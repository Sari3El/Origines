--[[-----------------------------------------------------------------------
	Origine du monde — tickets (serveur)

	Liés au compte (SteamID64). Les tickets ouverts restent après un
	redémarrage ; les fermés sont supprimés après RetentionJours.
	Le serveur vérifie tout (permissions, auteur, statut, longueurs).
-------------------------------------------------------------------------]]

local T = ORIGINE.Tickets
local CT = ORIGINE.ConfigTickets
local DB = ORIGINE.DB

for _, n in ipairs({ "origine_tickets_ouvrir", "origine_tickets_liste", "origine_tickets_detail",
	"origine_tickets_notif", "origine_tickets_compteur", "origine_tickets_stats" }) do
	util.AddNetworkString(n)
end

---------------------------------------------------------------------------
-- Tables
---------------------------------------------------------------------------
local function creerTables()
	local auto = DB.AutoIncrement()
	for _, r in ipairs({
		[[CREATE TABLE IF NOT EXISTS origine_tickets (
			]] .. auto .. [[, jeton VARCHAR(32), date INTEGER NOT NULL, auteur_sid VARCHAR(20) NOT NULL, auteur_nom VARCHAR(64),
			categorie VARCHAR(64), description MEDIUMTEXT, concernes MEDIUMTEXT, contexte MEDIUMTEXT,
			statut VARCHAR(12) NOT NULL, priorite INTEGER NOT NULL DEFAULT 2, staff_sid VARCHAR(20), staff_nom VARCHAR(64),
			date_maj INTEGER, premiere_reponse INTEGER, date_fermeture INTEGER, resolution VARCHAR(255),
			note INTEGER, commentaire VARCHAR(500), non_lu_joueur INTEGER NOT NULL DEFAULT 0)]],
		[[CREATE TABLE IF NOT EXISTS origine_tickets_messages (
			]] .. auto .. [[, ticket_id INTEGER NOT NULL, date INTEGER NOT NULL, auteur_sid VARCHAR(20), auteur_nom VARCHAR(64),
			staff INTEGER NOT NULL DEFAULT 0, interne INTEGER NOT NULL DEFAULT 0, texte MEDIUMTEXT)]],
	}) do DB.Requete(r, nil, nil, true) end
	DB.CreerIndex("origine_idx_tickets_auteur", "origine_tickets", "auteur_sid")
	DB.CreerIndex("origine_idx_tickets_statut", "origine_tickets", "statut")
	DB.CreerIndex("origine_idx_tickets_jeton", "origine_tickets", "jeton")
	DB.CreerIndex("origine_idx_tickets_msg", "origine_tickets_messages", "ticket_id")
	for _, t in ipairs({ "origine_tickets", "origine_tickets_messages" }) do
		if not table.HasValue(ORIGINE.TablesSauvegarde or {}, t) then table.insert(ORIGINE.TablesSauvegarde, t) end
	end
end
if DB.Pret then creerTables() else hook.Add("origine_BaseDeDonneesPrete", "origine_tickets", creerTables) end

---------------------------------------------------------------------------
-- Outils
---------------------------------------------------------------------------
local function erreur(ply, t) ORIGINE.Notifier(ply, t, "erreur") end
local function nomSteam(ply) return ORIGINE.NomSteam(ply) end

local function nettoyer(t, max)
	t = tostring(t or "")
	t = string.gsub(t, "[%z\1-\8\11\12\14-\31]", "")
	return ORIGINE.Tronquer(string.Trim(t), max)
end

