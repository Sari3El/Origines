--[[-----------------------------------------------------------------------
	Origine du monde — menu personnage (client)

	Le client affiche et envoie des demandes ; le serveur décide de tout.
-------------------------------------------------------------------------]]

local UI = ORIGINE.UI
local COL = UI.C
local C = ORIGINE.Config

ORIGINE.Menu = ORIGINE.Menu or {}
local M = ORIGINE.Menu
M.Selection = M.Selection or 1
M.Chat = M.Chat or {}

local MODELE_DEFAUT = "models/player/kleiner.mdl"

function ORIGINE.MenuOuvert()
	return IsValid(M.Panneau)
end

local function formaterDate(t)
	if not t then return "jamais" end
	return os.date("%d/%m/%Y à %H:%M", t)
end

local function modeleValide(m)
	if isstring(m) and m ~= "" and util.IsValidModel(m) then return m end
	return MODELE_DEFAUT
end

local function envoyer(nom, slot, ...)
	net.Start(nom)
	net.WriteUInt(slot, 4)
	for _, v in ipairs({ ... }) do net.WriteString(v) end
	net.SendToServer()
end

local function infoSlot(slot)
	return M.Donnees and M.Donnees.slots and M.Donnees.slots[slot]
end

-- Cadre la caméra d'un DModelPanel sur tout le corps
local function cadrerCorps(mp)
	mp:SetFOV(36)
	mp:SetCamPos(Vector(82, 0, 44))
	mp:SetLookAt(Vector(0, 0, 38))
end

