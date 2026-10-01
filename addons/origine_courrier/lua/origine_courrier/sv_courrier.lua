--[[-----------------------------------------------------------------------
	Origine du monde — missives (serveur)

	Rangement :
	  personnages -> coffret de chaque destinataire (origine_missives_boites)
	  faction     -> registre de sa faction (origine_missives_registres)
	  factions    -> registre de chaque faction choisie ET de la sienne
	  général     -> onglet Général de tous les coffrets
	Le registre d'une faction n'est lisible que par ses membres actuels.
	Supprimer ou sortir en papier une missive de faction / générale la masque
	seulement pour ce personnage.
-------------------------------------------------------------------------]]

local MC = ORIGINE.Courrier
local CC = ORIGINE.ConfigCourrier
local DB = ORIGINE.DB
local I = ORIGINE.Inv
local S = ORIGINE.Staff
local H = ORIGINE.Historique

util.AddNetworkString("origine_courrier_ouvrir")
util.AddNetworkString("origine_courrier_ecrire")
util.AddNetworkString("origine_courrier_liste")
util.AddNetworkString("origine_courrier_texte")
util.AddNetworkString("origine_courrier_papier")
util.AddNetworkString("origine_courrier_nouvelle")
util.AddNetworkString("origine_courrier_admin_liste")
util.AddNetworkString("origine_courrier_admin_texte")

ORIGINE.EnregistrerPermission("origine_courrier_admin", "superadmin", "Missives : lire et supprimer toutes les missives depuis !origine")

---------------------------------------------------------------------------
-- Tables
---------------------------------------------------------------------------
local function creerTables()
	local auto = DB.AutoIncrement()
	for _, r in ipairs({
		[[CREATE TABLE IF NOT EXISTS origine_missives (
			]] .. auto .. [[, date INTEGER NOT NULL, jeton VARCHAR(32),
			auteur_sid VARCHAR(20) NOT NULL, auteur_slot INTEGER NOT NULL, auteur_nom VARCHAR(160),
			auteur_faction VARCHAR(80), objet VARCHAR(160), texte MEDIUMTEXT, portee VARCHAR(12) NOT NULL,
			destinataires MEDIUMTEXT, supprimee INTEGER NOT NULL DEFAULT 0)]],
		[[CREATE TABLE IF NOT EXISTS origine_missives_boites (
			]] .. auto .. [[, missive_id INTEGER NOT NULL, steamid64 VARCHAR(20) NOT NULL, slot INTEGER NOT NULL,
			lu INTEGER NOT NULL DEFAULT 0)]],
		[[CREATE TABLE IF NOT EXISTS origine_missives_registres (
			]] .. auto .. [[, missive_id INTEGER NOT NULL, faction VARCHAR(80) NOT NULL)]],
		[[CREATE TABLE IF NOT EXISTS origine_missives_masquees (
			steamid64 VARCHAR(20) NOT NULL, slot INTEGER NOT NULL, missive_id INTEGER NOT NULL,
			PRIMARY KEY (steamid64, slot, missive_id))]],
	}) do DB.Requete(r, nil, nil, true) end
	DB.CreerIndex("origine_idx_missives_boites", "origine_missives_boites", "steamid64, slot")
	DB.CreerIndex("origine_idx_missives_registres", "origine_missives_registres", "faction")
	DB.CreerIndex("origine_idx_missives_jeton", "origine_missives", "jeton")
	for _, t in ipairs({ "origine_missives", "origine_missives_boites", "origine_missives_registres", "origine_missives_masquees" }) do
		if not table.HasValue(ORIGINE.TablesSauvegarde or {}, t) then table.insert(ORIGINE.TablesSauvegarde, t) end
	end
end
if DB.Pret then creerTables() else hook.Add("origine_BaseDeDonneesPrete", "origine_courrier", creerTables) end

local function erreur(ply, t) ORIGINE.Notifier(ply, t, "erreur") end

local function nettoyer(t, max)
	t = tostring(t or "")
	t = string.gsub(t, "[%z\1-\8\11\12\14-\31]", "")   -- caractères de contrôle (texte brut uniquement)
	return ORIGINE.Tronquer(string.Trim(t), max)