local function staffConnectes()
	local liste = {}
	for _, p in ipairs(player.GetAll()) do
		if T.EstStaff(p) then liste[#liste + 1] = p end
	end
	return liste
end

local NUMERIQUES = { "id", "date", "priorite", "date_maj", "premiere_reponse", "date_fermeture", "note", "non_lu_joueur" }
local function ligneTicket(l)
	for _, c in ipairs(NUMERIQUES) do l[c] = tonumber(l[c]) end
	l.concernes = util.JSONToTable(l.concernes or "") or {}
	l.contexte = util.JSONToTable(l.contexte or "") or {}
	l.jeton = nil
	return l
end

-- Nombre de tickets en attente, envoyé au staff connecté
function T.DiffuserCompteur()
	DB.Requete("SELECT COUNT(*) AS n FROM origine_tickets WHERE statut = 'ouvert'", nil, function(l)
		T.EnAttente = tonumber(l and l[1] and l[1].n) or 0
		local staff = staffConnectes()
		if #staff == 0 then return end
		net.Start("origine_tickets_compteur")
			net.WriteUInt(T.EnAttente, 16)
		net.Send(staff)
	end)
end

local function notifier(cibles, texte, son)
	if not cibles or (istable(cibles) and #cibles == 0) then return end
	net.Start("origine_tickets_notif")
		net.WriteString(texte)
		net.WriteString(son or "")
	net.Send(cibles)
end

-- Discord : seulement quand aucun staff n'est connecté
local function discord(ticket)
	local url = CT.Discord.Webhook
	if not url or url == "" or #staffConnectes() > 0 then return end
	local contenu = string.format("**Nouveau ticket n°%d** (%s) — %s\n%s", ticket.id, ticket.categorie, ticket.auteur_nom,
		ORIGINE.Tronquer(ticket.description, 1500))
	HTTP({
		url = url, method = "POST", type = "application/json",
		body = util.TableToJSON({ username = CT.Discord.NomServeur, content = contenu }),
		failed = function(err) MsgC(Color(230, 60, 50), "[Origine] Webhook Discord : " .. tostring(err) .. "\n") end,
	})
end

---------------------------------------------------------------------------
-- Lecture d'un ticket avec contrôle d'accès : callback(ticket) ou rien
---------------------------------------------------------------------------
local function lireTicket(id, callback)
	DB.Requete("SELECT * FROM origine_tickets WHERE id = ?", { id }, function(l)
		callback(l and l[1] and ligneTicket(l[1]) or nil)
	end)
end

function T.EnvoyerDetail(ply, id)
	lireTicket(id, function(t)
		if not (t and IsValid(ply)) then return end
		local staff = T.EstStaff(ply)
		local auteur = t.auteur_sid == ply:SteamID64()
		if not (staff or auteur) then return end
		local filtre = staff and "" or " AND interne = 0"
		DB.Requete("SELECT date, auteur_nom, staff, interne, texte FROM origine_tickets_messages WHERE ticket_id = ?" .. filtre .. " ORDER BY id",
			{ id }, function(msgs)
			if not IsValid(ply) then return end
			for _, m in ipairs(msgs or {}) do
				m.date, m.staff, m.interne = tonumber(m.date), tonumber(m.staff) == 1, tonumber(m.interne) == 1
			end
			t.messages = msgs or {}
			if not staff then t.contexte = nil end
			t.vue_staff = staff and not auteur
			if auteur and t.non_lu_joueur == 1 then
				DB.Requete("UPDATE origine_tickets SET non_lu_joueur = 0 WHERE id = ?", { id })
			end
			net.Start("origine_tickets_detail")
				ORIGINE.NetEcrireTable(t)
			net.Send(ply)
		end)
	end)
end

---------------------------------------------------------------------------
-- Joueur : créer un ticket
---------------------------------------------------------------------------
local function contexte(ply)
	local c = { date = os.date("%d/%m/%Y %H:%M:%S"), carte = game.GetMap() }
	local p = ORIGINE.PersoActuel(ply)
	if p then
		c.personnage = p.prenom .. " " .. p.nom
		c.slot = p.slot
		c.job = team.GetName(ply:Team())
	end
	local pos = ply:GetPos()
	c.position = string.format("%d %d %d", pos.x, pos.y, pos.z)
	if ORIGINE.HeureRP then
		local h, m = ORIGINE.HeureRP()
		c.heure_rp = string.format("%02d:%02d", h, m)
	end
	return c
end

function T.Creer(ply, categorie, description, concernes)
	local sid = ply:SteamID64()
	if not T.CategorieValide(categorie) then return erreur(ply, "Catégorie invalide.") end
	description = nettoyer(description, CT.LongueurDescription)
	if description == "" then return erreur(ply, "Décrivez votre demande.") end
	if (ply.OrigineDernierTicket or 0) + CT.DelaiEntreTickets > CurTime() then
		return erreur(ply, "Attendez " .. math.ceil(ply.OrigineDernierTicket + CT.DelaiEntreTickets - CurTime()) .. " s avant un nouveau ticket.")
	end
	local liste = {}
	for _, c in ipairs(istable(concernes) and concernes or {}) do
		local cible = isstring(c) and ORIGINE.JoueurParSid(c)
		if cible and cible ~= ply and #liste < 10 then
			liste[#liste + 1] = { sid = c, nom = nomSteam(cible), perso = ORIGINE.NomComplet(cible) }
		end
	end
	ply.OrigineDernierTicket = CurTime()
	DB.Requete("SELECT id FROM origine_tickets WHERE auteur_sid = ? AND statut <> 'ferme'", { sid }, function(ouverts)
		if not IsValid(ply) then return end
		if ouverts and ouverts[1] then
			ply.OrigineDernierTicket = nil
			return erreur(ply, "Vous avez déjà un ticket ouvert (n°" .. ouverts[1].id .. ").")
		end
		local jeton = util.CRC(sid .. os.time() .. math.random()) .. math.random(1000, 9999)
		local maintenant = os.time()
		DB.Requete([[INSERT INTO origine_tickets (jeton, date, auteur_sid, auteur_nom, categorie, description, concernes, contexte,
			statut, priorite, date_maj) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'ouvert', 2, ?)]], {
			jeton, maintenant, sid, nomSteam(ply), categorie, description, util.TableToJSON(liste), util.TableToJSON(contexte(ply)), maintenant,
		}, function(res)
			if not res then return IsValid(ply) and erreur(ply, "La création du ticket a échoué.") end
			DB.Requete("SELECT * FROM origine_tickets WHERE jeton = ?", { jeton }, function(l)
				local t = l and l[1] and ligneTicket(l[1])
				if not t then return end
				if IsValid(ply) then
					ORIGINE.Notifier(ply, "Ticket n°" .. t.id .. " envoyé au staff.", "succes")
					T.EnvoyerListeJoueur(ply)
					T.EnvoyerDetail(ply, t.id)
				end
				notifier(staffConnectes(), "Nouveau ticket n°" .. t.id .. " (" .. t.categorie .. ") de " .. t.auteur_nom, CT.SonNouveau)
				T.DiffuserCompteur()
				discord(t)
				hook.Run("origine_TicketCree", ply, t)
			end)
		end)
	end)
end

---------------------------------------------------------------------------
-- Listes
---------------------------------------------------------------------------
local RESUME = "id, date, auteur_sid, auteur_nom, categorie, statut, priorite, staff_sid, staff_nom, date_maj, note, non_lu_joueur"

function T.EnvoyerListeJoueur(ply)
	DB.Requete("SELECT " .. RESUME .. " FROM origine_tickets WHERE auteur_sid = ? ORDER BY id DESC LIMIT " .. CT.ParPage,
		{ ply:SteamID64() }, function(l)
		if not IsValid(ply) then return end
		local liste = {}
		for _, t in ipairs(l or {}) do liste[#liste + 1] = ligneTicket(t) end
		net.Start("origine_tickets_liste")
			ORIGINE.NetEcrireTable({ vue = "mes", tickets = liste })
		net.Send(ply)
	end)
end

-- File du staff : tickets non fermés, du plus ancien au plus récent ; filtres facultatifs
local function envoyerFile(ply, f)
	local requete, params = "SELECT " .. RESUME .. " FROM origine_tickets WHERE statut <> 'ferme'", {}
	if T.CategorieValide(f.categorie) then requete = requete .. " AND categorie = ?" params[#params + 1] = f.categorie end
	if T.Statuts[f.statut] and f.statut ~= "ferme" then requete = requete .. " AND statut = ?" params[#params + 1] = f.statut end
	if f.staff == "moi" then requete = requete .. " AND staff_sid = ?" params[#params + 1] = ply:SteamID64()
	elseif f.staff == "aucun" then requete = requete .. " AND staff_sid IS NULL" end
	DB.Requete(requete .. " ORDER BY id ASC LIMIT 200", params, function(l)
		if not IsValid(ply) then return end
		local liste = {}
		for _, t in ipairs(l or {}) do liste[#liste + 1] = ligneTicket(t) end
		net.Start("origine_tickets_liste")
			ORIGINE.NetEcrireTable({ vue = "file", tickets = liste })
		net.Send(ply)
	end)
end

-- Historique : recherche par joueur (nom ou SteamID64), staff, catégorie, date (AAAA-MM-JJ)
local function envoyerHistorique(ply, f)
	local requete, params = "SELECT " .. RESUME .. " FROM origine_tickets WHERE 1 = 1", {}
	local joueur = nettoyer(f.joueur, 64)
	if joueur ~= "" then
		requete = requete .. " AND (auteur_nom LIKE ? OR auteur_sid = ? OR concernes LIKE ?)"
		local motif = "%" .. string.gsub(joueur, "[%%_]", "") .. "%"
		params[#params + 1], params[#params + 2], params[#params + 3] = motif, joueur, motif
	end
	local staff = nettoyer(f.staff, 64)
	if staff ~= "" then
		requete = requete .. " AND (staff_nom LIKE ? OR staff_sid = ?)"
		params[#params + 1], params[#params + 2] = "%" .. string.gsub(staff, "[%%_]", "") .. "%", staff
	end
	if T.CategorieValide(f.categorie) then requete = requete .. " AND categorie = ?" params[#params + 1] = f.categorie end
	local a, m, j = string.match(tostring(f.date or ""), "^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
	if a then
		local debut = os.time({ year = tonumber(a), month = tonumber(m), day = tonumber(j), hour = 0 })
		requete = requete .. " AND date >= ? AND date < ?"
		params[#params + 1], params[#params + 2] = debut, debut + 86400
	end
	local page = math.Clamp(math.floor(tonumber(f.page) or 0), 0, 4000)
	DB.Requete(requete .. " ORDER BY id DESC LIMIT " .. CT.ParPage .. " OFFSET " .. (page * CT.ParPage), params, function(l)
		if not IsValid(ply) then return end
		local liste = {}
		for _, t in ipairs(l or {}) do liste[#liste + 1] = ligneTicket(t) end
		net.Start("origine_tickets_liste")
			ORIGINE.NetEcrireTable({ vue = "historique", tickets = liste, page = page })
		net.Send(ply)
	end)
end

---------------------------------------------------------------------------
-- Messages et changements d'état
---------------------------------------------------------------------------
local function ajouterMessage(id, ply, estStaff, interne, texte, maj)
	local reqs = {
		{ "INSERT INTO origine_tickets_messages (ticket_id, date, auteur_sid, auteur_nom, staff, interne, texte) VALUES (?, ?, ?, ?, ?, ?, ?)",
			{ id, os.time(), ply:SteamID64(), nomSteam(ply), estStaff and 1 or 0, interne and 1 or 0, texte } },
	}
	if maj then reqs[#reqs + 1] = maj end
	return reqs
end

local function prevenirAuteur(t, texte)
	local auteur = ORIGINE.JoueurParSid(t.auteur_sid)
	if auteur then
		notifier(auteur, texte, CT.SonReponse)
		T.EnvoyerListeJoueur(auteur)
	end
end

local function apres(ply, id)
	T.EnvoyerDetail(ply, id)
	T.DiffuserCompteur()
end

-- Actions du joueur sur SON ticket
local ACTIONS_JOUEUR = {
	repondre = function(ply, t, a)
		if t.statut == "ferme" then return erreur(ply, "Ce ticket est fermé.") end
		local texte = nettoyer(a.texte, CT.LongueurMessage)
		if texte == "" then return end
		local statut = t.statut == "attente" and (t.staff_sid and "pris" or "ouvert") or t.statut
		DB.Transaction(ajouterMessage(t.id, ply, false, false, texte,
			{ "UPDATE origine_tickets SET statut = ?, date_maj = ? WHERE id = ?", { statut, os.time(), t.id } }), function()
			local staff = t.staff_sid and ORIGINE.JoueurParSid(t.staff_sid)
			notifier(staff or staffConnectes(), "Ticket n°" .. t.id .. " : nouvelle réponse de " .. t.auteur_nom, CT.SonNouveau)
			apres(ply, t.id)
		end)
	end,
	fermer = function(ply, t, a)
		if t.statut == "ferme" then return end
		local note = math.floor(tonumber(a.note) or 0)
		if note < 1 or note > 5 then return erreur(ply, "Donnez une note de 1 à 5.") end
		DB.Requete([[UPDATE origine_tickets SET statut = 'ferme', date_fermeture = ?, date_maj = ?, note = ?, commentaire = ?,
			resolution = COALESCE(resolution, 'Fermé par le joueur') WHERE id = ?]],
			{ os.time(), os.time(), note, nettoyer(a.commentaire, 500), t.id }, function()
			ORIGINE.Notifier(ply, "Ticket fermé. Merci pour votre avis !", "succes")
			local staff = t.staff_sid and ORIGINE.JoueurParSid(t.staff_sid)
			if staff then notifier(staff, "Ticket n°" .. t.id .. " fermé par le joueur (note " .. note .. "/5).", "") end
			T.EnvoyerListeJoueur(ply)
			apres(ply, t.id)
		end)
	end,
	-- Note après une fermeture par le staff
	noter = function(ply, t, a)
		if t.statut ~= "ferme" or t.note then return end
		local note = math.floor(tonumber(a.note) or 0)
		if note < 1 or note > 5 then return erreur(ply, "Donnez une note de 1 à 5.") end
		DB.Requete("UPDATE origine_tickets SET note = ?, commentaire = ? WHERE id = ?", { note, nettoyer(a.commentaire, 500), t.id }, function()
			ORIGINE.Notifier(ply, "Merci pour votre avis !", "succes")
			T.EnvoyerDetail(ply, t.id)
		end)
	end,
}

-- Actions du staff
local ACTIONS_STAFF = {
	prendre = function(ply, t)
		if t.statut == "ferme" then return end
		DB.Requete("UPDATE origine_tickets SET statut = 'pris', staff_sid = ?, staff_nom = ?, date_maj = ? WHERE id = ?",
			{ ply:SteamID64(), nomSteam(ply), os.time(), t.id }, function()
			prevenirAuteur(t, "Votre ticket n°" .. t.id .. " est pris en charge par " .. nomSteam(ply) .. ".")
			apres(ply, t.id)
		end)
	end,
	repondre = function(ply, t, a)
		if t.statut == "ferme" then return erreur(ply, "Rouvrez d'abord ce ticket.") end
		local texte = nettoyer(a.texte, CT.LongueurMessage)
		if texte == "" then return end
		local maintenant = os.time()
		local statut = t.statut == "ouvert" and "pris" or t.statut
		local staffSid, staffNom = t.staff_sid or ply:SteamID64(), t.staff_nom or nomSteam(ply)
		DB.Transaction(ajouterMessage(t.id, ply, true, false, texte, {
			"UPDATE origine_tickets SET statut = ?, staff_sid = ?, staff_nom = ?, date_maj = ?, non_lu_joueur = 1, premiere_reponse = COALESCE(premiere_reponse, ?) WHERE id = ?",
			{ statut, staffSid, staffNom, maintenant, maintenant, t.id } }), function()
			prevenirAuteur(t, "Réponse du staff à votre ticket n°" .. t.id .. " (F6).")
			apres(ply, t.id)
		end)
	end,
	note = function(ply, t, a)
		local texte = nettoyer(a.texte, CT.LongueurMessage)
		if texte == "" then return end
		DB.Transaction(ajouterMessage(t.id, ply, true, true, texte), function() apres(ply, t.id) end)
	end,
	attente = function(ply, t)
		if t.statut == "ferme" then return end
		DB.Requete("UPDATE origine_tickets SET statut = 'attente', date_maj = ?, staff_sid = COALESCE(staff_sid, ?), staff_nom = COALESCE(staff_nom, ?) WHERE id = ?",
			{ os.time(), ply:SteamID64(), nomSteam(ply), t.id }, function()
			prevenirAuteur(t, "Le staff attend votre réponse sur le ticket n°" .. t.id .. " (F6).")
			apres(ply, t.id)
		end)
	end,
	priorite = function(ply, t, a)
		local p = math.floor(tonumber(a.priorite) or 0)
		if not CT.Priorites[p] then return end
		DB.Requete("UPDATE origine_tickets SET priorite = ? WHERE id = ?", { p, t.id }, function() apres(ply, t.id) end)
	end,
	transferer = function(ply, t, a)
		local cible = isstring(a.sid) and ORIGINE.JoueurParSid(a.sid)
		if not (cible and T.EstStaff(cible)) then return erreur(ply, "Ce membre du staff n'est pas connecté.") end
		-- Un staff transfère les tickets qui sont à lui ou à personne ; l'admin réattribue n'importe lequel
		if t.staff_sid and t.staff_sid ~= ply:SteamID64() and not T.EstAdmin(ply) then
			return erreur(ply, "Ce ticket est suivi par " .. (t.staff_nom or "un autre staff") .. " (réattribution : origine_tickets_admin).")
		end
		DB.Requete("UPDATE origine_tickets SET staff_sid = ?, staff_nom = ?, statut = CASE WHEN statut = 'ouvert' THEN 'pris' ELSE statut END, date_maj = ? WHERE id = ?",
			{ cible:SteamID64(), nomSteam(cible), os.time(), t.id }, function()
			notifier(cible, "Ticket n°" .. t.id .. " transféré par " .. nomSteam(ply) .. ".", CT.SonNouveau)
			apres(ply, t.id)
		end)
	end,
	fermer = function(ply, t, a)
		if t.statut == "ferme" then return end
		local resolution = nettoyer(a.resolution, 250)
		if resolution == "" then return erreur(ply, "Indiquez une note de résolution.") end
		DB.Requete("UPDATE origine_tickets SET statut = 'ferme', resolution = ?, date_fermeture = ?, date_maj = ?, non_lu_joueur = 1, staff_sid = COALESCE(staff_sid, ?), staff_nom = COALESCE(staff_nom, ?) WHERE id = ?",
			{ resolution, os.time(), os.time(), ply:SteamID64(), nomSteam(ply), t.id }, function()
			prevenirAuteur(t, "Votre ticket n°" .. t.id .. " est fermé : " .. resolution .. " (F6 pour le noter).")
			apres(ply, t.id)
		end)
	end,
	rouvrir = function(ply, t)
		if t.statut ~= "ferme" then return end
		DB.Requete("UPDATE origine_tickets SET statut = ?, date_fermeture = NULL, date_maj = ? WHERE id = ?",
			{ t.staff_sid and "pris" or "ouvert", os.time(), t.id }, function()
			prevenirAuteur(t, "Votre ticket n°" .. t.id .. " a été rouvert.")
			apres(ply, t.id)
		end)
	end,
	supprimer = function(ply, t)
		if not T.EstAdmin(ply) then return erreur(ply, "Vous n'avez pas la permission.") end
		DB.Transaction({
			{ "DELETE FROM origine_tickets_messages WHERE ticket_id = ?", { t.id } },
			{ "DELETE FROM origine_tickets WHERE id = ?", { t.id } },
		}, function()
			ORIGINE.Notifier(ply, "Ticket n°" .. t.id .. " supprimé.", "succes")
			T.DiffuserCompteur()
		end)
	end,
}

---------------------------------------------------------------------------
-- Statistiques (origine_tickets_admin)
---------------------------------------------------------------------------
local function envoyerStats(ply)
	DB.Requete([[SELECT staff_sid, MAX(staff_nom) AS staff_nom, COUNT(*) AS traites,
		AVG(CASE WHEN premiere_reponse IS NOT NULL THEN premiere_reponse - date END) AS delai,
		AVG(note) AS note, COUNT(note) AS notes
		FROM origine_tickets WHERE staff_sid IS NOT NULL AND statut = 'ferme' GROUP BY staff_sid ORDER BY traites DESC]], nil, function(l)
		if not IsValid(ply) then return end
		local liste = {}
		for _, r in ipairs(l or {}) do
			liste[#liste + 1] = { nom = r.staff_nom or r.staff_sid, sid = r.staff_sid, traites = tonumber(r.traites) or 0,
				delai = tonumber(r.delai), note = tonumber(r.note), notes = tonumber(r.notes) or 0 }
		end
		net.Start("origine_tickets_stats")
			ORIGINE.NetEcrireTable(liste)
		net.Send(ply)
	end)
end

---------------------------------------------------------------------------
-- Réseau
---------------------------------------------------------------------------
ORIGINE.NetRecevoir("origine_tickets_demande", function(ply)
	local quoi = net.ReadString()
	local a = ORIGINE.NetLireTable()
	if not istable(a) then return end
	local staff = T.EstStaff(ply)

	if quoi == "creer" then return T.Creer(ply, a.categorie, a.description, a.concernes) end
	if quoi == "mes" then return T.EnvoyerListeJoueur(ply) end
	if quoi == "detail" then return T.EnvoyerDetail(ply, math.floor(tonumber(a.id) or 0)) end
	if quoi == "file" then return staff and envoyerFile(ply, a) end
	if quoi == "historique" then return staff and envoyerHistorique(ply, a) end
	if quoi == "stats" then return T.EstAdmin(ply) and envoyerStats(ply) end

	if quoi == "action" then
		local id = math.floor(tonumber(a.id) or 0)
		lireTicket(id, function(t)
			if not (t and IsValid(ply)) then return end
			local action = tostring(a.action or "")
			if t.auteur_sid == ply:SteamID64() and ACTIONS_JOUEUR[action] then
				return ACTIONS_JOUEUR[action](ply, t, a)
			end
			if staff and ACTIONS_STAFF[action] then return ACTIONS_STAFF[action](ply, t, a) end
		end)
	end
end, 6)

function T.Ouvrir(ply)
	net.Start("origine_tickets_ouvrir")
		net.WriteBool(T.EstStaff(ply))
		net.WriteBool(T.EstAdmin(ply))
		net.WriteUInt(T.EnAttente or 0, 16)
	net.Send(ply)
end
ORIGINE.NetRecevoir("origine_tickets_f6", T.Ouvrir, 2)

-- !report message : ticket rapide ; !tickets : menu
hook.Add("PlayerSay", "origine_tickets", function(ply, texte)
	local bas = string.lower(texte)
	if string.sub(bas, 1, 7) == "!report" or string.sub(bas, 1, 7) == "/report" then
		local message = string.Trim(string.sub(texte, 8))
		if message == "" then T.Ouvrir(ply) else T.Creer(ply, CT.CategorieRapide, message, {}) end
		return ""
	end
	if string.Trim(bas) == "!tickets" or string.Trim(bas) == "/tickets" then
		T.Ouvrir(ply)
		return ""
	end
end)

---------------------------------------------------------------------------
-- Connexion : compteur pour le staff, réponses reçues hors ligne pour le joueur
---------------------------------------------------------------------------
hook.Add("PlayerInitialSpawn", "origine_tickets", function(ply)
	timer.Simple(8, function()
		if not IsValid(ply) then return end
		if T.EstStaff(ply) then
			net.Start("origine_tickets_compteur")
				net.WriteUInt(T.EnAttente or 0, 16)
			net.Send(ply)
		end
		DB.Requete("SELECT COUNT(*) AS n FROM origine_tickets WHERE auteur_sid = ? AND non_lu_joueur = 1", { ply:SteamID64() }, function(l)
			local n = tonumber(l and l[1] and l[1].n) or 0
			if n > 0 and IsValid(ply) then
				notifier(ply, n == 1 and "Le staff a répondu à votre ticket pendant votre absence (F6)." or
					("Le staff a répondu à " .. n .. " de vos tickets pendant votre absence (F6)."), CT.SonReponse)
			end
		end)
	end)
end)

---------------------------------------------------------------------------
-- Rétention : tickets fermés supprimés après RetentionJours
---------------------------------------------------------------------------
local function purger()
	local limite = os.time() - CT.RetentionJours * 86400
	DB.Requete("SELECT id FROM origine_tickets WHERE statut = 'ferme' AND date_fermeture < ?", { limite }, function(l)
		local reqs = {}
		for _, r in ipairs(l or {}) do
			reqs[#reqs + 1] = { "DELETE FROM origine_tickets_messages WHERE ticket_id = ?", { tonumber(r.id) } }
			reqs[#reqs + 1] = { "DELETE FROM origine_tickets WHERE id = ?", { tonumber(r.id) } }
		end
		if #reqs > 0 then DB.Transaction(reqs) end
	end)
end
hook.Add("InitPostEntity", "origine_tickets", function()
	timer.Simple(20, function()
		purger()
		T.DiffuserCompteur()
	end)
end)
timer.Create("origine_tickets_purge", 6 * 3600, 0, purger)