---------------------------------------------------------------------------
-- Cartes de slot
---------------------------------------------------------------------------
local function creerCarte(parent, slot)
	local carte = vgui.Create("DButton", parent)
	carte:SetText("")
	carte.DoClick = function()
		surface.PlaySound("ui/buttonclick.wav")
		M.Selectionner(slot)
	end

	local mp = vgui.Create("DModelPanel", carte)
	mp:SetMouseInputEnabled(false)
	mp.LayoutEntity = function(_, ent)
		ent:SetAngles(Angle(0, 20 + math.sin(CurTime() * 0.6) * 20, 0))
	end
	carte.Modele = mp

	carte.PerformLayout = function(_, w, h)
		mp:SetPos(UI.S(10), UI.S(44))
		mp:SetSize(w - UI.S(20), h - UI.S(44) - UI.S(122))
	end

	carte.MettreAJour = function()
		local info = infoSlot(slot)
		if info and info.perso then
			mp:SetVisible(true)
			local m = modeleValide(info.perso.modele)
			if mp.ModeleActuel ~= m then
				mp:SetModel(m)
				mp.ModeleActuel = m
				cadrerCorps(mp)
			end
		else
			mp:SetVisible(false)
		end
	end

	carte.Paint = function(s, w, h)
		local info = infoSlot(slot)
		if not info then return end
		local choisi = M.Selection == slot
		UI.Cadre(0, 0, w, h, choisi and COL.FondClair or COL.Fond, choisi or s:IsHovered())
		UI.Texte(C.Slots[slot].Nom, "sous_titre", w / 2, UI.S(12), COL.Or, TEXT_ALIGN_CENTER)

		local p = info.perso
		local y = h - UI.S(116)
		if p then
			UI.Separateur(UI.S(16), y - UI.S(8), w - UI.S(32))
			UI.Texte(p.prenom .. " " .. p.nom, "texte_gras", w / 2, y, COL.Texte, TEXT_ALIGN_CENTER)
			UI.Texte(ORIGINE.NomRace(p.race), "texte", w / 2, y + UI.S(24), ORIGINE.CouleurRace(p.race), TEXT_ALIGN_CENTER)
			local etat = p.job or "Sans métier"
			if not p.valide then etat = "Tirage à valider"
			elseif p.nom_a_redonner then etat = "Nouveau nom à donner" end
			UI.Texte(etat, "petit", w / 2, y + UI.S(50), COL.TexteSombre, TEXT_ALIGN_CENTER)
			UI.Texte("Dernière connexion :", "petit", w / 2, y + UI.S(72), COL.TexteSombre, TEXT_ALIGN_CENTER)
			UI.Texte(formaterDate(p.derniere), "petit", w / 2, y + UI.S(90), COL.TexteSombre, TEXT_ALIGN_CENTER)
		elseif info.acces then
			UI.Texte("+", "geant", w / 2, h / 2 - UI.S(30), COL.Or, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			UI.Texte("Nouveau personnage", "texte", w / 2, h / 2 + UI.S(20), COL.TexteSombre, TEXT_ALIGN_CENTER)
		end
	end

	-- Slot verrouillé : visible, grisé, avec sa raison
	carte.PaintOver = function(_, w, h)
		local info = infoSlot(slot)
		if not info or info.acces then return end
		UI.Rect(0, 0, w, h, Color(18, 16, 14, 190))
		UI.Contour(0, 0, w, h, COL.Grise, UI.S(2))
		UI.Texte("Verrouillé", "sous_titre", w / 2, h / 2 - UI.S(16), COL.TexteSombre, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		UI.Texte(info.raison or "", "texte", w / 2, h / 2 + UI.S(14), COL.TexteSombre, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	return carte
end

---------------------------------------------------------------------------
-- Superposition (dialogues, roulette, lignées)
---------------------------------------------------------------------------
local function superposition()
	if IsValid(M.Superposition) then M.Superposition:Remove() end
	local s = vgui.Create("DPanel", M.Panneau)
	s:SetSize(M.Panneau:GetWide(), M.Panneau:GetTall())
	s.Paint = function(_, w, h) UI.Rect(0, 0, w, h, Color(0, 0, 0, 190)) end
	M.Superposition = s
	return s
end

local function boite(parent, w, h, titre)
	local b = vgui.Create("DPanel", parent)
	b:SetSize(w, h)
	b:Center()
	b.Titre = titre
	b.Paint = function(s, pw, ph)
		UI.Cadre(0, 0, pw, ph, COL.Fond)
		if s.Titre then
			UI.Texte(s.Titre, "sous_titre", pw / 2, UI.S(16), COL.Or, TEXT_ALIGN_CENTER)
			UI.Separateur(UI.S(20), UI.S(52), pw - UI.S(40))
		end
	end
	b:DockPadding(UI.S(24), UI.S(66), UI.S(24), UI.S(20))
	return b
end

local function libelle(parent, texte, police, couleur)
	local l = vgui.Create("DLabel", parent)
	l:Dock(TOP)
	l:SetFont(UI.Police(police or "petit_gras"))
	l:SetTextColor(couleur or COL.TexteSombre)
	l:SetText(texte)
	l:SetWrap(true)
	l:SetAutoStretchVertical(true)
	return l
end

function M.FermerSuperposition()
	if IsValid(M.Superposition) then M.Superposition:Remove() end
	M.Dialogue = nil
end

-- Formulaire prénom + nom (création ou nouveau nom)
local function formulaireNom(titre, slot, texteBouton, surValidation, avecRace)
	local s = superposition()
	local hauteur = avecRace and UI.S(430) or UI.S(360)
	local b = boite(s, UI.S(520), hauteur, titre)
	M.Dialogue = b

	libelle(b, "Prénom")
	local prenom = UI.Entree(b, "Prénom du personnage")
	prenom:Dock(TOP) prenom:SetTall(UI.S(36)) prenom:DockMargin(0, UI.S(4), 0, UI.S(10))
	libelle(b, "Nom")
	local nom = UI.Entree(b, "Nom de famille")
	nom:Dock(TOP) nom:SetTall(UI.S(36)) nom:DockMargin(0, UI.S(4), 0, UI.S(10))

	local combo
	if avecRace then
		libelle(b, "Race (choix libre)")
		combo = UI.Combo(b)
		combo:Dock(TOP) combo:SetTall(UI.S(34)) combo:DockMargin(0, UI.S(4), 0, UI.S(10))
		combo:SetValue("Choisir une race")
		for _, race in ipairs(C.Races) do combo:AddChoice(race.Nom, race.id) end
	end

	libelle(b, "De " .. C.Nom.Min .. " à " .. C.Nom.Max .. " caractères chacun : lettres (accents compris), tiret, apostrophe.", "petit")
	b.Erreur = libelle(b, "", "petit_gras", COL.Alerte)
	b.Erreur:DockMargin(0, UI.S(6), 0, 0)

	local bas = vgui.Create("DPanel", b)
	bas:Dock(BOTTOM) bas:SetTall(UI.S(42)) bas.Paint = nil
	local annuler = UI.Bouton(bas, "Annuler", M.FermerSuperposition)
	annuler:Dock(LEFT) annuler:SetWide(UI.S(200))
	local valider = UI.Bouton(bas, texteBouton, function()
		local p, n = string.Trim(prenom:GetText()), string.Trim(nom:GetText())
		local ok, err = ORIGINE.ValiderNom(p, n)
		if not ok then b.Erreur:SetText(err) return end
		local race = ""
		if combo then
			local _, id = combo:GetSelected()
			if not id then b.Erreur:SetText("Choisissez une race.") return end
			race = id
		end
		b.Erreur:SetText("")
		surValidation(p, n, race)
	end)
	valider:Dock(RIGHT) valider:SetWide(UI.S(220))
	prenom:RequestFocus()
	return b
end

function M.OuvrirCreation(slot)
	local info = infoSlot(slot)
	if slot == ORIGINE.SLOT_EVENT then
		if not ORIGINE.Race(info.event_race) then
			UI.Notifier("Le staff n'a pas encore fixé la race de ce slot.", "erreur")
			return
		end
		local b = formulaireNom("Nouveau personnage — " .. C.Slots[slot].Nom, slot, "Créer", function(p, n)
			envoyer("origine_menu_creer", slot, p, n, "")
		end)
		libelle(b, "Race fixée par le staff : " .. ORIGINE.NomRace(info.event_race), "texte_gras", ORIGINE.CouleurRace(info.event_race))
		return
	end
	if slot == ORIGINE.SLOT_STAFF then
		formulaireNom("Nouveau personnage — " .. C.Slots[slot].Nom, slot, "Créer", function(p, n, race)
			envoyer("origine_menu_creer", slot, p, n, race)
		end, true)
		return
	end
	formulaireNom("Nouveau personnage — " .. C.Slots[slot].Nom, slot, "Tirer ma race", function(p, n)
		envoyer("origine_menu_creer", slot, p, n, "")
	end)
end

function M.OuvrirRenommer(slot)
	formulaireNom("Nouveau nom — " .. C.Slots[slot].Nom, slot, "Valider le nom", function(p, n)
		envoyer("origine_menu_renommer", slot, p, n)
	end)
end

function M.ConfirmerReroll(slot)
	local r = M.Donnees.rerolls or 0
	UI.Confirmer("Relancer la race",
		"Utiliser 1 point de reroll (il vous en reste " .. r .. ") ? Le résultat est définitif : l'ancienne race sera perdue.",
		function() envoyer("origine_menu_reroll", slot) end, "Relancer")
end

---------------------------------------------------------------------------
-- Roulette de tirage
---------------------------------------------------------------------------
function M.LancerRoulette(slot, race, estReroll)
	if not IsValid(M.Panneau) then return end
	local s = superposition()
	local largeurItem, nbAvant = UI.S(230), 34
	local sequence = {}
	for i = 1, nbAvant do sequence[i] = ORIGINE.TirerRace() end
	sequence[nbAvant + 1] = race
	for i = nbAvant + 2, nbAvant + 6 do sequence[i] = ORIGINE.TirerRace() end

	local debut, duree = CurTime(), math.max(1, C.DureeAnimationTirage)
	local dernierIndex, fini = 0, false
	local b = boite(s, UI.S(1000), UI.S(360), estReroll and "Relance de la race" or "Tirage de la lignée")

	b.PaintOver = function(_, w, h)
		local t = math.Clamp((CurTime() - debut) / duree, 0, 1)
		local ease = 1 - (1 - t) ^ 3
		local cible = nbAvant * largeurItem
		local decalage = ease * cible
		local cx, cy, hi = w / 2, UI.S(80), UI.S(110)

		local gx, gy = b:LocalToScreen(UI.S(20), 0)
		local dx, dy = b:LocalToScreen(w - UI.S(20), h)
		render.SetScissorRect(gx, gy, dx, dy, true)
		for i, id in ipairs(sequence) do
			local x = cx + (i - 1) * largeurItem - decalage - largeurItem / 2
			if x > -largeurItem and x < w then
				local col = ORIGINE.CouleurRace(id)
				UI.Rect(x + UI.S(6), cy, largeurItem - UI.S(12), hi, COL.FondClair)
				UI.Contour(x + UI.S(6), cy, largeurItem - UI.S(12), hi, col, UI.S(3))
				local lignes = UI.Couper(ORIGINE.NomRace(id), "texte_gras", largeurItem - UI.S(28))
				for li, l in ipairs(lignes) do
					UI.Texte(l, "texte_gras", x + largeurItem / 2, cy + hi / 2 + (li - (#lignes + 1) / 2) * UI.S(22), col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
			end
		end
		render.SetScissorRect(0, 0, 0, 0, false)

		-- Repère central
		surface.SetDrawColor(COL.Or)
		surface.DrawRect(cx - 1, cy - UI.S(12), UI.S(3), hi + UI.S(24))

		local index = math.floor(decalage / largeurItem + 0.5)
		if index ~= dernierIndex and not fini then
			dernierIndex = index
			surface.PlaySound("buttons/lightswitch2.wav")
		end

		if t >= 1 then
			if not fini then
				fini = true
				surface.PlaySound("garrysmod/save_load" .. math.random(1, 4) .. ".wav")
				M.AfficherResultat(b, slot, race, estReroll)
			end
			local info = infoSlot(slot)
			local p = info and info.perso
			local rarete = ORIGINE.RareteDeRace(race)
			local texte = (p and (p.prenom .. " " .. p.nom) or "Votre personnage") .. " a hérité de : " ..
				ORIGINE.NomRace(race) .. " (" .. (rarete and rarete.Nom or "") .. ")"
			UI.TexteOmbre(texte, "sous_titre", w / 2, cy + hi + UI.S(30), ORIGINE.CouleurRace(race), TEXT_ALIGN_CENTER)
		end
	end
end

function M.AfficherResultat(b, slot, race, estReroll)
	local bas = vgui.Create("DPanel", b)
	bas:Dock(BOTTOM) bas:SetTall(UI.S(44)) bas.Paint = nil
	local info = infoSlot(slot)
	local p = info and info.perso
	local r = M.Donnees.rerolls or 0

	local relancer = UI.Bouton(bas, "Relancer (" .. r .. " point" .. (r > 1 and "s" or "") .. ")", function()
		M.ConfirmerReroll(slot)
	end)
	relancer:Dock(LEFT) relancer:SetWide(UI.S(300))
	relancer:SetEnabled(r > 0)

	if p and not p.valide then
		local valider = UI.Bouton(bas, "Valider et jouer", function()
			envoyer("origine_menu_valider", slot)
		end)
		valider:Dock(RIGHT) valider:SetWide(UI.S(300))
	else
		local continuer = UI.Bouton(bas, "Continuer", M.FermerSuperposition)
		continuer:Dock(RIGHT) continuer:SetWide(UI.S(300))
	end
end

---------------------------------------------------------------------------
-- Fiches des races (taux recalculés en direct depuis la config)
---------------------------------------------------------------------------
function M.OuvrirLignees()
	local s = superposition()
	local b = boite(s, UI.S(900), math.min(ScrH() - UI.S(80), UI.S(860)), "Les lignées")
	local fermer = UI.Bouton(b, "Fermer", M.FermerSuperposition)
	fermer:Dock(BOTTOM) fermer:SetTall(UI.S(40)) fermer:DockMargin(0, UI.S(10), 0, 0)

	local scroll = UI.StyliserScroll(vgui.Create("DScrollPanel", b))
	scroll:Dock(FILL)
	local taux = ORIGINE.Taux()
	local largeur = UI.S(900) - UI.S(48) - UI.S(20)

	for _, rarete in ipairs(C.Raretes) do
		local entete = scroll:Add("DPanel")
		entete:Dock(TOP) entete:SetTall(UI.S(40)) entete:DockMargin(0, UI.S(8), 0, UI.S(4))
		entete.Paint = function(_, w, h)
			UI.Texte(rarete.Nom, "sous_titre", 0, h / 2, rarete.Couleur, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			UI.Texte(ORIGINE.FormaterTaux(taux.raretes[rarete.id] or 0), "texte_gras", w - UI.S(8), h / 2, rarete.Couleur, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			UI.Separateur(0, h - 1, w)
		end
		for _, race in ipairs(C.Races) do
			if race.Rarete == rarete.id then
				local lignesDesc = UI.Couper(race.Description or "", "texte", largeur - UI.S(30))
				local lignesEffets = UI.Couper("Effets : " .. (race.Effets or ""), "italique", largeur - UI.S(30))
				local chiffres = ORIGINE.EffetsChiffres(race.id)
				local hauteur = UI.S(62) + (#lignesDesc + #lignesEffets) * UI.S(22) + #chiffres * UI.S(20) + UI.S(10)
				local fiche = scroll:Add("DPanel")
				fiche:Dock(TOP) fiche:SetTall(hauteur) fiche:DockMargin(0, 0, 0, UI.S(6))
				fiche.Paint = function(_, w, h)
					UI.Rect(0, 0, w, h, COL.FondClair)
					UI.Rect(0, 0, UI.S(4), h, rarete.Couleur)
					UI.Texte(race.Nom, "texte_gras", UI.S(16), UI.S(10), rarete.Couleur)
					UI.Texte(ORIGINE.FormaterTaux(taux.races[race.id] or 0), "texte_gras", w - UI.S(12), UI.S(10), COL.Texte, TEXT_ALIGN_RIGHT)
					UI.Texte("Inspirée de : " .. (race.Inspiree or "?"), "petit", UI.S(16), UI.S(34), COL.TexteSombre)
					local y = UI.S(58)
					for _, l in ipairs(lignesDesc) do UI.Texte(l, "texte", UI.S(16), y, COL.Texte) y = y + UI.S(22) end
					for _, l in ipairs(lignesEffets) do UI.Texte(l, "italique", UI.S(16), y, COL.TexteSombre) y = y + UI.S(22) end
					for _, l in ipairs(chiffres) do UI.Texte("• " .. l, "petit", UI.S(24), y, COL.Or) y = y + UI.S(20) end
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- Panneau d'actions du slot sélectionné
---------------------------------------------------------------------------
function M.ConstruireActions()
	local a = M.Actions
	if not IsValid(a) then return end
	a:Clear()
	local slot = M.Selection
	local info = infoSlot(slot)
	if not info then return end
	local p = info.perso
	local r = M.Donnees.rerolls or 0
	local peutRelancer = slot <= ORIGINE.SLOT_VIP and r > 0

	local boutons = vgui.Create("DPanel", a)
	boutons:Dock(RIGHT) boutons:SetWide(UI.S(340)) boutons.Paint = nil
	boutons:DockPadding(0, UI.S(18), UI.S(18), UI.S(18))
	local function bouton(texte, fn, actif)
		local bt = UI.Bouton(boutons, texte, fn)
		bt:Dock(TOP) bt:SetTall(UI.S(44)) bt:DockMargin(0, 0, 0, UI.S(10))
		if actif == false then bt:SetEnabled(false) end
		return bt
	end

	local texte, sous = "", ""
	if not info.acces then
		texte = (p and (p.prenom .. " " .. p.nom) or C.Slots[slot].Nom) .. " — verrouillé"
		sous = info.raison or ""
	elseif not p then
		texte = "Emplacement libre"
		if slot == ORIGINE.SLOT_EVENT then sous = "Race fixée par le staff."
		elseif slot == ORIGINE.SLOT_STAFF then sous = "Race choisie librement."
		else sous = "Votre race sera tirée au sort parmi six paliers de rareté." end
		bouton("Créer un personnage", function() M.OuvrirCreation(slot) end)
	elseif not p.valide then
		texte = p.prenom .. " " .. p.nom
		sous = "Race tirée : " .. ORIGINE.NomRace(p.race) .. ". Validez pour jouer, ou relancez avec un point."
		bouton("Valider et jouer", function() envoyer("origine_menu_valider", slot) end)
		bouton("Relancer la race (" .. r .. ")", function() M.ConfirmerReroll(slot) end, peutRelancer)
	elseif p.nom_a_redonner then
		texte = p.prenom .. " " .. p.nom
		sous = "Ce personnage doit recevoir un nouveau nom avant de jouer."
		bouton("Choisir un nouveau nom", function() M.OuvrirRenommer(slot) end)
	else
		texte = p.prenom .. " " .. p.nom
		sous = ORIGINE.NomRace(p.race) .. " · " .. (p.job or "Sans métier")
		bouton("Jouer", function() envoyer("origine_menu_jouer", slot) end)
		if slot <= ORIGINE.SLOT_VIP then
			bouton("Relancer la race (" .. r .. ")", function() M.ConfirmerReroll(slot) end, peutRelancer)
		end
	end

	local infoP = vgui.Create("DPanel", a)
	infoP:Dock(FILL)
	infoP.Paint = function(_, w, h)
		UI.Texte(C.Slots[slot].Nom, "petit_gras", UI.S(24), UI.S(20), COL.Or)
		UI.Texte(texte, "titre", UI.S(24), UI.S(40), COL.Texte)
		local col = p and info.acces and ORIGINE.CouleurRace(p.race) or COL.TexteSombre
		local lignes = UI.Couper(sous, "texte", w - UI.S(48))
		for i, l in ipairs(lignes) do
			UI.Texte(l, "texte", UI.S(24), UI.S(84) + (i - 1) * UI.S(22), i == 1 and col or COL.TexteSombre)
		end
	end
end

function M.Selectionner(slot)
	M.Selection = slot
	M.ConstruireActions()
end

---------------------------------------------------------------------------
-- Chat OOC dans le menu (les nouveaux peuvent demander de l'aide)
---------------------------------------------------------------------------
local function capturerChat(...)
	local morceaux = {}
	local couleur = COL.Texte
	for _, v in ipairs({ ... }) do
		if IsColor(v) or (istable(v) and v.r and v.g and v.b) then
			couleur = Color(v.r, v.g, v.b)
		elseif isentity(v) and IsValid(v) and v:IsPlayer() then
			morceaux[#morceaux + 1] = { v:Nick(), couleur }
		elseif v ~= nil then
			morceaux[#morceaux + 1] = { tostring(v), couleur }
		end
	end
	if #morceaux == 0 then return end
	table.insert(M.Chat, morceaux)
	while #M.Chat > 9 do table.remove(M.Chat, 1) end
end

if not M.ChatEnveloppe then
	M.ChatEnveloppe = true
	local ancien = chat.AddText
	chat.AddText = function(...)
		-- Avec origine_chat, les messages arrivent par le hook origine_ChatMessage
		if not ORIGINE.Chat then pcall(capturerChat, ...) end
		return ancien(...)
	end
end

hook.Add("origine_ChatMessage", "origine_menu", function(message)
	local morceaux = {}
	for _, m in ipairs(message.morceaux) do morceaux[#morceaux + 1] = { m[1], m[2] } end
	table.insert(M.Chat, morceaux)
	while #M.Chat > 9 do table.remove(M.Chat, 1) end
end)

local function creerChat(parent)
	local p = vgui.Create("DPanel", parent)
	p.Paint = function(_, w, h)
		UI.Cadre(0, 0, w, h, Color(20, 15, 11, 220))
		UI.Texte("Chat OOC", "petit_gras", UI.S(12), UI.S(8), COL.Or)
		local y = UI.S(30)
		for _, morceaux in ipairs(M.Chat) do
			local x = UI.S(12)
			surface.SetFont(UI.Police("petit"))
			for _, m in ipairs(morceaux) do
				if x < w - UI.S(12) then
					UI.Texte(m[1], "petit", x, y, m[2])
					x = x + surface.GetTextSize(m[1])
				end
			end
			y = y + UI.S(18)
		end
	end
	local e = UI.Entree(p, "Écrire dans le chat OOC… (Entrée)")
	e:Dock(BOTTOM)
	e:SetTall(UI.S(30))
	e.OnEnter = function(s)
		local t = string.Trim(s:GetText())
		if t ~= "" then RunConsoleCommand("say", "// " .. t) end
		s:SetText("")
		s:RequestFocus()
	end
	p:DockPadding(UI.S(8), 0, UI.S(8), UI.S(8))
	return p
end

---------------------------------------------------------------------------
-- Construction / mise à jour
---------------------------------------------------------------------------
function M.Construire()
	if IsValid(M.Panneau) then M.Panneau:Remove() end
	local w, h = ScrW(), ScrH()
	local pan = vgui.Create("EditablePanel")
	pan:SetSize(w, h)
	pan:SetPos(0, 0)
	pan:MakePopup()
	pan:SetKeyboardInputEnabled(true)
	M.Panneau = pan

	pan.Paint = function(_, pw, ph)
		UI.FondMenu(pw, ph)
		UI.TexteOmbre("Origine du monde", "geant", pw / 2, UI.S(26), COL.Or, TEXT_ALIGN_CENTER)
		UI.Texte("Choisissez votre personnage", "italique", pw / 2, UI.S(92), COL.TexteSombre, TEXT_ALIGN_CENTER)
		local r = M.Donnees and M.Donnees.rerolls or 0
		UI.Cadre(pw - UI.S(300), UI.S(30), UI.S(270), UI.S(56), COL.Fond)
		UI.Texte("Points de reroll", "petit_gras", pw - UI.S(165), UI.S(38), COL.TexteSombre, TEXT_ALIGN_CENTER)
		UI.Texte(tostring(r), "sous_titre", pw - UI.S(165), UI.S(56), COL.Or, TEXT_ALIGN_CENTER)
	end

	local lignees = UI.Bouton(pan, "Les lignées", M.OuvrirLignees)
	lignees:SetPos(UI.S(30), UI.S(38))
	lignees:SetSize(UI.S(220), UI.S(42))

	-- Cartes
	local lc, hc, ec = UI.S(290), UI.S(430), UI.S(18)
	local total = lc * ORIGINE.NB_SLOTS + ec * (ORIGINE.NB_SLOTS - 1)
	local x0, y0 = (w - total) / 2, UI.S(136)
	M.Cartes = {}
	for s = 1, ORIGINE.NB_SLOTS do
		local c = creerCarte(pan, s)
		c:SetPos(x0 + (s - 1) * (lc + ec), y0)
		c:SetSize(lc, hc)
		M.Cartes[s] = c
	end

	-- Actions
	local a = vgui.Create("DPanel", pan)
	a:SetPos(x0, y0 + hc + UI.S(20))
	a:SetSize(total, UI.S(170))
	a.Paint = function(_, pw, ph) UI.Cadre(0, 0, pw, ph, COL.Fond) end
	M.Actions = a

	-- Chat OOC
	local chatY = y0 + hc + UI.S(210)
	local chatP = creerChat(pan)
	chatP:SetPos(x0, chatY)
	chatP:SetSize(math.min(UI.S(760), total), math.max(UI.S(120), h - chatY - UI.S(24)))
end

function M.Rafraichir()
	if not IsValid(M.Panneau) then return end
	for _, c in pairs(M.Cartes or {}) do c.MettreAJour() end
	M.ConstruireActions()
end

function M.Fermer()
	M.FermeA = CurTime()
	if IsValid(M.Panneau) then M.Panneau:Remove() end
	M.Panneau, M.Superposition, M.Dialogue = nil, nil, nil
end

---------------------------------------------------------------------------
-- Réseau
---------------------------------------------------------------------------
net.Receive("origine_menu", function()
	local d = net.ReadTable()
	M.Donnees = d
	M.FermeA = nil
	if d.selection then M.Selection = d.selection end
	if not IsValid(M.Panneau) then M.Construire() end
	-- Un formulaire ouvert a abouti : on le ferme (la roulette reste)
	if IsValid(M.Dialogue) and not d.message then
		local info = infoSlot(M.Selection)
		if info and info.perso and not info.perso.nom_a_redonner then M.FermerSuperposition() end
	end
	M.Rafraichir()
	if d.message then UI.Notifier(d.message, "info") end
end)

net.Receive("origine_menu_fermer", function()
	M.Fermer()
end)

net.Receive("origine_menu_tirage", function()
	local slot = net.ReadUInt(4)
	local race = net.ReadString()
	local estReroll = net.ReadBool()
	M.LancerRoulette(slot, race, estReroll)
end)

net.Receive("origine_menu_erreur", function()
	local texte = net.ReadString()
	if IsValid(M.Dialogue) and IsValid(M.Dialogue.Erreur) then
		M.Dialogue.Erreur:SetText(texte)
	else
		UI.Notifier(texte, "erreur")
	end
end)

-- Le joueur ne sort jamais du menu sans personnage chargé
hook.Add("Think", "origine_menu_garde", function()
	local ply = LocalPlayer()
	if not IsValid(ply) or not M.Donnees or IsValid(M.Panneau) then return end
	if not ORIGINE.EnMenu(ply) then return end
	if M.FermeA and CurTime() - M.FermeA < 3 then return end
	M.Construire()
	M.Rafraichir()
end)

hook.Add("origine_EchelleChangee", "origine_menu", function()
	if IsValid(M.Panneau) then
		M.Construire()
		M.Rafraichir()
	end
end)
