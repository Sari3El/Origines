--[[-----------------------------------------------------------------------
	Origine du monde — menu TAB (client)

	Remplace le scoreboard de FAdmin : seuls ses hooks d'ouverture et de
	fermeture sont retirés, le reste de FAdmin n'est pas touché.
	Le client affiche et envoie des demandes ; les actions staff sont des
	commandes ULX, vérifiées par ULX côté serveur.

	Fonctionne sans origine_personnages (noms DarkRP, couleurs par défaut).
-------------------------------------------------------------------------]]

ORIGINE = ORIGINE or {}
ORIGINE.Tab = ORIGINE.Tab or {}
local T = ORIGINE.Tab
-- Normalement déjà chargé par DarkRP (sh_ avant sv_/cl_) ; sécurité si l'ordre change
if not T.Config then include("sh_config.lua") end
T.Donnees = T.Donnees or {}   -- [joueur] = { badge, slot, pv, covan } (slot/pv/covan : staff seulement)
T.Lignes = T.Lignes or {}     -- lignes gardées en cache (avatars inclus)
T.Entetes = T.Entetes or {}
T.EstStaff = T.EstStaff or false

local function CFG() return T.Config end

---------------------------------------------------------------------------
-- Charte : celle de origine_personnages si chargé, sinon celle de la config
---------------------------------------------------------------------------
local function COL()
	return (ORIGINE.UI and ORIGINE.UI.C) or CFG().CouleursParDefaut
end

local function S(v)
	return math.max(1, math.Round(v * math.Clamp(ScrH() / 1080, 0.62, 2.2)))
end

local POLICES = {
	titre = { 30, 700, true },
	sous_titre = { 21, 600, true },
	texte = { 17, 500 },
	texte_gras = { 17, 700 },
	petit = { 14, 500 },
	petit_gras = { 14, 700 },
}

local function creerPolices()
	local charte = ORIGINE.Config and ORIGINE.Config.Charte
	local defaut = CFG().PolicesParDefaut
	for id, d in pairs(POLICES) do
		local famille = d[3] and (charte and charte.PoliceTitre or defaut.Titre) or (charte and charte.PoliceTexte or defaut.Texte)
		surface.CreateFont("origine_tab_" .. id, {
			font = famille, size = S(d[1]), weight = d[2], antialias = true, extended = true,
		})
	end
end

local function P(id) return "origine_tab_" .. id end

local function rect(x, y, w, h, col)
	surface.SetDrawColor(col)
	surface.DrawRect(x, y, w, h)
end

local function contour(x, y, w, h, col, e)
	surface.SetDrawColor(col)
	surface.DrawOutlinedRect(x, y, w, h, e or 1)
end

local function texte(t, police, x, y, col, ax, ay)
	return draw.SimpleText(t, P(police), x, y, col, ax, ay)
end

-- Cadre médiéval (identique à ORIGINE.UI.Cadre, redessiné ici pour marcher seul)
local function cadre(x, y, w, h, fond, surligne)
	if ORIGINE.UI and ORIGINE.UI.Cadre then return ORIGINE.UI.Cadre(x, y, w, h, fond, surligne) end
	local c = COL()
	rect(x, y, w, h, fond or c.Fond)
	contour(x, y, w, h, surligne and c.Or or c.Bordure, S(2))
end

-- Texte coupé avec « … » s'il dépasse la largeur
local function ajuster(t, police, largeur)
	surface.SetFont(P(police))
	if surface.GetTextSize(t) <= largeur then return t end
	local n = utf8.len(t) or #t
	while n > 1 do
		n = n - 1
		local essai = (utf8.offset(t, n + 1) and string.sub(t, 1, utf8.offset(t, n + 1) - 1) or t) .. "…"
		if surface.GetTextSize(essai) <= largeur then return essai end
	end
	return "…"
end

