--[[-----------------------------------------------------------------------
	Origine du monde — banque (client)

	Le client affiche et envoie des demandes ; le serveur vérifie tout.
	Onglets : Mon compte, Prêt, Trésor (jobs de la banque), Administration
	(permission origine_banque_admin).
-------------------------------------------------------------------------]]

local B = ORIGINE.Banque
local CB = ORIGINE.ConfigBanque
local UI = ORIGINE.UI
local COL = UI.C

local function covan(n) return ORIGINE.FormaterCovan(math.floor(tonumber(n) or 0)) end
local function date(t) return t and os.date("%d/%m/%Y %H:%M", tonumber(t)) or "—" end

local function action(nom, args)
	if not IsValid(B.Guichet) then return end
	net.Start("origine_banque_action")
		net.WriteEntity(B.Guichet)
		net.WriteString(nom)
		ORIGINE.NetEcrireTable(args or {})
	net.SendToServer()
end

local function actionAdmin(nom, args)
	if not IsValid(B.Guichet) then return end
	net.Start("origine_banque_admin")
		net.WriteEntity(B.Guichet)
		net.WriteString(nom)
		ORIGINE.NetEcrireTable(args or {})
	net.SendToServer()
end

---------------------------------------------------------------------------
-- Petits composants
---------------------------------------------------------------------------
local function panneau(parent, hauteur)
	local p = vgui.Create("DPanel", parent)
	p:Dock(TOP)
	p:SetTall(hauteur)
	p:DockMargin(0, 0, 0, UI.S(8))
	p.Paint = nil
	return p
end