end

local function factionsValides()
	local set = {}
	for _, f in ipairs(ORIGINE.Factions()) do set[f.nom] = true end
	return set
end

---------------------------------------------------------------------------
-- Parchemin : entité posée (E) ou dans l'inventaire (bouton « Écrire » du coffret)
---------------------------------------------------------------------------
local function parcheminInventaire(ply)
	local cases = I.DuJoueur(ply)
	if not cases then return nil end
	for i, c in ipairs(cases) do
		if c.classe == "origine_parchemin" then return i end
	end
	return nil
end

-- Vérifie le parchemin sans le consommer ; renvoie une fonction qui le consomme
local function parcheminDisponible(ply, ent)
	if IsValid(ent) then
		if ent:GetClass() ~= "origine_parchemin" or ent.OrigineUtilise then return nil end
		if ply:GetPos():Distance(ent:GetPos()) > CC.Portee then return nil end
		return function()
			if not IsValid(ent) or ent.OrigineUtilise then return false end
			ent.OrigineUtilise = true
			ent:Remove()
			return true
		end
	end
	if not parcheminInventaire(ply) then return nil end
	return function()
		local i = parcheminInventaire(ply)
		if not i then return false end
		I.RetirerDe(I.DuJoueur(ply), i)
		I.Modifie(ply)
		return true
	end
end