local function bouton(parent, libelle, fn)
	local b = vgui.Create("DButton", parent)
	b:SetText("")
	b.Libelle = libelle
	b.DoClick = function(s)
		surface.PlaySound("ui/buttonclick.wav")
		if fn then fn(s) end
	end
	b.Paint = function(s, w, h)
		local c = COL()
		rect(0, 0, w, h, s:IsHovered() and c.Survol or c.FondClair)
		contour(0, 0, w, h, s:IsHovered() and c.Or or c.Bordure, S(1))
		texte(ajuster(s.Libelle, "petit_gras", w - S(8)), "petit_gras", w / 2, h / 2, c.Texte, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	return b
end

---------------------------------------------------------------------------
-- Infos d'un joueur (avec ou sans origine_personnages)
---------------------------------------------------------------------------
local function nomPerso(ply)
	if ORIGINE.NomComplet then return ORIGINE.NomComplet(ply) end
	return ply:Nick()   -- DarkRP : nom RP
end

local function nomSteam(ply)
	return ply.SteamName and ply:SteamName() or ply:Nick()
end

local function race(ply)
	if not (ORIGINE.RaceJoueur and ORIGINE.NomRace) then return nil end
	local id = ORIGINE.RaceJoueur(ply)
	if not id then return nil end
	return ORIGINE.NomRace(id), ORIGINE.CouleurRace(id)
end

local function enSelection(ply)
	if ORIGINE.EquipeSelection and ply:Team() == ORIGINE.EquipeSelection then return true end
	local job = RPExtraTeams and RPExtraTeams[ply:Team()]
	return job and job.origine_cache or false
end

local function couleurPing(p)
	local cfg = CFG()
	if p < cfg.Ping.Vert then return cfg.CouleurPingVert end
	if p < cfg.Ping.Orange then return cfg.CouleurPingOrange end
	return cfg.CouleurPingRouge
end

local function aPermission(permission)
	local lp = LocalPlayer()
	if ULib and ULib.ucl and ULib.ucl.query then return ULib.ucl.query(lp, permission) == true end
	return lp:IsAdmin()
end

-- Commande ULX disponible : elle existe et le staff en a la permission
local function ulxDispo(cmd)
	if not (ULib and ULib.cmds and ULib.cmds.translatedCmds) then return false end
	return ULib.cmds.translatedCmds[cmd] ~= nil and aPermission(cmd)
end

local function cibleUlx(ply)
	if ply:IsBot() then return ply:Nick() end
	return "$" .. ply:SteamID()
end

local function lancerUlx(cmd, cible, valeurs)
	local args = string.Explode(" ", cmd)
	table.remove(args, 1) -- « ulx »
	if cible then args[#args + 1] = cibleUlx(cible) end
	for _, v in ipairs(valeurs or {}) do args[#args + 1] = v end
	RunConsoleCommand("ulx", unpack(args))
end

-- Fenêtre de saisie : reste ouverte même quand TAB est relâché
local function demander(titre, champs, fn)
	if ORIGINE.UI and ORIGINE.UI.Demander then return ORIGINE.UI.Demander(titre, champs, fn) end
	local valeurs = {}
	local function suivant(i)
		if i > #champs then return fn(valeurs) end
		Derma_StringRequest(titre, champs[i].libelle or "", champs[i].valeur or "", function(v)
			valeurs[i] = v
			suivant(i + 1)
		end)
	end
	suivant(1)
end

local function executer(action, cible)
	if action.args and #action.args > 0 then
		local titre = action.Nom .. (cible and (" — " .. nomPerso(cible)) or "")
		demander(titre, action.args, function(valeurs)
			if cible and not IsValid(cible) then return end
			lancerUlx(action.ulx, cible, valeurs)
		end)
	else
		lancerUlx(action.ulx, cible)
	end
end

---------------------------------------------------------------------------
-- Réseau
---------------------------------------------------------------------------
local function demanderDonnees()
	net.Start("origine_tab_demande")
	net.SendToServer()
end

net.Receive("origine_tab_donnees", function()
	local staff = net.ReadBool()
	local donnees = {}
	for _ = 1, net.ReadUInt(8) do
		local p = net.ReadEntity()
		local d = {}
		if staff then
			d.badge = net.ReadUInt(2)
			d.slot = net.ReadUInt(4)
			d.pv = net.ReadInt(16)
			d.covan = net.ReadDouble()
		end
		if IsValid(p) then donnees[p] = d end
	end
	T.EstStaff, T.Donnees = staff, donnees
	if T.Visible() then T.Rafraichir() end
end)

---------------------------------------------------------------------------
-- Groupes : catégories de jobs DarkRP, dans l'ordre du F4
---------------------------------------------------------------------------
local function categoriesOrdonnees()
	local liste = {}
	local cats = DarkRP and DarkRP.getCategories and DarkRP.getCategories()
	for i, cat in ipairs(cats and cats.jobs or {}) do
		liste[#liste + 1] = { nom = cat.name, couleur = cat.color, ordre = cat.sortOrder or 100, i = i }
	end
	table.sort(liste, function(a, b)
		if a.ordre ~= b.ordre then return a.ordre < b.ordre end
		return a.i < b.i
	end)
	return liste
end

local function filtre(ply, recherche)
	if recherche == "" then return true end
	local function contient(s) return string.find(string.lower(s or ""), recherche, 1, true) ~= nil end
	-- Joueurs : nom Steam et SteamID seulement ; staff : aussi le nom du personnage
	if T.EstStaff and contient(nomPerso(ply)) then return true end
	return contient(nomSteam(ply)) or contient(ply:SteamID()) or contient(ply:SteamID64())
end

-- Retourne { { cle, nom, couleur, joueurs = {...} }, ... } sans les groupes vides
local function construireGroupes(recherche)
	local cfg = CFG()
	-- Joueurs : un seul groupe trié par nom Steam (les catégories de job trahiraient le RP)
	if not T.EstStaff then
		local tous = { cle = "joueurs", nom = cfg.GroupeJoueurs, couleur = COL().Or, joueurs = {} }
		local selection = { cle = "selection", nom = cfg.GroupeSelection, couleur = COL().Grise, joueurs = {} }
		for _, p in ipairs(player.GetAll()) do
			if filtre(p, recherche) then table.insert(enSelection(p) and selection.joueurs or tous.joueurs, p) end
		end
		local resultat = {}
		for _, g in ipairs({ tous, selection }) do
			if #g.joueurs > 0 then
				table.sort(g.joueurs, function(a, b) return string.lower(nomSteam(a)) < string.lower(nomSteam(b)) end)
				resultat[#resultat + 1] = g
			end
		end
		return resultat
	end
	local groupes, parNom = {}, {}
	for _, cat in ipairs(categoriesOrdonnees()) do
		local g = { cle = "cat_" .. cat.nom, nom = cat.nom, couleur = cat.couleur or COL().Or, joueurs = {} }
		groupes[#groupes + 1] = g
		parNom[cat.nom] = g
	end
	local autres = { cle = "autres", nom = cfg.GroupeSansCategorie, couleur = COL().TexteSombre, joueurs = {} }
	local selection = { cle = "selection", nom = cfg.GroupeSelection, couleur = COL().Grise, joueurs = {} }
	groupes[#groupes + 1] = autres
	groupes[#groupes + 1] = selection

	for _, p in ipairs(player.GetAll()) do
		if filtre(p, recherche) then
			local g
			if enSelection(p) then g = selection
			else
				local job = RPExtraTeams and RPExtraTeams[p:Team()]
				g = job and job.category and parNom[job.category] or autres
			end
			table.insert(g.joueurs, p)
		end
	end

	local resultat = {}
	for _, g in ipairs(groupes) do
		if #g.joueurs > 0 then
			-- Tri par métier (ordre du F4) puis par nom
			table.sort(g.joueurs, function(a, b)
				local ja, jb = RPExtraTeams and RPExtraTeams[a:Team()], RPExtraTeams and RPExtraTeams[b:Team()]
				local oa, ob = ja and ja.sortOrder or 100, jb and jb.sortOrder or 100
				if oa ~= ob then return oa < ob end
				if a:Team() ~= b:Team() then return a:Team() < b:Team() end
				return string.lower(nomPerso(a)) < string.lower(nomPerso(b))
			end)
			resultat[#resultat + 1] = g
		end
	end
	return resultat
end

---------------------------------------------------------------------------
-- Ligne d'un joueur (gardée en cache tant que le joueur est connecté)
---------------------------------------------------------------------------
local HAUTEUR_LIGNE = 44

local function infosLigne(ply)
	-- Joueurs : seulement le nom Steam, le SteamID et le ping
	if not T.EstStaff then
		return { nom = nomSteam(ply), steamid = ply:SteamID(), ping = ply:Ping(), couleurJob = COL().Or, badge = 0 }
	end
	local d = T.Donnees[ply] or {}
	local nomR, couleurR = race(ply)
	local job = team.GetName(ply:Team()) or ""
	local i = {
		nom = nomPerso(ply),
		race = nomR, couleurRace = couleurR,
		job = job, couleurJob = team.GetColor(ply:Team()),
		badge = d.badge or 0,
		ping = ply:Ping(),
	}
	if T.EstStaff then
		i.steam = nomSteam(ply)
		i.steamid = ply:SteamID()
		i.slot = d.slot
		i.km = ply:Frags() .. " / " .. ply:Deaths()
	end
	return i
end

local function dessinerBadge(b, x, y, centre)
	local cfg = CFG()
	local libelle, col
	if b == 2 then libelle, col = "STAFF", cfg.CouleurBadgeStaff
	elseif b == 1 then libelle, col = "EVENT", cfg.CouleurBadgeEvent
	else return 0 end
	surface.SetFont(P("petit_gras"))
	local tw, th = surface.GetTextSize(libelle)
	local w, h = tw + S(12), th + S(4)
	if centre then x = x - w / 2 end
	rect(x, y - h / 2, w, h, Color(col.r, col.g, col.b, 60))
	contour(x, y - h / 2, w, h, col, 1)
	texte(libelle, "petit_gras", x + w / 2, y, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	return w
end

local function creerLigne(ply)
	local l = vgui.Create("DButton")
	l:SetText("")
	l:SetTall(S(HAUTEUR_LIGNE))
	l:DockMargin(0, 0, 0, S(3))
	l.Joueur = ply
	l.Infos = infosLigne(ply)

	-- Avatar Steam, créé une fois et gardé
	l.Avatar = vgui.Create("AvatarImage", l)
	l.Avatar:SetPlayer(ply, 64)
	l.Avatar:SetMouseInputEnabled(false)

	l.PerformLayout = function(s, w, h)
		local a = h - S(10)
		s.Avatar:SetSize(a, a)
		s.Avatar:SetPos(S(12), S(5))
	end

	l.DoClick = function(s)
		surface.PlaySound("ui/buttonclick.wav")
		T.Selection = s.Joueur
		T.AfficherFiche(s.Joueur)
	end

	l.Paint = function(s, w, h)
		local c, i = COL(), s.Infos
		local choisi = T.Selection == s.Joueur
		rect(0, 0, w, h, (s:IsHovered() or choisi) and c.Survol or c.FondClair)
		if choisi then contour(0, 0, w, h, c.Or, S(1)) end
		rect(0, 0, S(4), h, i.couleurJob)

		local x = S(12) + (h - S(10)) + S(10)

		-- Joueurs : nom Steam, SteamID, ping
		if not T.EstStaff then
			texte(ajuster(i.nom, "texte_gras", w * 0.6), "texte_gras", x, h / 2 - S(8), c.Texte, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			texte(i.steamid, "petit", x, h / 2 + S(10), c.TexteSombre, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			texte(i.ping .. " ms", "petit_gras", w - S(12), h / 2, couleurPing(i.ping), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			return
		end

		-- Nom du personnage et race
		local largeurNom = math.floor(w * 0.28)
		texte(ajuster(i.nom, "texte_gras", largeurNom), "texte_gras", x, h / 2 - (i.race and S(8) or 0), c.Texte, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		if i.race then
			texte(ajuster(i.race, "petit", largeurNom), "petit", x, h / 2 + S(10), i.couleurRace or c.TexteSombre, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		x = x + largeurNom + S(10)

		-- Métier et badge
		local largeurJob = math.floor(w * 0.22)
		texte(ajuster(i.job, "texte", largeurJob), "texte", x, h / 2, i.couleurJob, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		x = x + largeurJob + S(8)
		dessinerBadge(i.badge, x, h / 2)

		-- Ping (tous)
		texte(i.ping .. " ms", "petit_gras", w - S(12), h / 2, couleurPing(i.ping), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		-- Zone staff : nom Steam, SteamID, slot, K/M
		if T.EstStaff and i.steam then
			local xs = w - S(80)
			local largeur = math.floor(w * 0.26)
			texte(ajuster(i.steam, "petit_gras", largeur), "petit_gras", xs, h / 2 - S(8), c.TexteSombre, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			local bas = i.steamid .. "  ·  slot " .. (i.slot and i.slot > 0 and i.slot or "—") .. "  ·  K/M " .. i.km
			texte(ajuster(bas, "petit", largeur), "petit", xs, h / 2 + S(10), c.TexteSombre, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end
	return l
end

local function creerEntete()
	local e = vgui.Create("DPanel")
	e:SetTall(S(30))
	e:DockMargin(0, S(6), 0, S(4))
	e.Paint = function(s, w, h)
		local c = COL()
		local col = s.Couleur or c.Or
		texte(s.Nom or "", "sous_titre", S(4), h / 2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetFont(P("sous_titre"))
		local tw = surface.GetTextSize(s.Nom or "")
		texte("(" .. (s.Nombre or 0) .. ")", "texte", S(12) + tw, h / 2, c.TexteSombre, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetDrawColor(col.r, col.g, col.b, 120)
		surface.DrawRect(0, h - 1, w, 1)
	end
	return e
end

---------------------------------------------------------------------------
-- Rafraîchissement de la liste (ouverture, toutes les 2 s, recherche)
---------------------------------------------------------------------------
function T.Rafraichir()
	if not IsValid(T.Liste) then return end
	local canvas = T.Liste:GetCanvas()
	local recherche = string.lower(string.Trim(IsValid(T.Recherche) and T.Recherche:GetText() or ""))

	-- Joueurs partis : lignes supprimées
	for p, l in pairs(T.Lignes) do
		if not IsValid(p) then
			if IsValid(l) then l:Remove() end
			T.Lignes[p] = nil
		elseif IsValid(l) then
			l:SetVisible(false)
		end
	end
	for _, e in pairs(T.Entetes) do
		if IsValid(e) then e:SetVisible(false) end
	end

	local z = 0
	for _, g in ipairs(construireGroupes(recherche)) do
		local e = T.Entetes[g.cle]
		if not IsValid(e) then
			e = creerEntete()
			e:SetParent(canvas)
			e:Dock(TOP)
			T.Entetes[g.cle] = e
		end
		e.Nom, e.Couleur, e.Nombre = g.nom, g.couleur, #g.joueurs
		z = z + 1
		e:SetZPos(z)
		e:SetVisible(true)
		for _, p in ipairs(g.joueurs) do
			local l = T.Lignes[p]
			if not IsValid(l) then
				l = creerLigne(p)
				l:SetParent(canvas)
				l:Dock(TOP)
				T.Lignes[p] = l
			end
			l.Infos = infosLigne(p)
			z = z + 1
			l:SetZPos(z)
			l:SetVisible(true)
			l:InvalidateLayout()
		end
	end
	canvas:InvalidateLayout()

	if T.Selection and not IsValid(T.Selection) then
		T.Selection = nil
		T.AfficherFiche(nil)
	end
	if IsValid(T.BoutonServeur) then T.BoutonServeur:SetVisible(T.ActionsServeurDispo()) end
end

---------------------------------------------------------------------------
-- Fiche joueur (panneau de droite)
---------------------------------------------------------------------------
function T.ActionsServeurDispo()
	for _, a in ipairs(CFG().ActionsServeur) do
		if ulxDispo(a.ulx) then return true end
	end
	return false
end

-- valeur : texte, ou fonction qui renvoie (texte, couleur) pour les infos qui changent
local function ligneInfo(parent, libelle, valeur, couleur)
	local p = vgui.Create("DPanel", parent)
	p:Dock(TOP)
	p:SetTall(S(22))
	p.Paint = function(_, w, h)
		local c = COL()
		texte(libelle, "petit", 0, h / 2, c.TexteSombre, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		local v, col = valeur, couleur
		if isfunction(valeur) then v, col = valeur() end
		texte(ajuster(tostring(v), "petit_gras", w * 0.62), "petit_gras", w, h / 2, col or c.Texte, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
	return p
end

local function grilleBoutons(parent)
	local g = vgui.Create("DIconLayout", parent)
	g:Dock(TOP)
	g:SetSpaceX(S(6))
	g:SetSpaceY(S(6))
	g:DockMargin(0, S(6), 0, S(4))
	return g
end

local function ajouterBouton(grille, libelle, fn)
	local b = bouton(grille, libelle, fn)
	b:SetSize(math.floor((T.Fiche:GetWide() - S(24) - S(12)) / 2), S(30))
	return b
end

local function titreSection(parent, t)
	local p = vgui.Create("DPanel", parent)
	p:Dock(TOP)
	p:SetTall(S(26))
	p:DockMargin(0, S(8), 0, 0)
	p.Paint = function(_, w, h)
		local c = COL()
		texte(t, "texte_gras", 0, h / 2, c.Or, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetDrawColor(c.Or.r, c.Or.g, c.Or.b, 90)
		surface.DrawRect(0, h - 1, w, 1)
	end
end

local function changerJob(cible)
	local function envoyer(commande)
		if not IsValid(cible) then return end
		net.Start("origine_tab_job")
			net.WriteEntity(cible)
			net.WriteString(commande)
		net.SendToServer()
	end
	if ORIGINE.Staff and ORIGINE.Staff.ChoisirJob then
		return ORIGINE.Staff.ChoisirJob("Changer le job — " .. nomPerso(cible), envoyer)
	end
	local menu = DermaMenu()
	for t, job in SortedPairs(RPExtraTeams or {}) do
		if t ~= ORIGINE.EquipeSelection and not job.origine_cache then
			menu:AddOption(job.name, function() envoyer(job.command) end)
		end
	end
	menu:Open()
end

function T.AfficherFiche(ply)
	if not IsValid(T.Fiche) then return end
	local fiche = T.Fiche
	fiche.Contenu:Clear()
	fiche:SetVisible(IsValid(ply))
	T.Cadre:InvalidateLayout()
	if not IsValid(ply) then return end
	local c = COL()
	local corps = fiche.Contenu
	local mp = fiche.Modele
	mp:SetVisible(T.EstStaff)

	-- Joueurs : nom Steam, SteamID, profil Steam, ping, voix (aucune info RP)
	if not T.EstStaff then
		local entete = vgui.Create("DPanel", corps)
		entete:Dock(TOP)
		entete:SetTall(S(36))
		local nom = nomSteam(ply)
		entete.Paint = function(_, w)
			texte(ajuster(nom, "sous_titre", w), "sous_titre", w / 2, S(4), c.Texte, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		end
		ligneInfo(corps, "SteamID", ply:SteamID())
		ligneInfo(corps, "Ping", function()
			if not IsValid(ply) then return "—" end
			local p = ply:Ping()
			return p .. " ms", couleurPing(p)
		end)
		local g = grilleBoutons(corps)
		ajouterBouton(g, "Copier le SteamID", function() SetClipboardText(ply:SteamID()) end)
		ajouterBouton(g, "Profil Steam", function() if IsValid(ply) then ply:ShowProfile() end end)
		if ply ~= LocalPlayer() then
			local voix = bouton(corps, ply:IsMuted() and "Rétablir sa voix (pour moi)" or "Couper sa voix (pour moi)", function(b)
				if not IsValid(ply) then return end
				ply:SetMuted(not ply:IsMuted())
				b.Libelle = ply:IsMuted() and "Rétablir sa voix (pour moi)" or "Couper sa voix (pour moi)"
			end)
			voix:Dock(TOP)
			voix:SetTall(S(30))
			voix:DockMargin(0, S(4), 0, 0)
		end
		return
	end

	-- Aperçu 3D (un seul panneau, modèle changé seulement s'il diffère)
	local modele = ply:GetModel() or ""
	if mp.ModeleActuel ~= modele then
		mp:SetModel(modele)
		mp.ModeleActuel = modele
		local ent = mp:GetEntity()
		if IsValid(ent) then
			local tete = ent:LookupBone("ValveBiped.Bip01_Head1")
			local pos = tete and ent:GetBonePosition(tete) or (ent:GetPos() + Vector(0, 0, 60))
			mp:SetLookAt(pos - Vector(0, 0, 18))
			mp:SetCamPos(pos + Vector(52, 10, -6))
			mp:SetFOV(38)
		end
	end
	local ent = mp:GetEntity()
	if IsValid(ent) then
		ent:SetSkin(ply:GetSkin())
		for i = 0, ply:GetNumBodyGroups() - 1 do ent:SetBodygroup(i, ply:GetBodygroup(i)) end
	end

	local i = infosLigne(ply)
	local entete = vgui.Create("DPanel", corps)
	entete:Dock(TOP)
	entete:SetTall(S(i.badge > 0 and 84 or 62))
	entete.Paint = function(_, w)
		texte(ajuster(i.nom, "sous_titre", w), "sous_titre", w / 2, S(4), c.Texte, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		if i.race then
			texte(i.race, "texte", w / 2, S(34), i.couleurRace or c.TexteSombre, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		end
		dessinerBadge(i.badge, w / 2, S(70), true)
	end
	ligneInfo(corps, "Métier", i.job, i.couleurJob)
	ligneInfo(corps, "Ping", function()
		if not IsValid(ply) then return "—" end
		local p = ply:Ping()
		return p .. " ms", couleurPing(p)
	end)

	-- Voix : pour soi uniquement
	if ply ~= LocalPlayer() then
		local voix = bouton(corps, ply:IsMuted() and "Rétablir sa voix (pour moi)" or "Couper sa voix (pour moi)", function(s)
			if not IsValid(ply) then return end
			ply:SetMuted(not ply:IsMuted())
			s.Libelle = ply:IsMuted() and "Rétablir sa voix (pour moi)" or "Couper sa voix (pour moi)"
		end)
		voix:Dock(TOP)
		voix:SetTall(S(30))
		voix:DockMargin(0, S(8), 0, 0)
	end

	if not T.EstStaff then return end
	local function donnee(cle) return (T.Donnees[ply] or {})[cle] end

	titreSection(corps, "Staff")
	ligneInfo(corps, "Nom Steam", nomSteam(ply))
	ligneInfo(corps, "SteamID", ply:SteamID())
	ligneInfo(corps, "Slot joué", function()
		local sl = donnee("slot")
		return sl and sl > 0 and sl or "—"
	end)
	ligneInfo(corps, "Rang", function() return IsValid(ply) and ply:GetUserGroup() or "—" end)
	ligneInfo(corps, "Kills / morts", function() return IsValid(ply) and (ply:Frags() .. " / " .. ply:Deaths()) or "—" end)
	ligneInfo(corps, "Points de vie", function() return donnee("pv") or "—", c.PV end)
	ligneInfo(corps, "Covan", function()
		local covan = donnee("covan") or 0
		return ORIGINE.FormaterCovan and ORIGINE.FormaterCovan(covan) or tostring(covan), c.Or
	end)

	local g = grilleBoutons(corps)
	ajouterBouton(g, "Copier le SteamID", function()
		SetClipboardText(ply:SteamID())
		if ORIGINE.UI and ORIGINE.UI.Notifier then ORIGINE.UI.Notifier("SteamID copié.", "succes") end
	end)
	ajouterBouton(g, "Profil Steam", function() if IsValid(ply) then ply:ShowProfile() end end)
	if ORIGINE.Staff and ORIGINE.Staff.OuvrirFicheJoueur and aPermission("origine_menu") then
		ajouterBouton(g, "Ouvrir dans !origine", function()
			if not IsValid(ply) then return end
			ORIGINE.Staff.FicheEnAttente = ply:SteamID64()
			RunConsoleCommand("origine")
			T.Fermer()
		end)
	end

	-- Actions : seulement celles que le staff a le droit de lancer
	local boutons = {}
	for _, a in ipairs(CFG().Actions) do
		if a.permission then
			if aPermission(a.permission) and a.id == "job" then
				boutons[#boutons + 1] = { a.Nom, function() if IsValid(ply) then changerJob(ply) end end }
			end
		else
			if ulxDispo(a.ulx) then
				boutons[#boutons + 1] = { a.Nom, function() if IsValid(ply) then executer(a, ply) end end }
			end
			if a.inverse and ulxDispo(a.inverse.ulx) then
				local inv = { Nom = a.inverse.Nom, ulx = a.inverse.ulx }
				boutons[#boutons + 1] = { inv.Nom, function() if IsValid(ply) then executer(inv, ply) end end }
			end
		end
	end
	if #boutons > 0 then
		titreSection(corps, "Actions")
		local ga = grilleBoutons(corps)
		for _, b in ipairs(boutons) do ajouterBouton(ga, b[1], b[2]) end
	end
end

---------------------------------------------------------------------------
-- Actions serveur (bouton « Serveur » de l'en-tête)
---------------------------------------------------------------------------
local function ouvrirActionsServeur()
	local menu = DermaMenu()
	for _, a in ipairs(CFG().ActionsServeur) do
		if ulxDispo(a.ulx) then
			menu:AddOption(a.Nom, function() executer(a, nil) end)
		end
	end
	menu:Open()
end

---------------------------------------------------------------------------
-- Fenêtre principale (créée une fois, cachée à la fermeture)
---------------------------------------------------------------------------
local function construire()
	local cfg = CFG()
	local w, h = math.min(ScrW() - S(40), S(1180)), math.min(ScrH() - S(40), S(820))
	local f = vgui.Create("EditablePanel")
	f:SetSize(w, h)
	f:Center()
	f:SetVisible(false)
	T.Cadre = f
	f.Paint = function(_, pw, ph)
		cadre(0, 0, pw, ph, COL().Fond)
	end
	f:DockPadding(S(16), S(12), S(16), S(16))

	-- En-tête : nom du serveur, joueurs connectés, liens
	local entete = vgui.Create("DPanel", f)
	entete:Dock(TOP)
	entete:SetTall(S(50))
	entete.Paint = function(_, ew, eh)
		local c = COL()
		texte(cfg.NomServeur, "titre", 0, eh / 2, c.Or, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetFont(P("titre"))
		local tw = surface.GetTextSize(cfg.NomServeur)
		texte(player.GetCount() .. " / " .. game.MaxPlayers() .. " joueurs", "texte", tw + S(18), eh / 2 + S(3), c.TexteSombre, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		-- Tickets en attente (origine_tickets), pour le staff
		local tk = ORIGINE.Tickets
		if T.EstStaff and tk and tk.EnAttente then
			surface.SetFont(P("texte"))
			local jw = surface.GetTextSize(player.GetCount() .. " / " .. game.MaxPlayers() .. " joueurs")
			texte("·  " .. tk.EnAttente .. " ticket(s) en attente (F6)", "texte", tw + S(30) + jw, eh / 2 + S(3),
				tk.EnAttente > 0 and c.Alerte or c.TexteSombre, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end
	for n = #cfg.Liens, 1, -1 do
		local lien = cfg.Liens[n]
		if lien.Url ~= "" then
			local b = bouton(entete, lien.Nom, function() gui.OpenURL(lien.Url) end)
			b:Dock(RIGHT)
			b:DockMargin(S(6), S(9), 0, S(9))
			surface.SetFont(P("petit_gras"))
			b:SetWide(surface.GetTextSize(lien.Nom) + S(28))
		end
	end

	-- Barre de recherche (+ bouton Serveur pour le staff)
	local barre = vgui.Create("DPanel", f)
	barre:Dock(TOP)
	barre:SetTall(S(34))
	barre:DockMargin(0, S(6), 0, S(8))
	barre.Paint = nil

	local r = vgui.Create("DTextEntry", barre)
	r:Dock(FILL)
	r:SetFont(P("texte"))
	r:SetPaintBackground(false)
	r:SetTextInset(S(8), 0)
	r:SetUpdateOnType(true)
	r.Paint = function(s, rw, rh)
		local c = COL()
		rect(0, 0, rw, rh, Color(16, 12, 9, 230))
		contour(0, 0, rw, rh, s:HasFocus() and c.Or or c.Bordure, S(1))
		if s:GetText() == "" and not s:HasFocus() then
			local indication = T.EstStaff and "Rechercher (personnage, nom Steam ou SteamID)…" or "Rechercher (nom Steam ou SteamID)…"
			texte(indication, "texte", S(8), rh / 2, c.TexteSombre, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		s:DrawTextEntryText(c.Texte, c.Or, c.Texte)
	end
	r.OnValueChange = function() T.Rafraichir() end
	-- Le clavier n'est pris que pendant la saisie (sinon TAB relâché ne serait plus vu)
	r.OnGetFocus = function() f:SetKeyboardInputEnabled(true) end
	r.OnLoseFocus = function() f:SetKeyboardInputEnabled(false) end
	T.Recherche = r

	local bs = bouton(barre, "Serveur", ouvrirActionsServeur)
	bs:Dock(RIGHT)
	bs:SetWide(S(140))
	bs:DockMargin(S(8), 0, 0, 0)
	bs:SetVisible(false)
	T.BoutonServeur = bs

	-- Fiche (droite)
	local fiche = vgui.Create("DPanel", f)
	fiche:Dock(RIGHT)
	fiche:SetWide(math.floor(w * 0.32))
	fiche:DockMargin(S(12), 0, 0, 0)
	fiche:DockPadding(S(12), S(12), S(12), S(12))
	fiche:SetVisible(false)
	fiche.Paint = function(_, fw, fh) cadre(0, 0, fw, fh, COL().FondClair) end
	T.Fiche = fiche

	local mp = vgui.Create("DModelPanel", fiche)
	mp:Dock(TOP)
	mp:SetTall(math.floor(h * 0.3))
	mp.LayoutEntity = function(_, ent) ent:SetAngles(Angle(0, 20, 0)) end
	fiche.Modele = mp

	local contenu = vgui.Create("DScrollPanel", fiche)
	contenu:Dock(FILL)
	contenu:DockMargin(0, S(6), 0, 0)
	local barreV = contenu:GetVBar()
	barreV:SetWide(S(6))
	barreV:SetHideButtons(true)
	barreV.Paint = nil
	barreV.btnGrip.Paint = function(_, gw, gh) rect(0, 0, gw, gh, COL().Bordure) end
	fiche.Contenu = contenu

	-- Liste des joueurs
	local liste = vgui.Create("DScrollPanel", f)
	liste:Dock(FILL)
	local vb = liste:GetVBar()
	vb:SetWide(S(8))
	vb:SetHideButtons(true)
	vb.Paint = function(_, bw, bh) rect(0, 0, bw, bh, Color(0, 0, 0, 80)) end
	vb.btnGrip.Paint = function(_, gw, gh) rect(0, 0, gw, gh, COL().Bordure) end
	T.Liste = liste

	-- Mise à jour toutes les 2 s tant que le TAB est ouvert (Think ne tourne pas quand il est caché)
	f.Think = function(s)
		if CurTime() >= (s.ProchaineMaj or 0) then
			s.ProchaineMaj = CurTime() + cfg.Rafraichissement
			demanderDonnees()
		end
		-- Pendant la saisie, le clavier est capté : TAB relâché est vu ici
		if s:IsKeyboardInputEnabled() and T.ToucheTab and not input.IsKeyDown(T.ToucheTab) then
			T.Fermer()
		end
	end
end

local function detruire()
	if IsValid(T.Cadre) then T.Cadre:Remove() end
	for _, l in pairs(T.Lignes) do if IsValid(l) then l:Remove() end end
	T.Lignes, T.Entetes = {}, {}
	T.Cadre, T.Liste, T.Fiche = nil, nil, nil
end

function T.Visible()
	return IsValid(T.Cadre) and T.Cadre:IsVisible()
end
ORIGINE.TabOuvert = T.Visible

function T.Ouvrir()
	if ORIGINE.MenuOuvert and ORIGINE.MenuOuvert() then return end
	if ORIGINE.EnMenu and IsValid(LocalPlayer()) and ORIGINE.EnMenu(LocalPlayer()) then return end
	if not IsValid(T.Cadre) then construire() end
	local touche = input.LookupBinding("+showscores")
	T.ToucheTab = touche and input.GetKeyCode(touche) or KEY_TAB
	T.Cadre:SetVisible(true)
	T.Cadre:MakePopup()
	T.Cadre:SetKeyboardInputEnabled(false)
	T.Cadre.ProchaineMaj = 0
	T.Rafraichir()
end

function T.Fermer()
	if not IsValid(T.Cadre) then return end
	if IsValid(T.Recherche) then T.Recherche:KillFocus() end
	T.Cadre:SetKeyboardInputEnabled(false)
	T.Cadre:SetMouseInputEnabled(false)
	T.Cadre:SetVisible(false)
	CloseDermaMenus()
end

---------------------------------------------------------------------------
-- Remplacement du scoreboard FAdmin (seulement ses hooks d'ouverture/fermeture)
---------------------------------------------------------------------------
local function retirerFAdmin()
	hook.Remove("ScoreboardShow", "FAdmin_scoreboard")
	hook.Remove("ScoreboardHide", "FAdmin_scoreboard")
	-- Au cas où FAdmin renommerait ses hooks dans une mise à jour
	local tous = hook.GetTable()
	for _, ev in ipairs({ "ScoreboardShow", "ScoreboardHide" }) do
		for id in pairs(tous[ev] or {}) do
			if isstring(id) and string.find(string.lower(id), "fadmin", 1, true) then hook.Remove(ev, id) end
		end
	end
end

hook.Add("ScoreboardShow", "origine_tab", function()
	retirerFAdmin()
	T.Ouvrir()
	return true
end)

hook.Add("ScoreboardHide", "origine_tab", function()
	T.Fermer()
	return true
end)

hook.Add("InitPostEntity", "origine_tab", function()
	retirerFAdmin()
	timer.Simple(5, retirerFAdmin)
end)
retirerFAdmin()

creerPolices()
hook.Add("OnScreenSizeChanged", "origine_tab", function()
	creerPolices()
	detruire()
end)
