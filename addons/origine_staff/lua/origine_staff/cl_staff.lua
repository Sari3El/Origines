--[[-----------------------------------------------------------------------
	Origine du monde — menu staff !origine (client)

	Le client n'envoie que des demandes : chaque action est vérifiée par le
	serveur (permission origine_menu).
-------------------------------------------------------------------------]]

ORIGINE.Staff = ORIGINE.Staff or {}
local S = ORIGINE.Staff
local UI = ORIGINE.UI
local COL = UI.C
local C = ORIGINE.Config
local CS = ORIGINE.ConfigStaff

local function date(t) return t and os.date("%d/%m/%Y %H:%M", t) or "—" end

local function action(nom, sid, slot, a, b, n)
	net.Start("origine_staff_action")
		net.WriteString(nom)
		net.WriteString(sid or "")
		net.WriteUInt(slot or 0, 4)
		net.WriteString(a or "")
		net.WriteString(b or "")
		net.WriteInt(n or 0, 32)
	net.SendToServer()
end

---------------------------------------------------------------------------
-- Petits composants
---------------------------------------------------------------------------
local function titreSection(parent, texte)
	local p = parent:Add("DPanel")
	p:Dock(TOP)
	p:SetTall(UI.S(34))
	p:DockMargin(0, UI.S(10), 0, UI.S(4))
	p.Paint = function(_, w, h)
		UI.Texte(texte, "sous_titre", 0, h / 2, COL.Or, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		UI.Separateur(0, h - 1, w)
	end
	return p
end

local function rangeeBoutons(parent)
	local r = parent:Add("DPanel")
	r:Dock(TOP)
	r:SetTall(UI.S(34))
	r:DockMargin(0, UI.S(4), 0, UI.S(4))
	r.Paint = nil
	r.Ajouter = function(_, texte, fn, largeur, actif)
		local b = UI.Bouton(r, texte, fn)
		b:Dock(LEFT)
		b:SetWide(UI.S(largeur or 170))
		b:DockMargin(0, 0, UI.S(8), 0)
		if actif == false then b:SetEnabled(false) end
		return b
	end
	return r
end

local function lignesTexte(parent, lignes)
	local p = parent:Add("DPanel")
	p:Dock(TOP)
	p:SetTall(#lignes * UI.S(22) + UI.S(4))
	p.Paint = function()
		for i, l in ipairs(lignes) do
			local x = 0
			surface.SetFont(UI.Police("texte"))
			for _, m in ipairs(istable(l) and l or { { l } }) do
				UI.Texte(m[1], m[3] or "texte", x, (i - 1) * UI.S(22), m[2] or COL.Texte)
				x = x + surface.GetTextSize(m[1])
			end
		end
	end
	return p
end

-- Choisir une race dans une liste ; fn(id)
local function choisirRace(titre, fn)
	local f = UI.Fenetre(titre, UI.S(440), UI.S(190))
	f:SetDrawOnTop(true)
	local combo = UI.Combo(f)
	combo:Dock(TOP)
	combo:SetTall(UI.S(34))
	combo:SetValue("Choisir une race")
	for _, race in ipairs(C.Races) do combo:AddChoice(race.Nom, race.id) end
	local ok = UI.Bouton(f, "Valider", function()
		local _, id = combo:GetSelected()
		if not id then return end
		f:Close()
		fn(id)
	end)
	ok:Dock(BOTTOM)
	ok:SetTall(UI.S(38))
end

---------------------------------------------------------------------------
-- Fenêtre principale
---------------------------------------------------------------------------
function S.Ouvrir()
	if IsValid(S.Fenetre) then S.Fenetre:Close() end
	local w, h = math.min(ScrW() - UI.S(40), UI.S(1280)), math.min(ScrH() - UI.S(40), UI.S(820))
	local f = UI.Fenetre("Origine — menu staff", w, h)
	S.Fenetre = f

	local onglets = vgui.Create("DPanel", f)
	onglets:Dock(TOP)
	onglets:SetTall(UI.S(38))
	onglets:DockMargin(0, 0, 0, UI.S(10))
	onglets.Paint = nil

	local corps = vgui.Create("DPanel", f)
	corps:Dock(FILL)
	corps.Paint = nil
	S.Corps = corps

	local bJoueurs = UI.Bouton(onglets, "Joueurs", function() S.OngletJoueurs() end)
	bJoueurs:Dock(LEFT) bJoueurs:SetWide(UI.S(200)) bJoueurs:DockMargin(0, 0, UI.S(8), 0)
	local bLogs = UI.Bouton(onglets, "Logs", function() S.OngletLogs() end)
	bLogs:Dock(LEFT) bLogs:SetWide(UI.S(200)) bLogs:DockMargin(0, 0, UI.S(8), 0)
	local bServeur = UI.Bouton(onglets, "Serveur", function() S.OngletServeur() end)
	bServeur:Dock(LEFT) bServeur:SetWide(UI.S(200))

	S.OngletJoueurs()
end

---------------------------------------------------------------------------
-- Onglet Joueurs : recherche + fiche
---------------------------------------------------------------------------
function S.OngletJoueurs()
	local corps = S.Corps
	corps:Clear()
	S.Onglet = "joueurs"

	local gauche = vgui.Create("DPanel", corps)
	gauche:Dock(LEFT)
	gauche:SetWide(UI.S(360))
	gauche:DockMargin(0, 0, UI.S(12), 0)
	gauche.Paint = function(_, pw, ph) UI.Rect(0, 0, pw, ph, Color(0, 0, 0, 60)) end
	gauche:DockPadding(UI.S(8), UI.S(8), UI.S(8), UI.S(8))

	local recherche = UI.Entree(gauche, "Nom de personnage ou SteamID")
	recherche:Dock(TOP)
	recherche:SetTall(UI.S(34))
	local bouton = UI.Bouton(gauche, "Rechercher", function()
		net.Start("origine_staff_recherche")
			net.WriteString(recherche:GetText())
		net.SendToServer()
	end)
	bouton:Dock(TOP)
	bouton:SetTall(UI.S(34))
	bouton:DockMargin(0, UI.S(6), 0, UI.S(8))
	recherche.OnEnter = function() bouton:DoClick() end

	S.Resultats = UI.StyliserScroll(vgui.Create("DScrollPanel", gauche))
	S.Resultats:Dock(FILL)

	S.PanneauFiche = UI.StyliserScroll(vgui.Create("DScrollPanel", corps))
	S.PanneauFiche:Dock(FILL)
	local vide = S.PanneauFiche:Add("DLabel")
	vide:Dock(TOP)
	vide:SetFont(UI.Police("texte"))
	vide:SetTextColor(COL.TexteSombre)
	vide:SetText("Recherchez un joueur pour afficher sa fiche.")
	vide:SetTall(UI.S(30))

	-- Liste des joueurs connectés au départ
	net.Start("origine_staff_recherche")
		net.WriteString("")
	net.SendToServer()

	if S.DerniereFiche then S.AfficherFiche(S.DerniereFiche) end
end

function S.AfficherResultats(resultats)
	if not IsValid(S.Resultats) then return end
	S.Resultats:Clear()
	if #resultats == 0 then
		local l = S.Resultats:Add("DLabel")
		l:Dock(TOP) l:SetTall(UI.S(26)) l:SetFont(UI.Police("petit")) l:SetTextColor(COL.TexteSombre)
		l:SetText("Aucun résultat.")
		return
	end
	for _, r in ipairs(resultats) do
		local b = S.Resultats:Add("DButton")
		b:Dock(TOP)
		b:SetTall(UI.S(46))
		b:DockMargin(0, 0, 0, UI.S(4))
		b:SetText("")
		b.Paint = function(s, bw, bh)
			UI.Rect(0, 0, bw, bh, s:IsHovered() and COL.Survol or COL.FondClair)
			UI.Contour(0, 0, bw, bh, COL.Bordure, 1)
			UI.Texte(r.nom, "texte_gras", UI.S(8), UI.S(4), r.race and ORIGINE.CouleurRace(r.race) or COL.Texte)
			local ligne = (r.slot and ("Slot " .. r.slot .. " · ") or "") .. r.sid
			UI.Texte(ligne, "petit", UI.S(8), UI.S(26), COL.TexteSombre)
			if r.en_ligne then UI.Texte("en ligne", "petit_gras", bw - UI.S(8), UI.S(4), COL.Succes, TEXT_ALIGN_RIGHT) end
		end
		b.DoClick = function()
			net.Start("origine_staff_fiche")
				net.WriteString(r.sid)
			net.SendToServer()
		end
	end
end

---------------------------------------------------------------------------
-- Fiche d'un compte
---------------------------------------------------------------------------
local function carteSlot(parent, fiche, s)
	local info = fiche.slots[s]
	local p = info.perso
	local sid = fiche.sid

	local titre = C.Slots[s].Nom .. (info.acces and "" or " (verrouillé)")
	if fiche.slot_actuel == s then titre = titre .. " — joué actuellement" end
	titreSection(parent, titre)

	if not p then
		lignesTexte(parent, { { { "Aucun personnage.", COL.TexteSombre } } })
		if fiche.en_ligne then
			rangeeBoutons(parent):Ajouter("Forcer ce slot", function() action("forcer", sid, s) end, 170, info.acces)
		end
		return
	end

	local etat = {}
	if not p.valide then etat[#etat + 1] = "tirage à valider" end
	if p.nom_a_redonner then etat[#etat + 1] = "nom à redonner" end
	lignesTexte(parent, {
		{ { p.prenom .. " " .. p.nom, COL.Texte, "texte_gras" }, { "  —  " }, { ORIGINE.NomRace(p.race), ORIGINE.CouleurRace(p.race), "texte_gras" } },
		{ { "Covan : " .. ORIGINE.FormaterCovan(p.covan or 0) .. "    Métier : " .. (p.job or "—") } },
		{ { "PV : " .. (p.pv or "max") .. " / " .. (p.pvmax or "—") .. "    Armure : " .. (p.armure or 0) .. " / " .. (p.armuremax or "—") ..
			"    Faim : " .. (p.faim and math.Round(p.faim) .. " %" or "—") } },
		{ { "Dernière connexion : " .. date(p.derniere) .. (#etat > 0 and ("    (" .. table.concat(etat, ", ") .. ")") or ""), COL.TexteSombre } },
	})

	-- Inventaire
	local inv = info.inventaire or {}
	local lignesInv = {}
	for i, c in ipairs(inv) do
		lignesInv[#lignesInv + 1] = { i = i, texte = ORIGINE.Inv.NomObjet(c) .. ((c.n or 1) > 1 and (" ×" .. c.n) or "") }
	end
	local invP = parent:Add("DPanel")
	invP:Dock(TOP)
	invP:SetTall(UI.S(28) + math.max(1, #lignesInv) * UI.S(26))
	invP:DockMargin(0, UI.S(4), 0, UI.S(4))
	invP.Paint = function(_, pw, ph)
		UI.Rect(0, 0, pw, ph, Color(0, 0, 0, 60))
		UI.Texte("Inventaire (" .. #inv .. " cases)", "petit_gras", UI.S(8), UI.S(5), COL.Or)
		if #lignesInv == 0 then UI.Texte("Vide", "petit", UI.S(8), UI.S(28), COL.TexteSombre) end
	end
	for k, l in ipairs(lignesInv) do
		local ligne = vgui.Create("DPanel", invP)
		ligne:SetPos(UI.S(8), UI.S(26) + (k - 1) * UI.S(26))
		ligne:SetSize(UI.S(520), UI.S(24))
		ligne.Paint = function(_, _, lh) UI.Texte(l.texte, "petit", 0, lh / 2, COL.Texte, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
		local retirer = UI.Bouton(ligne, "Retirer", function()
			UI.Confirmer("Retirer un objet", "Retirer « " .. l.texte .. " » de l'inventaire ?", function()
				action("inv_retirer", sid, s, "", "", l.i)
			end, "Retirer")
		end)
		retirer:SetSize(UI.S(90), UI.S(22))
		retirer:SetPos(UI.S(420), 1)
	end

	local r1 = rangeeBoutons(parent)
	r1:Ajouter("Modifier la race", function()
		choisirRace("Race de " .. p.prenom .. " " .. p.nom, function(id) action("race", sid, s, id) end)
	end)
	r1:Ajouter("Changer le nom", function()
		UI.Demander("Nouveau nom", {
			{ libelle = "Prénom", valeur = p.prenom },
			{ libelle = "Nom", valeur = p.nom },
		}, function(v) action("nom", sid, s, v[1], v[2]) end)
	end)
	r1:Ajouter("Ajouter un objet", function()
		local liste = {}
		for classe in pairs(ORIGINE.Inv.Autorisees or {}) do liste[#liste + 1] = classe end
		table.sort(liste)
		if #liste == 0 then return UI.Notifier("La liste des entités autorisées est vide (sh_entites.lua).", "erreur") end
		local fe = UI.Fenetre("Ajouter un objet", UI.S(440), UI.S(190))
		fe:SetDrawOnTop(true)
		local combo = UI.Combo(fe)
		combo:Dock(TOP) combo:SetTall(UI.S(34)) combo:SetValue("Choisir une entité")
		for _, classe in ipairs(liste) do combo:AddChoice(ORIGINE.Inv.NomObjet({ classe = classe, arme = weapons.GetStored(classe) and classe or nil }) .. " (" .. classe .. ")", classe) end
		local ok = UI.Bouton(fe, "Ajouter", function()
			local _, classe = combo:GetSelected()
			if not classe then return end
			fe:Close()
			action("inv_ajouter", sid, s, classe)
		end)
		ok:Dock(BOTTOM) ok:SetTall(UI.S(38))
	end)
	if fiche.en_ligne then
		r1:Ajouter("Forcer ce slot", function() action("forcer", sid, s) end, 170, info.acces and fiche.slot_actuel ~= s)
	end

	local r2 = rangeeBoutons(parent)
	local function ckRpk(typ)
		local nom = typ == "ck" and "CK" or "RPK"
		UI.Demander(nom .. " — " .. p.prenom .. " " .. p.nom, { { libelle = "Raison (obligatoire)" } }, function(v)
			local raison = string.Trim(v[1] or "")
			if raison == "" then return UI.Notifier("La raison est obligatoire.", "erreur") end
			local detail = typ == "ck"
				and "Covan remis au départ, inventaire, armes et licences vidés, portes et props libérés, job gardé, nouveau nom à donner."
				or "Covan remis au départ, inventaire, armes et licences vidés, portes et props libérés, job par défaut, nouveau nom à donner."
			UI.Confirmer("Confirmer le " .. nom, detail .. " Une copie est faite avant, pour pouvoir annuler.", function()
				action(typ, sid, s, raison)
			end, "Confirmer le " .. nom)
		end, "Continuer")
	end
	r2:Ajouter("CK", function() ckRpk("ck") end, 120)
	r2:Ajouter("RPK", function() ckRpk("rpk") end, 120)
end

function S.AfficherFiche(fiche)
	S.DerniereFiche = fiche
	local pan = S.PanneauFiche
	if not IsValid(pan) then return end
	pan:Clear()
	local sid = fiche.sid

	titreSection(pan, fiche.nom_steam .. "  ·  " .. sid)
	lignesTexte(pan, {
		{ { fiche.en_ligne and "En ligne" or "Hors ligne", fiche.en_ligne and COL.Succes or COL.TexteSombre, "texte_gras" },
		  { "    Groupe ULX : " .. (fiche.groupe or "?") } },
	})

	-- Compte
	titreSection(pan, "Compte")
	local c = fiche.compte
	if not c then
		lignesTexte(pan, { { { "Ce joueur n'a pas encore de compte Origine.", COL.TexteSombre } } })
	else
		local slots = {}
		for s = 1, ORIGINE.NB_SLOTS do
			slots[#slots + 1] = { C.Slots[s].Nom .. (fiche.slots[s].acces and " : oui    " or " : non    "), fiche.slots[s].acces and COL.Succes or COL.TexteSombre }
		end
		lignesTexte(pan, {
			{ { "Points de reroll : ", COL.Texte }, { tostring(c.rerolls), COL.Or, "texte_gras" } },
			slots,
			{ { "Race du slot EVENT : " .. (c.event_race and ORIGINE.NomRace(c.event_race) or "non fixée"),
				c.event_race and ORIGINE.CouleurRace(c.event_race) or COL.TexteSombre } },
		})
		local r = rangeeBoutons(pan)
		r:Ajouter("Rerolls +/−", function()
			UI.Demander("Points de reroll", { { libelle = "Nombre à ajouter (négatif pour retirer)", valeur = "1" } }, function(v)
				local n = math.floor(tonumber(v[1]) or 0)
				if n ~= 0 then action("rerolls", sid, 0, "", "", n) end
			end)
		end)
		local debloque = c.event_debloque == 1
		r:Ajouter(debloque and "Verrouiller EVENT" or "Débloquer EVENT", function()
			if debloque then
				action("event", sid, 0, "0", "")
			else
				choisirRace("Race du slot EVENT", function(id) action("event", sid, 0, "1", id) end)
			end
		end, 190)
		if debloque then
			r:Ajouter("Race EVENT", function()
				choisirRace("Race du slot EVENT", function(id) action("event", sid, 0, "1", id) end)
			end)
		end
		local r2 = rangeeBoutons(pan)
		local vip = c.vip_debloque == 1
		r2:Ajouter(vip and "Verrouiller le slot 3" or "Débloquer le slot 3", function()
			if vip then
				UI.Confirmer("Slot 3", "Verrouiller le slot 3 de ce joueur ? S'il n'est pas VIP et joue dessus, il revient au menu (ses données sont gardées).", function()
					action("vip_slot", sid, 0, "0")
				end, "Verrouiller")
			else
				action("vip_slot", sid, 0, "1")
			end
		end, 220)
	end

	for s = 1, ORIGINE.NB_SLOTS do carteSlot(pan, fiche, s) end

	-- Copies avant CK / RPK
	titreSection(pan, "Copies avant CK / RPK")
	if #fiche.copies == 0 then
		lignesTexte(pan, { { { "Aucune copie.", COL.TexteSombre } } })
	end
	for _, cp in ipairs(fiche.copies) do
		local ligne = pan:Add("DPanel")
		ligne:Dock(TOP)
		ligne:SetTall(UI.S(34))
		ligne:DockMargin(0, 0, 0, UI.S(4))
		ligne.Paint = function(_, lw, lh)
			UI.Rect(0, 0, lw, lh, COL.FondClair)
			UI.Texte(string.upper(cp.type) .. " · " .. C.Slots[cp.slot].Nom .. " · " .. date(cp.date) .. " · " .. (cp.raison or ""),
				"petit", UI.S(8), lh / 2, cp.restauree and COL.TexteSombre or COL.Texte, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		if not cp.restauree then
			local b = UI.Bouton(ligne, "Annuler le " .. string.upper(cp.type), function()
				UI.Confirmer("Annuler", "Restaurer le personnage tel qu'il était juste avant ce " .. string.upper(cp.type) .. " ?", function()
					action("annuler", sid, 0, "", "", cp.id)
				end, "Restaurer")
			end)
			b:Dock(RIGHT)
			b:SetWide(UI.S(180))
		end
	end
end

---------------------------------------------------------------------------
-- Onglet Historique
---------------------------------------------------------------------------
local function detailHistorique(e)
	local f = UI.Fenetre(ORIGINE.NomTypeHistorique(e.type) .. " — " .. date(e.date), UI.S(620), UI.S(460))
	local texte = vgui.Create("DTextEntry", f)
	texte:Dock(FILL)
	texte:SetMultiline(true)
	texte:SetEditable(false)
	texte:SetFont(UI.Police("petit"))
	local function joli(j)
		local t = j and util.JSONToTable(j)
		if not t then return j or "—" end
		local l = {}
		for k, v in SortedPairs(t) do l[#l + 1] = "  " .. tostring(k) .. " : " .. (istable(v) and util.TableToJSON(v) or tostring(v)) end
		return table.concat(l, "\n")
	end
	texte:SetText(
		"Qui : " .. (e.staff_nom or "Système") .. (e.staff_sid and (" (" .. e.staff_sid .. ")") or "") .. "\n" ..
		"Sur qui : " .. (e.cible_nom or "—") .. (e.cible_sid and (" (" .. e.cible_sid .. ")") or "") ..
		(e.cible_slot and (" · slot " .. e.cible_slot) or "") .. "\n" ..
		"Quand : " .. date(e.date) .. "\n" ..
		"Raison : " .. (e.raison or "—") .. "\n\n" ..
		"Avant :\n" .. joli(e.avant) .. "\n\nAprès :\n" .. joli(e.apres)
	)
end

-- Historique des actions staff (sous-onglet « Staff » des logs)
function S.OngletHistorique(corps)

	local filtres = vgui.Create("DPanel", corps)
	filtres:Dock(TOP)
	filtres:SetTall(UI.S(36))
	filtres:DockMargin(0, 0, 0, UI.S(10))
	filtres.Paint = nil

	local joueur = UI.Entree(filtres, "Joueur (nom ou SteamID)")
	joueur:Dock(LEFT) joueur:SetWide(UI.S(300)) joueur:DockMargin(0, 0, UI.S(8), 0)
	local staff = UI.Entree(filtres, "Staff (nom ou SteamID)")
	staff:Dock(LEFT) staff:SetWide(UI.S(260)) staff:DockMargin(0, 0, UI.S(8), 0)
	local typ = UI.Combo(filtres)
	typ:Dock(LEFT) typ:SetWide(UI.S(240)) typ:DockMargin(0, 0, UI.S(8), 0)
	typ:AddChoice("Toutes les actions", "", true)
	for _, t in ipairs(CS.TypesHistorique) do typ:AddChoice(t.Nom, t.id) end

	local function filtrer()
		local _, id = typ:GetSelected()
		net.Start("origine_staff_historique")
			net.WriteString(joueur:GetText())
			net.WriteString(staff:GetText())
			net.WriteString(id or "")
		net.SendToServer()
	end
	local b = UI.Bouton(filtres, "Filtrer", filtrer)
	b:Dock(LEFT) b:SetWide(UI.S(140))
	joueur.OnEnter, staff.OnEnter = filtrer, filtrer

	S.ListeHistorique = UI.StyliserScroll(vgui.Create("DScrollPanel", corps))
	S.ListeHistorique:Dock(FILL)
	filtrer()
end

function S.AfficherHistorique(entrees)
	local liste = S.ListeHistorique
	if not IsValid(liste) then return end
	liste:Clear()
	if #entrees == 0 then
		local l = liste:Add("DLabel")
		l:Dock(TOP) l:SetTall(UI.S(26)) l:SetFont(UI.Police("petit")) l:SetTextColor(COL.TexteSombre)
		l:SetText("Aucune entrée.")
	end
	for _, e in ipairs(entrees) do
		local ligne = liste:Add("DButton")
		ligne:Dock(TOP)
		ligne:SetTall(UI.S(30))
		ligne:DockMargin(0, 0, 0, UI.S(3))
		ligne:SetText("")
		ligne.Paint = function(s, lw, lh)
			UI.Rect(0, 0, lw, lh, s:IsHovered() and COL.Survol or COL.FondClair)
			local x = UI.S(8)
			local function col(t, largeur, c)
				UI.Texte(t, "petit", x, lh / 2, c or COL.Texte, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				x = x + UI.S(largeur)
			end
			col(date(e.date), 140, COL.TexteSombre)
			col(ORIGINE.NomTypeHistorique(e.type), 190, COL.Or)
			col(e.staff_nom or "Système", 200)
			col((e.cible_nom or "—") .. (e.cible_slot and (" (slot " .. e.cible_slot .. ")") or ""), 280)
			col(e.raison or "", 400, COL.TexteSombre)
		end
		ligne.DoClick = function() detailHistorique(e) end
	end
end

---------------------------------------------------------------------------
-- Onglet Serveur : actions sur tous les joueurs connectés
---------------------------------------------------------------------------
function S.OngletServeur()
	local corps = S.Corps
	corps:Clear()
	S.Onglet = "serveur"
	local pan = UI.StyliserScroll(vgui.Create("DScrollPanel", corps))
	pan:Dock(FILL)

	titreSection(pan, "Serveur")
	lignesTexte(pan, {
		{ { "Ces actions s'appliquent à tous les joueurs connectés (" .. player.GetCount() .. " en ce moment).", COL.TexteSombre } },
	})

	titreSection(pan, "Points de reroll")
	local r1 = rangeeBoutons(pan)
	r1:Ajouter("Rerolls à tous", function()
		UI.Demander("Rerolls pour tous les joueurs connectés", { { libelle = "Nombre de points (négatif pour retirer)", valeur = "1" } }, function(v)
			local n = math.floor(tonumber(v[1]) or 0)
			if n == 0 then return end
			UI.Confirmer("Rerolls à tous", (n > 0 and "Donner " or "Retirer ") .. math.abs(n) .. " point(s) de reroll à tous les joueurs connectés ?", function()
				action("rerolls_tous", "", 0, "", "", n)
			end)
		end)
	end, 220)

	titreSection(pan, "Slot EVENT")
	lignesTexte(pan, {
		{ { "Débloque le slot EVENT de tous les joueurs connectés avec la race choisie, ou le verrouille.", COL.TexteSombre } },
		{ { "Changer la race modifie aussi les personnages EVENT déjà créés. Verrouiller renvoie au menu ceux qui jouent dessus.", COL.TexteSombre } },
	})
	local r2 = rangeeBoutons(pan)
	r2:Ajouter("Débloquer pour tous", function()
		choisirRace("Race du slot EVENT (tous les joueurs)", function(id)
			UI.Confirmer("Slot EVENT", "Débloquer le slot EVENT de tous les joueurs connectés en " .. ORIGINE.NomRace(id) .. " ?", function()
				action("event_tous", "", 0, "1", id)
			end)
		end)
	end, 220)
	r2:Ajouter("Verrouiller pour tous", function()
		UI.Confirmer("Slot EVENT", "Verrouiller le slot EVENT de tous les joueurs connectés ? Leurs données sont gardées.", function()
			action("event_tous", "", 0, "0", "")
		end, "Verrouiller")
	end, 220)
end

---------------------------------------------------------------------------
-- Onglet Logs : un sous-onglet par catégorie
---------------------------------------------------------------------------
local PERIODES = {
	{ "Dernière heure", 3600 }, { "24 heures", 86400 }, { "7 jours", 7 * 86400 },
	{ "30 jours", 30 * 86400 }, { "Tout", 0 },
}

local function dateLog(t) return t and os.date("%d/%m %H:%M:%S", t) or "—" end

function S.OuvrirFicheJoueur(sid)
	if not sid then return end
	S.OngletJoueurs()
	net.Start("origine_staff_fiche")
		net.WriteString(sid)
	net.SendToServer()
end

local function detailLog(categorie, e)
	local f = UI.Fenetre(dateLog(e.date) .. " — " .. categorie, UI.S(640), UI.S(440))
	local bas = vgui.Create("DPanel", f)
	bas:Dock(BOTTOM) bas:SetTall(UI.S(38)) bas:DockMargin(0, UI.S(8), 0, 0) bas.Paint = nil
	if e.acteur_sid then
		local b = UI.Bouton(bas, "Fiche de l'auteur", function() f:Close() S.OuvrirFicheJoueur(e.acteur_sid) end)
		b:Dock(LEFT) b:SetWide(UI.S(220)) b:DockMargin(0, 0, UI.S(8), 0)
	end
	if e.cible_sid then
		local b = UI.Bouton(bas, "Fiche de la cible", function() f:Close() S.OuvrirFicheJoueur(e.cible_sid) end)
		b:Dock(LEFT) b:SetWide(UI.S(220))
	end
	local texte = vgui.Create("DTextEntry", f)
	texte:Dock(FILL)
	texte:SetMultiline(true)
	texte:SetEditable(false)
	texte:SetFont(UI.Police("petit"))
	local l = {
		"Quand : " .. os.date("%d/%m/%Y %H:%M:%S", e.date),
		"Auteur : " .. (e.acteur_nom or "—") .. (e.acteur_sid and (" (" .. e.acteur_sid .. ")") or ""),
		"Cible : " .. (e.cible_nom or "—") .. (e.cible_sid and (" (" .. e.cible_sid .. ")") or ""),
		"",
		e.texte or "",
	}
	local d = e.details and util.JSONToTable(e.details)
	if d then
		l[#l + 1] = ""
		l[#l + 1] = "Détails :"
		for k, v in SortedPairs(d) do l[#l + 1] = "  " .. tostring(k) .. " : " .. (istable(v) and util.TableToJSON(v) or tostring(v)) end
	end
	texte:SetText(table.concat(l, "\n"))
end

function S.OngletLogs()
	local corps = S.Corps
	corps:Clear()
	S.Onglet = "logs"
	S.LogsCategorie = S.LogsCategorie or CS.CategoriesLogs[1].id

	local menu = vgui.Create("DPanel", corps)
	menu:Dock(LEFT)
	menu:SetWide(UI.S(190))
	menu:DockMargin(0, 0, UI.S(12), 0)
	menu.Paint = function(_, pw, ph) UI.Rect(0, 0, pw, ph, Color(0, 0, 0, 60)) end
	menu:DockPadding(UI.S(6), UI.S(6), UI.S(6), UI.S(6))

	local contenu = vgui.Create("DPanel", corps)
	contenu:Dock(FILL)
	contenu.Paint = nil
	S.LogsContenu = contenu

	for _, cat in ipairs(CS.CategoriesLogs) do
		local b = vgui.Create("DButton", menu)
		b:Dock(TOP)
		b:SetTall(UI.S(34))
		b:DockMargin(0, 0, 0, UI.S(4))
		b:SetText("")
		b.Paint = function(s, bw, bh)
			local actif = S.LogsCategorie == cat.id
			UI.Rect(0, 0, bw, bh, actif and COL.FondClair or (s:IsHovered() and COL.Survol or COL.Fond))
			UI.Contour(0, 0, bw, bh, actif and COL.Or or COL.Bordure, 1)
			UI.Texte(cat.Nom, "texte", UI.S(10), bh / 2, actif and COL.Or or COL.Texte, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		b.DoClick = function()
			S.LogsCategorie = cat.id
			S.ConstruireLogs()
		end
	end
	S.ConstruireLogs()
end

function S.ConstruireLogs()
	local contenu = S.LogsContenu
	if not IsValid(contenu) then return end
	contenu:Clear()
	local categorie = S.LogsCategorie
	if categorie == "staff" then
		S.OngletHistorique(contenu)
		return
	end

	local filtres = vgui.Create("DPanel", contenu)
	filtres:Dock(TOP)
	filtres:SetTall(UI.S(36))
	filtres:DockMargin(0, 0, 0, UI.S(8))
	filtres.Paint = nil
	local joueur = UI.Entree(filtres, "Joueur (nom ou SteamID)")
	joueur:Dock(LEFT) joueur:SetWide(UI.S(250)) joueur:DockMargin(0, 0, UI.S(8), 0)
	local recherche = UI.Entree(filtres, "Rechercher dans le texte")
	recherche:Dock(LEFT) recherche:SetWide(UI.S(250)) recherche:DockMargin(0, 0, UI.S(8), 0)
	local periode = UI.Combo(filtres)
	periode:Dock(LEFT) periode:SetWide(UI.S(170)) periode:DockMargin(0, 0, UI.S(8), 0)
	for i, p in ipairs(PERIODES) do periode:AddChoice(p[1], p[2], i == 2) end

	S.LogsPage = 1
	local function demander(page)
		local _, secondes = periode:GetSelected()
		S.LogsPage = page
		net.Start("origine_staff_logs")
			net.WriteString(categorie)
			net.WriteString(joueur:GetText())
			net.WriteString(recherche:GetText())
			net.WriteUInt(secondes or 0, 32)
			net.WriteUInt(page, 16)
		net.SendToServer()
	end
	S.DemanderLogs = demander
	local b = UI.Bouton(filtres, "Actualiser", function() demander(1) end)
	b:Dock(LEFT) b:SetWide(UI.S(140))
	joueur.OnEnter = function() demander(1) end
	recherche.OnEnter = function() demander(1) end
	periode.OnSelect = function() demander(1) end

	local bas = vgui.Create("DPanel", contenu)
	bas:Dock(BOTTOM)
	bas:SetTall(UI.S(36))
	bas:DockMargin(0, UI.S(8), 0, 0)
	bas.Paint = function(_, bw, bh)
		UI.Texte("Page " .. (S.LogsPage or 1), "texte_gras", bw / 2, bh / 2, COL.Or, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	S.BoutonPrecedent = UI.Bouton(bas, "Précédent", function() if S.LogsPage > 1 then demander(S.LogsPage - 1) end end)
	S.BoutonPrecedent:Dock(LEFT) S.BoutonPrecedent:SetWide(UI.S(160))
	S.BoutonSuivant = UI.Bouton(bas, "Suivant", function() demander(S.LogsPage + 1) end)
	S.BoutonSuivant:Dock(RIGHT) S.BoutonSuivant:SetWide(UI.S(160))

	S.ListeLogs = UI.StyliserScroll(vgui.Create("DScrollPanel", contenu))
	S.ListeLogs:Dock(FILL)
	demander(1)
end

function S.AfficherLogs(categorie, page, suite, lignes)
	local liste = S.ListeLogs
	if not IsValid(liste) or categorie ~= S.LogsCategorie then return end
	liste:Clear()
	S.LogsPage = page
	if IsValid(S.BoutonPrecedent) then S.BoutonPrecedent:SetEnabled(page > 1) end
	if IsValid(S.BoutonSuivant) then S.BoutonSuivant:SetEnabled(suite) end
	if #lignes == 0 then
		local l = liste:Add("DLabel")
		l:Dock(TOP) l:SetTall(UI.S(26)) l:SetFont(UI.Police("petit")) l:SetTextColor(COL.TexteSombre)
		l:SetText("Aucun log pour ces filtres.")
		return
	end
	local nomCat = categorie
	for _, c in ipairs(CS.CategoriesLogs) do if c.id == categorie then nomCat = c.Nom end end
	for _, e in ipairs(lignes) do
		local ligne = liste:Add("DButton")
		ligne:Dock(TOP)
		ligne:SetTall(UI.S(28))
		ligne:DockMargin(0, 0, 0, UI.S(2))
		ligne:SetText("")
		ligne:SetTooltip(e.texte)
		ligne.Paint = function(s, lw, lh)
			UI.Rect(0, 0, lw, lh, s:IsHovered() and COL.Survol or COL.FondClair)
			UI.Texte(dateLog(e.date), "petit", UI.S(8), lh / 2, COL.TexteSombre, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			UI.Texte(e.acteur_nom or "—", "petit_gras", UI.S(140), lh / 2, COL.Or, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			local x = UI.S(390)
			UI.Texte(e.texte or "", "petit", x, lh / 2, COL.Texte, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			if e.cible_nom then
				UI.Texte("-> " .. e.cible_nom, "petit_gras", lw - UI.S(8), lh / 2, COL.Texte, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
		end
		ligne.DoClick = function() detailLog(nomCat, e) end
	end
end

---------------------------------------------------------------------------
-- Réseau
---------------------------------------------------------------------------
net.Receive("origine_staff_ouvrir", function() S.Ouvrir() end)
net.Receive("origine_staff_resultats", function() S.AfficherResultats(ORIGINE.NetLireTable()) end)
net.Receive("origine_staff_fiche", function()
	local fiche = ORIGINE.NetLireTable()
	if IsValid(S.Fenetre) and S.Onglet == "joueurs" then S.AfficherFiche(fiche) else S.DerniereFiche = fiche end
end)
net.Receive("origine_staff_historique", function() S.AfficherHistorique(ORIGINE.NetLireTable()) end)
net.Receive("origine_staff_logs", function()
	local categorie = net.ReadString()
	local page = net.ReadUInt(16)
	local suite = net.ReadBool()
	local lignes = ORIGINE.NetLireTable()
	S.AfficherLogs(categorie, page, suite, lignes)
end)