function MC.OuvrirEcriture(ply, ent, modele)
	if not ORIGINE.PersoActuel(ply) or ORIGINE.EnMenu(ply) then return end
	if ORIGINE.EstImmobilise and ORIGINE.EstImmobilise(ply) then return erreur(ply, "Vous avez les mains liées.") end
	if not parcheminDisponible(ply, ent) then return erreur(ply, "Il vous faut un parchemin vierge (posé devant vous ou dans votre inventaire).") end
	local factions = {}
	for _, f in ipairs(ORIGINE.Factions()) do factions[#factions + 1] = f.nom end
	net.Start("origine_courrier_ecrire")
		net.WriteEntity(IsValid(ent) and ent or NULL)
		ORIGINE.NetEcrireTable({
			factions = factions, faction = ORIGINE.FactionDe(ply),
			generale = MC.PeutEcrireGenerale(ply), modele = modele,
		})
	net.Send(ply)
end

---------------------------------------------------------------------------
-- Envoi
---------------------------------------------------------------------------
-- Résout les noms de personnages : callback(trouves, introuvables)
local function resoudreNoms(noms, callback)
	local trouves, introuvables, i = {}, {}, 0
	local function suivant()
		i = i + 1
		local nom = noms[i]
		if not nom then return callback(trouves, introuvables) end
		local prenom, nomFamille = string.match(nom, "^(%S+)%s+(.+)$")
		if not prenom then introuvables[#introuvables + 1] = nom return suivant() end
		DB.Requete("SELECT steamid64, slot, prenom, nom FROM origine_personnages WHERE nom_cle = ? AND valide = 1",
			{ ORIGINE.CleNom(prenom, nomFamille) }, function(l)
			local r = l and l[1]
			if r then
				trouves[#trouves + 1] = { sid = r.steamid64, slot = tonumber(r.slot), nom = r.prenom .. " " .. r.nom }
			else
				introuvables[#introuvables + 1] = nom
			end
			suivant()
		end)
	end
	suivant()
end

-- Garde les MaxPersonnelles dernières missives personnelles d'un personnage
local function limiterBoite(sid, slot)
	DB.Requete("SELECT id FROM origine_missives_boites WHERE steamid64 = ? AND slot = ? ORDER BY id DESC LIMIT 1 OFFSET " .. (CC.MaxPersonnelles - 1),
		{ sid, slot }, function(l)
		local limite = l and l[1] and tonumber(l[1].id)
		if limite then
			DB.Requete("DELETE FROM origine_missives_boites WHERE steamid64 = ? AND slot = ? AND id < ?", { sid, slot, limite })
		end
	end)
end

local function prevenir(ply, onglet, objet, auteur)
	net.Start("origine_courrier_nouvelle")
		net.WriteString(onglet)
		net.WriteString(objet)
		net.WriteString(auteur)
	net.Send(ply)
end

function MC.Envoyer(ply, ent, d)
	local p = ORIGINE.PersoActuel(ply)
	if not p or ORIGINE.EnMenu(ply) then return end
	if ORIGINE.EstImmobilise and ORIGINE.EstImmobilise(ply) then return erreur(ply, "Vous avez les mains liées.") end
	local maintenant = CurTime()
	if (ply.OrigineDerniereMissive or 0) + CC.DelaiMissive > maintenant then
		return erreur(ply, "Attendez " .. math.ceil(ply.OrigineDerniereMissive + CC.DelaiMissive - maintenant) .. " s avant une nouvelle missive.")
	end
	local portee = MC.Portees[d.portee] and d.portee or nil
	if not portee then return end
	if portee == "general" then
		if not MC.PeutEcrireGenerale(ply) then return erreur(ply, "Votre métier ne permet pas d'écrire à tout le serveur.") end
		if (ply.OrigineDerniereGenerale or 0) + CC.DelaiGenerale > maintenant then
			return erreur(ply, "Attendez " .. math.ceil((ply.OrigineDerniereGenerale + CC.DelaiGenerale - maintenant) / 60) .. " min avant une nouvelle missive générale.")
		end
	end
	local objet = nettoyer(d.objet, CC.LongueurObjet)
	local texte = nettoyer(d.texte, CC.LongueurTexte)
	if objet == "" or texte == "" then return erreur(ply, "L'objet et le texte sont obligatoires.") end

	local faction = ORIGINE.FactionDe(ply)
	local factions = {}
	if portee == "faction" then
		if not faction then return erreur(ply, "Vous n'appartenez à aucune faction.") end
		factions = { faction }
	elseif portee == "factions" then
		local valides, vus = factionsValides(), {}
		for _, f in ipairs(istable(d.factions) and d.factions or {}) do
			if isstring(f) and valides[f] and f ~= faction and not vus[f] then
				vus[f] = true
				factions[#factions + 1] = f
			end
		end
		if #factions == 0 then return erreur(ply, "Choisissez au moins une autre faction.") end
		-- Copie dans le registre de sa propre faction : chaque camp suit l'échange
		if faction then factions[#factions + 1] = faction end
	end

	local noms = {}
	if portee == "perso" then
		for _, n in ipairs(istable(d.persos) and d.persos or {}) do
			n = nettoyer(n, 130)
			if n ~= "" and not table.HasValue(noms, n) then noms[#noms + 1] = n end
		end
		if #noms == 0 then return erreur(ply, "Choisissez au moins un destinataire.") end
		if #noms > CC.MaxDestinataires then return erreur(ply, "Au maximum " .. CC.MaxDestinataires .. " destinataires.") end
	end
	local consommer = parcheminDisponible(ply, ent)
	if not consommer then return erreur(ply, "Il vous faut un parchemin vierge.") end

	ply.OrigineDerniereMissive = maintenant   -- bloque les doubles envois pendant la suite
	resoudreNoms(noms, function(trouves, introuvables)
		if not IsValid(ply) or ORIGINE.PersoActuel(ply) ~= p then return end
		if #introuvables > 0 then
			ply.OrigineDerniereMissive = nil
			return erreur(ply, "Personnage introuvable : " .. table.concat(introuvables, ", ") .. ".")
		end
		local dest = {}
		for _, t in ipairs(trouves) do
			if not (t.sid == p.steamid64 and t.slot == p.slot) then dest[#dest + 1] = t end
		end
		if portee == "perso" and #dest == 0 then
			ply.OrigineDerniereMissive = nil
			return erreur(ply, "Vous ne pouvez pas vous écrire à vous-même.")
		end
		if not consommer() then
			ply.OrigineDerniereMissive = nil
			return erreur(ply, "Votre parchemin a disparu.")
		end
		if portee == "general" then ply.OrigineDerniereGenerale = maintenant end

		local nomsDest = {}
		for _, t in ipairs(dest) do nomsDest[#nomsDest + 1] = t.nom end
		local destinataires = { persos = nomsDest, factions = factions }
		local jeton = util.CRC(p.steamid64 .. os.time() .. math.random()) .. math.random(1000, 9999)
		local auteur = p.prenom .. " " .. p.nom

		DB.Requete([[INSERT INTO origine_missives (date, jeton, auteur_sid, auteur_slot, auteur_nom, auteur_faction, objet, texte, portee, destinataires)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
			os.time(), jeton, p.steamid64, p.slot, auteur, faction, objet, texte, portee, util.TableToJSON(destinataires),
		}, function(res)
			if not res then return IsValid(ply) and erreur(ply, "L'envoi a échoué.") end
			DB.Requete("SELECT id FROM origine_missives WHERE jeton = ?", { jeton }, function(l)
				local id = l and l[1] and tonumber(l[1].id)
				if not id then return end
				local reqs = {}
				for _, t in ipairs(dest) do
					reqs[#reqs + 1] = { "INSERT INTO origine_missives_boites (missive_id, steamid64, slot, lu) VALUES (?, ?, ?, 0)", { id, t.sid, t.slot } }
				end
				for _, f in ipairs(factions) do
					reqs[#reqs + 1] = { "INSERT INTO origine_missives_registres (missive_id, faction) VALUES (?, ?)", { id, f } }
				end
				DB.Transaction(reqs, function()
					for _, t in ipairs(dest) do limiterBoite(t.sid, t.slot) end
				end)

				-- Prévenir les destinataires connectés
				local setFactions = {}
				for _, f in ipairs(factions) do setFactions[f] = true end
				for _, cible in ipairs(player.GetAll()) do
					if cible ~= ply and ORIGINE.PersoActuel(cible) and not ORIGINE.EnMenu(cible) then
						local onglet
						if portee == "general" then onglet = "general"
						elseif portee == "perso" then
							for _, t in ipairs(dest) do
								if t.sid == cible:SteamID64() and t.slot == cible.OrigineSlot then onglet = "perso" end
							end
						elseif setFactions[ORIGINE.FactionDe(cible) or ""] then onglet = "faction" end
						if onglet then prevenir(cible, onglet, objet, auteur) end
					end
				end
				if IsValid(ply) then ORIGINE.Notifier(ply, "Missive envoyée.", "succes") end
				hook.Run("origine_MissiveEnvoyee", ply, id, portee, destinataires)
			end)
		end)
	end)
end

ORIGINE.NetRecevoir("origine_courrier_envoyer", function(ply)
	local ent = net.ReadEntity()
	local d = ORIGINE.NetLireTable()
	if istable(d) then MC.Envoyer(ply, IsValid(ent) and ent or nil, d) end
end, 2)

ORIGINE.NetRecevoir("origine_courrier_ecrire_inventaire", function(ply)
	MC.OuvrirEcriture(ply, nil)
end, 2)

---------------------------------------------------------------------------
-- Coffret : listes par pages (Personnelles, Faction, Général)
---------------------------------------------------------------------------
local CHAMPS = "m.id, m.date, m.auteur_nom, m.objet, m.portee, m.destinataires"

local function requeteOnglet(p, faction, onglet, page)
	local limite = " LIMIT " .. CC.ParPage .. " OFFSET " .. (page * CC.ParPage)
	if onglet == "perso" then
		return "SELECT " .. CHAMPS .. ", b.lu FROM origine_missives_boites b JOIN origine_missives m ON m.id = b.missive_id " ..
			"WHERE b.steamid64 = ? AND b.slot = ? AND m.supprimee = 0 ORDER BY b.id DESC" .. limite, { p.steamid64, p.slot }
	end
	local masque = " AND m.id NOT IN (SELECT missive_id FROM origine_missives_masquees WHERE steamid64 = ? AND slot = ?)"
	if onglet == "faction" then
		if not faction then return nil end
		return "SELECT " .. CHAMPS .. " FROM origine_missives_registres r JOIN origine_missives m ON m.id = r.missive_id " ..
			"WHERE r.faction = ? AND m.supprimee = 0" .. masque .. " ORDER BY m.id DESC" .. limite, { faction, p.steamid64, p.slot }
	end
	return "SELECT " .. CHAMPS .. " FROM origine_missives m WHERE m.portee = 'general' AND m.supprimee = 0" .. masque ..
		" ORDER BY m.id DESC" .. limite, { p.steamid64, p.slot }
end

local function envoyerListe(ply, onglet, page)
	local p = ORIGINE.PersoActuel(ply)
	if not p then return end
	local faction = ORIGINE.FactionDe(ply)
	local requete, params = requeteOnglet(p, faction, onglet, page)
	if not requete then
		net.Start("origine_courrier_liste")
			ORIGINE.NetEcrireTable({ onglet = onglet, page = page, missives = {}, faction = nil })
		net.Send(ply)
		return
	end
	DB.Requete(requete, params, function(lignes)
		if not IsValid(ply) then return end
		local liste = {}
		for _, l in ipairs(lignes or {}) do
			liste[#liste + 1] = {
				id = tonumber(l.id), date = tonumber(l.date), auteur = l.auteur_nom, objet = l.objet,
				portee = l.portee, destinataires = util.JSONToTable(l.destinataires or "") or {},
				lu = l.lu == nil or tonumber(l.lu) == 1,
			}
		end
		net.Start("origine_courrier_liste")
			ORIGINE.NetEcrireTable({ onglet = onglet, page = page, missives = liste, faction = faction, parPage = CC.ParPage })
		net.Send(ply)
	end)
end

ORIGINE.NetRecevoir("origine_courrier_liste", function(ply)
	local onglet = net.ReadString()
	local page = math.Clamp(net.ReadUInt(12), 0, 4000)
	if onglet ~= "perso" and onglet ~= "faction" and onglet ~= "general" then return end
	envoyerListe(ply, onglet, page)
end, 6)

-- Accès d'un personnage à une missive : callback(missive, onglet) ou callback(nil)
local function acces(ply, id, callback)
	local p = ORIGINE.PersoActuel(ply)
	if not p then return callback(nil) end
	DB.Requete("SELECT * FROM origine_missives WHERE id = ? AND supprimee = 0", { id }, function(l)
		local m = l and l[1]
		if not m then return callback(nil) end
		DB.Requete("SELECT id FROM origine_missives_boites WHERE missive_id = ? AND steamid64 = ? AND slot = ?", { id, p.steamid64, p.slot }, function(b)
			if b and b[1] then return callback(m, "perso") end
			DB.Requete("SELECT missive_id FROM origine_missives_masquees WHERE missive_id = ? AND steamid64 = ? AND slot = ?", { id, p.steamid64, p.slot }, function(mq)
				if mq and mq[1] then return callback(nil) end
				if m.portee == "general" then return callback(m, "general") end
				local faction = ORIGINE.FactionDe(ply)
				if not faction then return callback(nil) end
				-- Registre : membres ACTUELS de la faction seulement
				DB.Requete("SELECT id FROM origine_missives_registres WHERE missive_id = ? AND faction = ?", { id, faction }, function(r)
					callback(r and r[1] and m or nil, "faction")
				end)
			end)
		end)
	end)
end

local function versClient(m)
	return {
		id = tonumber(m.id), date = tonumber(m.date), auteur = m.auteur_nom, objet = m.objet, texte = m.texte,
		portee = m.portee, destinataires = util.JSONToTable(m.destinataires or "") or {}, faction = m.auteur_faction,
	}
end

ORIGINE.NetRecevoir("origine_courrier_lire", function(ply)
	local id = net.ReadUInt(32)
	acces(ply, id, function(m, onglet)
		if not IsValid(ply) or not m then return end
		if onglet == "perso" then
			local p = ORIGINE.PersoActuel(ply)
			DB.Requete("UPDATE origine_missives_boites SET lu = 1 WHERE missive_id = ? AND steamid64 = ? AND slot = ?", { id, p.steamid64, p.slot })
		end
		net.Start("origine_courrier_texte")
			ORIGINE.NetEcrireTable(versClient(m))
		net.Send(ply)
	end)
end, 6)

-- Retire la missive du coffret de ce personnage (supprimer ou sortir en papier)
local function retirerDuCoffret(ply, id, onglet)
	local p = ORIGINE.PersoActuel(ply)
	if onglet == "perso" then
		DB.Requete("DELETE FROM origine_missives_boites WHERE missive_id = ? AND steamid64 = ? AND slot = ?", { id, p.steamid64, p.slot })
	else
		DB.Requete("REPLACE INTO origine_missives_masquees (steamid64, slot, missive_id) VALUES (?, ?, ?)", { p.steamid64, p.slot, id })
	end
end

ORIGINE.NetRecevoir("origine_courrier_action", function(ply)
	local id = net.ReadUInt(32)
	local action = net.ReadString()
	if action ~= "supprimer" and action ~= "papier" then return end
	if ORIGINE.EstImmobilise and ORIGINE.EstImmobilise(ply) then return erreur(ply, "Vous avez les mains liées.") end
	acces(ply, id, function(m, onglet)
		if not IsValid(ply) or not m then return end
		if action == "papier" then
			local d = versClient(m)
			local missive = ents.Create("origine_missive")
			if not IsValid(missive) then return end
			local pos, ang = I.PositionDevant(ply)
			missive:SetPos(pos)
			missive:SetAngles(ang)
			missive:OrigineDepuisObjet({ objet = d.objet, texte = d.texte, auteur = d.auteur, date = d.date })
			missive:Spawn()
			ORIGINE.MarquerEntite(missive, ply)
		end
		retirerDuCoffret(ply, id, onglet)
		ORIGINE.Notifier(ply, action == "papier" and "La missive est sortie en papier." or "Missive supprimée.", "succes")
		envoyerListe(ply, onglet, 0)
	end)
end, 4)

---------------------------------------------------------------------------
-- Missive papier : lire (E ou inventaire), ranger, détruire
---------------------------------------------------------------------------
function MC.EnvoyerPapier(ply, donnees, ent)
	net.Start("origine_courrier_papier")
		net.WriteEntity(IsValid(ent) and ent or NULL)
		ORIGINE.NetEcrireTable({ objet = donnees.objet, texte = donnees.texte, auteur = donnees.auteur, date = donnees.date })
	net.Send(ply)
end

ORIGINE.NetRecevoir("origine_courrier_papier_action", function(ply)
	local ent = net.ReadEntity()
	local action = net.ReadString()
	if not (IsValid(ent) and ent:GetClass() == "origine_missive") then return end
	if ply:GetPos():Distance(ent:GetPos()) > CC.Portee or not ply:Alive() then return end
	if action == "ranger" then
		I.Ranger(ply, ent)
	elseif action == "detruire" then
		if ORIGINE.EstImmobilise and ORIGINE.EstImmobilise(ply) then return end
		ent:Remove()
		ORIGINE.Notifier(ply, "Missive détruite.", "info")
	end
end, 4)

---------------------------------------------------------------------------
-- Coffret : !missives, missives reçues hors ligne
---------------------------------------------------------------------------
function MC.OuvrirCoffret(ply)
	if not ORIGINE.PersoActuel(ply) or ORIGINE.EnMenu(ply) then return end
	net.Start("origine_courrier_ouvrir")
		net.WriteBool(parcheminInventaire(ply) ~= nil)
	net.Send(ply)
end

hook.Add("PlayerSay", "origine_courrier", function(ply, texte)
	local cmd = string.lower(string.Trim(texte))
	if cmd == "!missives" or cmd == "/missives" then
		MC.OuvrirCoffret(ply)
		return ""
	end
end)
ORIGINE.NetRecevoir("origine_courrier_coffret", MC.OuvrirCoffret, 2)

hook.Add("origine_PersonnageCharge", "origine_courrier", function(ply, p)
	DB.Requete([[SELECT COUNT(*) AS n FROM origine_missives_boites b JOIN origine_missives m ON m.id = b.missive_id
		WHERE b.steamid64 = ? AND b.slot = ? AND b.lu = 0 AND m.supprimee = 0]], { p.steamid64, p.slot }, function(l)
		local n = tonumber(l and l[1] and l[1].n) or 0
		if n > 0 and IsValid(ply) then
			timer.Simple(3, function()
				if IsValid(ply) then prevenir(ply, "perso", n == 1 and "1 missive non lue" or (n .. " missives non lues"), "") end
			end)
		end
	end)
end)

---------------------------------------------------------------------------
-- CK / RPK : le coffret du personnage est vidé
---------------------------------------------------------------------------
S.AjouterExtensionCK({
	nom = "courrier",
	vider = function(sid, slot)
		DB.Transaction({
			{ "DELETE FROM origine_missives_boites WHERE steamid64 = ? AND slot = ?", { sid, slot } },
			{ "DELETE FROM origine_missives_masquees WHERE steamid64 = ? AND slot = ?", { sid, slot } },
		})
	end,
})

---------------------------------------------------------------------------
-- Staff (!origine > Missives) : origine_menu ET origine_courrier_admin
---------------------------------------------------------------------------
S.RecevoirStaff("origine_courrier_admin", function(ply)
	if not ORIGINE.APermission(ply, "origine_courrier_admin") then return erreur(ply, "Vous n'avez pas la permission.") end
	local action = net.ReadString()
	local a = ORIGINE.NetLireTable()
	if not istable(a) then return end
	if action == "liste" then
		local page = math.Clamp(math.floor(tonumber(a.page) or 0), 0, 4000)
		local t = nettoyer(a.texte, 80)
		local requete = "SELECT id, date, auteur_nom, auteur_sid, objet, portee, destinataires, supprimee FROM origine_missives"
		local params = {}
		if t ~= "" then
			requete = requete .. " WHERE auteur_nom LIKE ? OR objet LIKE ? OR texte LIKE ? OR auteur_sid = ?"
			local motif = "%" .. string.gsub(t, "[%%_]", "") .. "%"
			params = { motif, motif, motif, t }
		end
		DB.Requete(requete .. " ORDER BY id DESC LIMIT 30 OFFSET " .. (page * 30), params, function(l)
			if not IsValid(ply) then return end
			local liste = {}
			for _, m in ipairs(l or {}) do
				liste[#liste + 1] = { id = tonumber(m.id), date = tonumber(m.date), auteur = m.auteur_nom, sid = m.auteur_sid,
					objet = m.objet, portee = m.portee, destinataires = util.JSONToTable(m.destinataires or "") or {},
					supprimee = tonumber(m.supprimee) == 1 }
			end
			net.Start("origine_courrier_admin_liste")
				ORIGINE.NetEcrireTable({ page = page, missives = liste })
			net.Send(ply)
		end)
	elseif action == "lire" then
		DB.Requete("SELECT * FROM origine_missives WHERE id = ?", { tonumber(a.id) or 0 }, function(l)
			local m = l and l[1]
			if not (m and IsValid(ply)) then return end
			local d = versClient(m)
			d.sid, d.supprimee = m.auteur_sid, tonumber(m.supprimee) == 1
			net.Start("origine_courrier_admin_texte")
				ORIGINE.NetEcrireTable(d)
			net.Send(ply)
		end)
	elseif action == "supprimer" then
		local id = tonumber(a.id) or 0
		DB.Requete("SELECT auteur_sid, auteur_slot, auteur_nom, objet FROM origine_missives WHERE id = ?", { id }, function(l)
			local m = l and l[1]
			if not m then return end
			DB.Requete("UPDATE origine_missives SET supprimee = 1 WHERE id = ?", { id }, function()
				H.Ajouter({ type = "missive", staff = ply, cible_sid = m.auteur_sid, cible_slot = tonumber(m.auteur_slot),
					cible_nom = m.auteur_nom, avant = { missive = id, objet = m.objet }, raison = nettoyer(a.raison, 200) })
				if IsValid(ply) then ORIGINE.Notifier(ply, "Missive supprimée.", "succes") end
			end)
		end)
	end
end, 4)