local function titre(parent, texte)
	local p = panneau(parent, UI.S(28))
	p.Paint = function(_, w, h)
		UI.Texte(texte, "texte_gras", 0, h / 2, COL.Or, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetDrawColor(COL.Or.r, COL.Or.g, COL.Or.b, 90)
		surface.DrawRect(0, h - 1, w, 1)
	end
	return p
end

local function texte(parent, t, col)
	local lignes = UI.Couper(t, "texte", parent:GetWide() > 0 and parent:GetWide() - UI.S(10) or UI.S(700))
	local p = panneau(parent, math.max(1, #lignes) * UI.S(22))
	p.Paint = function()
		for i, l in ipairs(lignes) do UI.Texte(l, "texte", 0, (i - 1) * UI.S(22), col or COL.Texte) end
	end
	return p
end

-- Rangée : champs de saisie + bouton ; fn(valeurs)
local function rangee(parent, libelle, champs, texteBouton, fn)
	local p = panneau(parent, UI.S(36))
	local l = vgui.Create("DLabel", p)
	l:Dock(LEFT) l:SetWide(UI.S(150))
	l:SetFont(UI.Police("texte_gras")) l:SetTextColor(COL.Texte) l:SetText(libelle)
	local b = UI.Bouton(p, texteBouton, nil)
	b:Dock(RIGHT) b:SetWide(UI.S(170)) b:DockMargin(UI.S(8), 0, 0, 0)
	local entrees = {}
	for i = #champs, 1, -1 do
		local c = champs[i]
		local e = UI.Entree(p, c.indication)
		e:Dock(c.large and FILL or RIGHT)
		if not c.large then e:SetWide(UI.S(c.largeur or 150)) end
		e:DockMargin(UI.S(6), 0, 0, 0)
		if c.numerique then e:SetNumeric(true) end
		entrees[i] = e
	end
	b.DoClick = function()
		surface.PlaySound("ui/buttonclick.wav")
		local v = {}
		for i, e in ipairs(entrees) do v[i] = e:GetText() end
		fn(v)
	end
	return p
end

-- Liste à colonnes : colonnes = { { nom, largeur (fraction) } }, lignes = { { valeurs… , couleur = } }
local function liste(parent, colonnes, lignes, hauteur)
	local cadre = vgui.Create("DPanel", parent)
	cadre:Dock(hauteur and TOP or FILL)
	if hauteur then cadre:SetTall(hauteur) end
	cadre.Paint = function(_, w, h) UI.Rect(0, 0, w, h, Color(0, 0, 0, 60)) end
	local entete = vgui.Create("DPanel", cadre)
	entete:Dock(TOP) entete:SetTall(UI.S(24))
	entete.Paint = function(_, w, h)
		local x = UI.S(6)
		for _, c in ipairs(colonnes) do
			UI.Texte(c[1], "petit_gras", x, h / 2, COL.TexteSombre, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			x = x + w * c[2]
		end
	end
	local scroll = UI.StyliserScroll(vgui.Create("DScrollPanel", cadre))
	scroll:Dock(FILL)
	if #lignes == 0 then
		local v = scroll:Add("DLabel")
		v:Dock(TOP) v:SetTall(UI.S(24)) v:SetFont(UI.Police("petit")) v:SetTextColor(COL.TexteSombre)
		v:SetText("   Rien à afficher.")
	end
	for i, l in ipairs(lignes) do
		local r = scroll:Add("DPanel")
		r:Dock(TOP) r:SetTall(UI.S(22))
		r.Paint = function(_, w, h)
			if i % 2 == 0 then UI.Rect(0, 0, w, h, Color(255, 255, 255, 6)) end
			local x = UI.S(6)
			for k, c in ipairs(colonnes) do
				local v = tostring(l[k] or "")
				UI.Texte(UI.Couper(v, "petit", w * c[2] - UI.S(8))[1] or "", "petit", x, h / 2,
					(l.couleurs and l.couleurs[k]) or COL.Texte, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				x = x + w * c[2]
			end
		end
	end
	return cadre
end

local function nombre(v) return math.floor(tonumber(v) or 0) end

---------------------------------------------------------------------------
-- Onglet : Mon compte
---------------------------------------------------------------------------
local function ongletCompte(corps, d)
	local plaques = panneau(corps, UI.S(64))
	plaques.Paint = function(_, w, h)
		local lw = w / 2 - UI.S(6)
		for i, info in ipairs({ { "Bourse (sur vous)", d.bourse }, { "Compte en banque", d.solde } }) do
			local x = (i - 1) * (lw + UI.S(12))
			UI.Cadre(x, 0, lw, h, COL.FondClair)
			UI.Texte(info[1], "petit_gras", x + UI.S(14), UI.S(10), COL.TexteSombre)
			UI.Texte(covan(info[2]), "sous_titre", x + UI.S(14), UI.S(28), COL.Or)
		end
	end

	local f = d.frais or {}
	rangee(corps, "Déposer", { { indication = "Montant", numerique = true } },
		"Déposer" .. ((f.Depot or 0) > 0 and (" (" .. f.Depot .. " %)") or ""),
		function(v) action("deposer", { montant = nombre(v[1]) }) end)
	rangee(corps, "Retirer", { { indication = "Montant", numerique = true } },
		"Retirer" .. ((f.Retrait or 0) > 0 and (" (" .. f.Retrait .. " %)") or ""),
		function(v) action("retirer", { montant = nombre(v[1]) }) end)
	rangee(corps, "Virement", { { indication = "Prénom Nom du personnage", large = true }, { indication = "Montant", numerique = true } },
		"Envoyer" .. ((f.Virement or 0) > 0 and (" (" .. f.Virement .. " %)") or ""),
		function(v) action("virement", { nom = v[1], montant = nombre(v[2]) }) end)

	titre(corps, "Relevé (" .. #(d.releve or {}) .. " dernières opérations)")
	local lignes = {}
	for _, o in ipairs(d.releve or {}) do
		local m = nombre(o.montant)
		lignes[#lignes + 1] = {
			date(o.date), (d.types and d.types[o.type]) or o.type, (m > 0 and "+" or "") .. covan(m),
			nombre(o.frais) > 0 and covan(o.frais) or "", covan(o.solde), o.detail or "",
			couleurs = { nil, nil, m >= 0 and COL.Succes or COL.Alerte },
		}
	end
	liste(corps, { { "Date", 0.17 }, { "Opération", 0.2 }, { "Montant", 0.15 }, { "Frais", 0.1 }, { "Solde", 0.15 }, { "Détail", 0.23 } }, lignes)
end

---------------------------------------------------------------------------
-- Onglet : Prêt
---------------------------------------------------------------------------
local function ongletPret(corps, d)
	titre(corps, "Mon prêt")
	local p = d.pret
	if not p then
		texte(corps, "Aucun prêt en cours.", COL.TexteSombre)
	elseif p.etat == "propose" then
		texte(corps, string.format("%s vous propose un prêt de %s à %s %% sur %d jours. Total à rembourser : %s.",
			p.banquier_nom or "La banque", covan(p.montant), tostring(p.taux), nombre(p.jours), covan(p.total)))
		local r = panneau(corps, UI.S(36))
		local oui = UI.Bouton(r, "Accepter", function()
			UI.Confirmer("Accepter le prêt", "Vous devrez rembourser " .. covan(p.total) .. " avant l'échéance.", function() action("accepter") end, "Accepter")
		end)
		oui:Dock(LEFT) oui:SetWide(UI.S(200))
		local non = UI.Bouton(r, "Refuser", function() action("refuser") end)
		non:Dock(LEFT) non:SetWide(UI.S(200)) non:DockMargin(UI.S(8), 0, 0, 0)
	else
		texte(corps, string.format("Reste à rembourser : %s sur %s — échéance le %s%s",
			covan(p.restant), covan(p.total), date(p.echeance), p.en_retard and " (EN RETARD)" or ""),
			p.en_retard and COL.Alerte or COL.Texte)
		rangee(corps, "Rembourser", { { indication = "Montant (depuis le compte)", numerique = true, largeur = 240 } }, "Rembourser",
			function(v) action("rembourser", { montant = nombre(v[1]) }) end)
	end

	if not d.droits.preter then return end
	titre(corps, "Proposer un prêt (banquier)")
	local pm = d.pretMax or CB.Pret
	rangee(corps, "Personnage", { { indication = "Prénom Nom", large = true }, { indication = "Montant (max " .. nombre(pm.MontantMax) .. ")", numerique = true, largeur = 180 },
		{ indication = "Taux % (max " .. tostring(pm.TauxMax) .. ")", numerique = true, largeur = 130 }, { indication = "Jours (max " .. nombre(pm.EcheanceMaxJours) .. ")", numerique = true, largeur = 130 } },
		"Proposer", function(v)
			action("proposer", { nom = v[1], montant = nombre(v[2]), taux = tonumber(v[3]) or -1, jours = nombre(v[4]) })
		end)
	titre(corps, "Débiteurs (échéance dépassée)")
	local lignes = {}
	for _, x in ipairs(d.debiteurs or {}) do
		lignes[#lignes + 1] = { "n°" .. x.id, x.nom or "?", covan(x.restant), date(x.echeance), x.banquier_nom or "",
			couleurs = { nil, nil, COL.Alerte } }
	end
	liste(corps, { { "Prêt", 0.1 }, { "Personnage", 0.3 }, { "Reste", 0.2 }, { "Échéance", 0.2 }, { "Accordé par", 0.2 } }, lignes)
end

---------------------------------------------------------------------------
-- Onglet : Trésor
---------------------------------------------------------------------------
local function ongletTresor(corps, d)
	local p = panneau(corps, UI.S(56))
	p.Paint = function(_, w, h)
		UI.Cadre(0, 0, w, h, COL.FondClair)
		UI.Texte("Trésor de la banque", "petit_gras", UI.S(14), UI.S(8), COL.TexteSombre)
		UI.Texte(covan(d.tresor), "sous_titre", UI.S(14), UI.S(24), COL.Or)
	end
	if d.droits.retirer then
		rangee(corps, "Retirer", { { indication = "Motif", large = true }, { indication = "Montant", numerique = true } }, "Vers ma bourse",
			function(v) action("retirer_tresor", { motif = v[1], montant = nombre(v[2]) }) end)
	end
	if not d.mouvements then return end
	titre(corps, "Mouvements du trésor")
	local lignes = {}
	for _, m in ipairs(d.mouvements) do
		local n = nombre(m.montant)
		lignes[#lignes + 1] = { date(m.date), m.acteur_nom or "", (n > 0 and "+" or "") .. covan(n), m.motif or "", covan(m.solde),
			couleurs = { nil, nil, n >= 0 and COL.Succes or COL.Alerte } }
	end
	liste(corps, { { "Date", 0.17 }, { "Qui", 0.23 }, { "Montant", 0.15 }, { "Pourquoi", 0.3 }, { "Solde", 0.15 } }, lignes)
end

---------------------------------------------------------------------------
-- Onglet : Administration (staff)
---------------------------------------------------------------------------
local function demanderCorrection(titreFenetre, fn)
	UI.Demander(titreFenetre, {
		{ libelle = "Montant (positif pour ajouter, négatif pour retirer)", indication = "-500" },
		{ libelle = "Raison (obligatoire)", indication = "Ex. : paiement fait avec un autre personnage" },
	}, function(v)
		local m = tonumber(v[1])
		if not m or m == 0 then return UI.Notifier("Montant invalide.", "erreur") end
		if string.Trim(v[2] or "") == "" then return UI.Notifier("La raison est obligatoire.", "erreur") end
		fn(math.floor(m), v[2])
	end)
end

local function afficherFicheAdmin()
	local pan, f = B.PanneauAdmin, B.FicheAdmin
	if not (IsValid(pan) and f) then return end
	pan:Clear()
	titre(pan, (f.nom_steam or "Joueur") .. "  ·  " .. f.sid)
	local lignes = {}
	for slot = 1, 5 do
		local s = f.slots[slot] or {}
		local pret = s.pret and (covan(s.pret.restant) .. (s.pret.etat == "propose" and " (proposé)" or (" — " .. date(s.pret.echeance)))) or "—"
		lignes[#lignes + 1] = { slot .. " · " .. (s.type or ""), s.nom and (s.nom .. (s.joue and " (en jeu)" or "")) or "—",
			s.nom and covan(s.bourse) or "—", s.nom and covan(s.compte) or "—", pret, s.nom and covan(s.total) or "—" }
	end
	liste(pan, { { "Slot", 0.16 }, { "Personnage", 0.26 }, { "Bourse", 0.13 }, { "Compte", 0.13 }, { "Prêt", 0.19 }, { "Total", 0.13 } }, lignes, UI.S(24) + 5 * UI.S(22) + UI.S(4))

	titre(pan, "Corrections")
	for slot = 1, 5 do
		local s = f.slots[slot]
		if s and s.nom then
			local r = panneau(pan, UI.S(32))
			local l = vgui.Create("DLabel", r)
			l:Dock(LEFT) l:SetWide(UI.S(200)) l:SetFont(UI.Police("petit_gras")) l:SetTextColor(COL.Texte)
			l:SetText(slot .. " · " .. s.nom)
			local function bouton(t, fn)
				local b = UI.Bouton(r, t, fn)
				b:Dock(LEFT) b:SetWide(UI.S(150)) b:DockMargin(UI.S(6), 0, 0, 0)
			end
			bouton("Bourse ±", function()
				demanderCorrection("Bourse de " .. s.nom, function(m, raison)
					actionAdmin("bourse", { sid = f.sid, slot = slot, montant = m, raison = raison })
				end)
			end)
			bouton("Compte ±", function()
				demanderCorrection("Compte de " .. s.nom, function(m, raison)
					actionAdmin("compte", { sid = f.sid, slot = slot, montant = m, raison = raison })
				end)
			end)
			if s.pret then
				bouton("Annuler le prêt", function()
					UI.Demander("Annuler le prêt n°" .. s.pret.id, { { libelle = "Raison (obligatoire)" } }, function(v)
						actionAdmin("annuler_pret", { id = s.pret.id, sid = f.sid, raison = v[1] })
					end)
				end)
			end
		end
	end

	titre(pan, "Trésor : " .. covan(f.tresor))
	local r = panneau(pan, UI.S(32))
	local b = UI.Bouton(r, "Corriger le trésor", function()
		demanderCorrection("Trésor de la banque", function(m, raison)
			actionAdmin("tresor", { sid = f.sid, montant = m, raison = raison })
		end)
	end)
	b:Dock(LEFT) b:SetWide(UI.S(220))
end

local function afficherResultatsAdmin()
	local res = B.ResultatsAdmin
	if not (IsValid(res) and B.ComptesAdmin) then return end
	res:Clear()
	for _, c in ipairs(B.ComptesAdmin) do
		local b = res:Add("DButton")
		b:Dock(TOP) b:SetText("") b:DockMargin(0, 0, 0, UI.S(4))
		b:SetTall(UI.S(26) + #c.persos * UI.S(18) + UI.S(6))
		b.Paint = function(s, w, h)
			UI.Rect(0, 0, w, h, s:IsHovered() and COL.Survol or COL.FondClair)
			UI.Contour(0, 0, w, h, COL.Bordure, 1)
			UI.Texte(c.nom_steam or c.sid, "petit_gras", UI.S(6), UI.S(4), COL.Texte)
			if c.en_ligne then UI.Texte("en ligne", "petit", w - UI.S(6), UI.S(4), COL.Succes, TEXT_ALIGN_RIGHT) end
			for i, p in ipairs(c.persos) do
				UI.Texte("Slot " .. p.slot .. "  " .. p.nom, "petit", UI.S(14), UI.S(8) + i * UI.S(18), COL.TexteSombre)
			end
		end
		b.DoClick = function() actionAdmin("fiche", { sid = c.sid }) end
	end
end

local function ongletAdmin(corps)
	local gauche = vgui.Create("DPanel", corps)
	gauche:Dock(LEFT) gauche:SetWide(UI.S(290)) gauche:DockMargin(0, 0, UI.S(10), 0)
	gauche.Paint = nil
	local e = UI.Entree(gauche, "Nom de personnage ou SteamID")
	e:Dock(TOP) e:SetTall(UI.S(32))
	local b = UI.Bouton(gauche, "Rechercher", function() actionAdmin("recherche", { texte = e:GetText() }) end)
	b:Dock(TOP) b:SetTall(UI.S(32)) b:DockMargin(0, UI.S(6), 0, UI.S(6))
	e.OnEnter = function() actionAdmin("recherche", { texte = e:GetText() }) end
	B.ResultatsAdmin = UI.StyliserScroll(vgui.Create("DScrollPanel", gauche))
	B.ResultatsAdmin:Dock(FILL)

	B.PanneauAdmin = UI.StyliserScroll(vgui.Create("DScrollPanel", corps))
	B.PanneauAdmin:Dock(FILL)
	afficherResultatsAdmin()
	if B.FicheAdmin then afficherFicheAdmin() else
		local l = B.PanneauAdmin:Add("DLabel")
		l:Dock(TOP) l:SetTall(UI.S(30)) l:SetFont(UI.Police("texte")) l:SetTextColor(COL.TexteSombre)
		l:SetText("Recherchez un joueur pour voir et corriger les Covan de ses personnages.")
	end
	actionAdmin("recherche", { texte = "" })
end

net.Receive("origine_banque_admin_resultats", function()
	B.ComptesAdmin = ORIGINE.NetLireTable()
	afficherResultatsAdmin()
end)
net.Receive("origine_banque_admin_fiche", function()
	B.FicheAdmin = ORIGINE.NetLireTable()
	afficherFicheAdmin()
end)

---------------------------------------------------------------------------
-- Fenêtre
---------------------------------------------------------------------------
local ONGLETS = {
	{ id = "compte", nom = "Mon compte", fn = ongletCompte },
	{ id = "pret", nom = "Prêt", fn = ongletPret },
	{ id = "tresor", nom = "Trésor", fn = ongletTresor, visible = function(d) return d.droits.consulter or d.droits.retirer end },
	{ id = "admin", nom = "Administration", fn = ongletAdmin, visible = function(d) return d.admin end },
}

function B.Rafraichir()
	local f = B.Fenetre
	if not (IsValid(f) and B.Donnees) then return end
	f.Onglets:Clear()
	for _, o in ipairs(ONGLETS) do
		if not o.visible or o.visible(B.Donnees) then
			local b = UI.Bouton(f.Onglets, o.nom, function()
				B.Onglet = o.id
				B.Rafraichir()
			end)
			b:Dock(LEFT) b:SetWide(UI.S(180)) b:DockMargin(0, 0, UI.S(8), 0)
			b.PaintOver = function(_, w, h)
				if B.Onglet == o.id then UI.Rect(UI.S(4), h - UI.S(4), w - UI.S(8), UI.S(2), COL.Or) end
			end
		end
	end
	local corps = f.Corps
	-- L'onglet admin garde sa recherche : on ne le reconstruit que si on vient d'y entrer
	if B.Onglet == "admin" and corps.Onglet == "admin" then return end
	corps:Clear()
	corps.Onglet = B.Onglet
	for _, o in ipairs(ONGLETS) do
		if o.id == B.Onglet and (not o.visible or o.visible(B.Donnees)) then
			o.fn(corps, B.Donnees)
			return
		end
	end
	B.Onglet = "compte"
	corps.Onglet = "compte"
	ongletCompte(corps, B.Donnees)
end

function B.OuvrirFenetre()
	if IsValid(B.Fenetre) then B.Fenetre:Close() end
	local w, h = math.min(ScrW() - UI.S(40), UI.S(980)), math.min(ScrH() - UI.S(40), UI.S(680))
	local f = UI.Fenetre("Banque", w, h)
	B.Fenetre = f
	B.Onglet = B.Onglet or "compte"
	f.Onglets = vgui.Create("DPanel", f)
	f.Onglets:Dock(TOP) f.Onglets:SetTall(UI.S(36)) f.Onglets:DockMargin(0, 0, 0, UI.S(10))
	f.Onglets.Paint = nil
	f.Corps = vgui.Create("DPanel", f)
	f.Corps:Dock(FILL)
	f.Corps.Paint = nil
	f.Think = function(s)
		-- Fermée si le joueur s'éloigne du guichet
		if not IsValid(B.Guichet) or LocalPlayer():GetPos():Distance(B.Guichet:GetPos()) > CB.Portee + 40 then s:Close() end
	end
	B.Rafraichir()
end

net.Receive("origine_banque_ouvrir", function()
	B.Guichet = net.ReadEntity()
	B.Donnees = nil
	B.OuvrirFenetre()
end)

net.Receive("origine_banque_donnees", function()
	B.Donnees = ORIGINE.NetLireTable()
	if IsValid(B.Fenetre) then
		if B.Fenetre.Corps then B.Fenetre.Corps.Onglet = nil end
		B.Rafraichir()
	end
end)
