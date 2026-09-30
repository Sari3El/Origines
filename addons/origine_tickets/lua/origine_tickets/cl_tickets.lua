--[[-----------------------------------------------------------------------
	Origine du monde — tickets (client)

	F6 : joueur -> ses tickets et « Nouveau ticket » ;
	     staff  -> File, Historique, Mes tickets, Statistiques (admin).
	Textes affichés en texte brut.
-------------------------------------------------------------------------]]

local T = ORIGINE.Tickets
local CT = ORIGINE.ConfigTickets
local UI = ORIGINE.UI
local COL = UI.C

local function date(t) return t and os.date("%d/%m/%Y %H:%M", t) or "—" end

local function demande(quoi, a)
	net.Start("origine_tickets_demande")
		net.WriteString(quoi)
		ORIGINE.NetEcrireTable(a or {})
	net.SendToServer()
end

local function action(id, nom, a)
	a = a or {}
	a.id, a.action = id, nom
	demande("action", a)
end

local function titre(parent, texte, col)
	local p = vgui.Create("DPanel", parent)
	p:Dock(TOP) p:SetTall(UI.S(28)) p:DockMargin(0, UI.S(4), 0, UI.S(4))
	p.Paint = function(_, w, h)
		UI.Texte(texte, "texte_gras", 0, h / 2, col or COL.Or, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetDrawColor(COL.Or.r, COL.Or.g, COL.Or.b, 80)
		surface.DrawRect(0, h - 1, w, 1)
	end
	return p
end

local function rangeeBoutons(parent)
	local r = vgui.Create("DPanel", parent)
	r:Dock(TOP) r:SetTall(UI.S(32)) r:DockMargin(0, 0, 0, UI.S(6)) r.Paint = nil
	function r:Ajouter(texte, fn, largeur)
		local b = UI.Bouton(self, texte, fn)
		b:Dock(LEFT) b:SetWide(UI.S(largeur or 150)) b:DockMargin(0, 0, UI.S(6), 0)
		return b
	end
	return r
end

-- Bloc de texte brut, hauteur ajustée au contenu
local function texteBloc(parent, texte, couleur, police)
	local lignes = {}
	for _, para in ipairs(string.Explode("\n", texte or "")) do
		for _, l in ipairs(UI.Couper(para, police or "texte", UI.S(560))) do lignes[#lignes + 1] = l end
		if para == "" then lignes[#lignes + 1] = "" end
	end
	local p = vgui.Create("DPanel", parent)
	p:Dock(TOP) p:SetTall(math.max(1, #lignes) * UI.S(20) + UI.S(4))
	p.Paint = function()
		for i, l in ipairs(lignes) do UI.Texte(l, police or "texte", 0, (i - 1) * UI.S(20), couleur or COL.Texte) end
	end
	return p
end

---------------------------------------------------------------------------
-- Actions ULX rapides sur un joueur (aller vers, ramener, renvoyer, observer, geler)
---------------------------------------------------------------------------
local ULX_RAPIDES = {
	{ "Aller vers", "goto" }, { "Ramener", "bring" }, { "Renvoyer", "return" },
	{ "Observer", "spectate" }, { "Geler", "freeze" }, { "Dégeler", "unfreeze" },
}

local function menuULX(sid, nom)
	local cible = player.GetBySteamID64(sid)
	local m = DermaMenu()
	if not IsValid(cible) then
		m:AddOption(nom .. " n'est pas connecté"):SetEnabled(false)
	else
		for _, a in ipairs(ULX_RAPIDES) do
			local cmd = "ulx " .. a[2]
			local dispo = ULib and ULib.ucl and ULib.cmds and ULib.cmds.translatedCmds and ULib.cmds.translatedCmds[cmd]
				and ULib.ucl.query(LocalPlayer(), cmd)
			if dispo then
				m:AddOption(a[1], function()
					if IsValid(cible) then RunConsoleCommand("ulx", a[2], cible:IsBot() and cible:Nick() or ("$" .. cible:SteamID())) end
				end)
			end
		end
	end
	if ORIGINE.Staff and ORIGINE.Staff.OuvrirFicheJoueur and ORIGINE.APermission(LocalPlayer(), "origine_menu") then
		m:AddSpacer()
		m:AddOption("Ouvrir dans !origine", function()
			ORIGINE.Staff.FicheEnAttente = sid
			RunConsoleCommand("origine")
			if IsValid(T.Fenetre) then T.Fenetre:Close() end
		end):SetIcon("icon16/book.png")
	end
	m:Open()
end

---------------------------------------------------------------------------
-- Détail d'un ticket
---------------------------------------------------------------------------
local function demanderNote(t, fermer)
	local f = UI.Fenetre(fermer and "Fermer le ticket" or "Noter la prise en charge", UI.S(460), UI.S(300))
	f:SetDrawOnTop(true)
	local note = 5
	local l = vgui.Create("DLabel", f)
	l:Dock(TOP) l:SetTall(UI.S(22)) l:SetFont(UI.Police("petit_gras")) l:SetTextColor(COL.TexteSombre)
	l:SetText("Votre note (1 à 5)")
	local etoiles = vgui.Create("DPanel", f)
	etoiles:Dock(TOP) etoiles:SetTall(UI.S(40)) etoiles.Paint = nil
	for i = 1, 5 do
		local b = vgui.Create("DButton", etoiles)
		b:Dock(LEFT) b:SetWide(UI.S(52)) b:SetText("")
		b:DockMargin(0, 0, UI.S(6), 0)
		b.Paint = function(s, w, h)
			UI.Rect(0, 0, w, h, i <= note and COL.Survol or COL.FondClair)
			UI.Contour(0, 0, w, h, i <= note and COL.Or or COL.Bordure, UI.S(2))
			UI.Texte(tostring(i), "sous_titre", w / 2, h / 2, i <= note and COL.Or or COL.TexteSombre, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		b.DoClick = function() note = i end
	end
	local l2 = vgui.Create("DLabel", f)
	l2:Dock(TOP) l2:SetTall(UI.S(22)) l2:SetFont(UI.Police("petit_gras")) l2:SetTextColor(COL.TexteSombre)
	l2:SetText("Commentaire (facultatif)")
	local c = UI.Entree(f, "Votre avis sur la prise en charge")
	c:Dock(TOP) c:SetTall(UI.S(34))
	local ok = UI.Bouton(f, fermer and "Fermer le ticket" or "Envoyer", function()
		action(t.id, fermer and "fermer" or "noter", { note = note, commentaire = c:GetText() })
		f:Close()
	end)
	ok:Dock(BOTTOM) ok:SetTall(UI.S(38))
end

function T.AfficherDetail(t)
	local pan = T.Fenetre and T.Fenetre.Detail
	if not IsValid(pan) then return end
	pan:Clear()
	T.Actuel = t
	local staff = t.vue_staff
	local statut = T.Statuts[t.statut] or t.statut

	local haut = vgui.Create("DPanel", pan)
	haut:Dock(TOP) haut:SetTall(UI.S(64))
	haut.Paint = function(_, w)
		UI.Texte("Ticket n°" .. t.id .. " — " .. (t.categorie or ""), "sous_titre", 0, 0, COL.Or)
		UI.Texte(statut, "texte_gras", w, UI.S(4), T.CouleursStatuts[t.statut] or COL.Texte, TEXT_ALIGN_RIGHT)
		local ligne = "Ouvert le " .. date(t.date) .. "  ·  " .. (t.staff_nom and ("Suivi par " .. t.staff_nom) or "En attente d'un staff")
		if staff then ligne = ligne .. "  ·  Priorité : " .. (CT.Priorites[t.priorite] or "?") end
		UI.Texte(ligne, "petit", 0, UI.S(36), COL.TexteSombre)
	end

	local corps = UI.StyliserScroll(vgui.Create("DScrollPanel", pan))

	-- Zone de réponse (en bas)
	if t.statut ~= "ferme" then
		local bas = vgui.Create("DPanel", pan)
		bas:Dock(BOTTOM) bas:SetTall(UI.S(40)) bas:DockMargin(0, UI.S(6), 0, 0) bas.Paint = nil
		local e = UI.Entree(bas, staff and "Réponse au joueur (ou note interne)" or "Votre message au staff")
		e:Dock(FILL)
		e.AllowInput = function(s) return utf8.len(s:GetText() or "") >= CT.LongueurMessage end
		local rep = UI.Bouton(bas, "Répondre", function()
			if string.Trim(e:GetText()) == "" then return end
			action(t.id, "repondre", { texte = e:GetText() })
		end)
		rep:Dock(RIGHT) rep:SetWide(UI.S(130)) rep:DockMargin(UI.S(6), 0, 0, 0)
		if staff then
			local note = UI.Bouton(bas, "Note interne", function()
				if string.Trim(e:GetText()) == "" then return end
				action(t.id, "note", { texte = e:GetText() })
			end)
			note:Dock(RIGHT) note:SetWide(UI.S(140)) note:DockMargin(UI.S(6), 0, 0, 0)
		end
	end
	corps:Dock(FILL)

	-- Actions
	if staff then
		local r1 = rangeeBoutons(corps)
		if t.statut ~= "ferme" then
			r1:Ajouter("Prendre en charge", function() action(t.id, "prendre") end, 170)
			r1:Ajouter("Attendre le joueur", function() action(t.id, "attente") end, 170)
			r1:Ajouter("Transférer", function()
				local m = DermaMenu()
				for _, p in ipairs(player.GetAll()) do
					if p ~= LocalPlayer() and ORIGINE.APermission(p, "origine_tickets_staff") then
						m:AddOption(ORIGINE.NomSteam(p), function() action(t.id, "transferer", { sid = p:SteamID64() }) end)
					end
				end
				if m:ChildCount() == 0 then m:AddOption("Aucun autre staff connecté"):SetEnabled(false) end
				m:Open()
			end, 130)
			r1:Ajouter("Fermer", function()
				UI.Demander("Fermer le ticket n°" .. t.id, { { libelle = "Note de résolution (visible par le joueur)" } }, function(v)
					action(t.id, "fermer", { resolution = v[1] })
				end, "Fermer")
			end, 110)
		else
			r1:Ajouter("Rouvrir", function() action(t.id, "rouvrir") end, 130)
		end
		local r2 = rangeeBoutons(corps)
		local prio = UI.Combo(r2)
		prio:Dock(LEFT) prio:SetWide(UI.S(170)) prio:DockMargin(0, 0, UI.S(6), 0)
		for i, nom in ipairs(CT.Priorites) do prio:AddChoice("Priorité : " .. nom, i, i == t.priorite) end
		prio.OnSelect = function(_, _, _, p) action(t.id, "priorite", { priorite = p }) end
		r2:Ajouter("Auteur : " .. (t.auteur_nom or "?"), function() menuULX(t.auteur_sid, t.auteur_nom or "?") end, 240)
		for _, c in ipairs(t.concernes or {}) do
			r2:Ajouter(c.nom or c.sid, function() menuULX(c.sid, c.nom or c.sid) end, 150)
		end
		if ORIGINE.APermission(LocalPlayer(), "origine_tickets_admin") then
			local r3 = rangeeBoutons(corps)
			r3:Ajouter("Supprimer le ticket", function()
				UI.Confirmer("Supprimer", "Supprimer définitivement le ticket n°" .. t.id .. " ?", function()
					action(t.id, "supprimer")
					pan:Clear()
				end, "Supprimer")
			end, 190)
		end

		-- Contexte joint automatiquement
		local c = t.contexte or {}
		titre(corps, "Contexte")
		texteBloc(corps, string.format("Joueur : %s (%s)\nPersonnage : %s (slot %s) · Job : %s\nPosition : %s · Carte : %s\nHeure : %s%s",
			t.auteur_nom or "?", t.auteur_sid or "?", c.personnage or "aucun", tostring(c.slot or "—"), c.job or "—",
			c.position or "—", c.carte or "—", c.date or "—", c.heure_rp and (" · Heure RP : " .. c.heure_rp) or ""), COL.TexteSombre, "petit")
	elseif t.statut ~= "ferme" then
		local r = rangeeBoutons(corps)
		r:Ajouter("Fermer mon ticket", function() demanderNote(t, true) end, 190)
	elseif not t.note then
		local r = rangeeBoutons(corps)
		r:Ajouter("Noter la prise en charge", function() demanderNote(t, false) end, 240)
	end

	if #(t.concernes or {}) > 0 then
		local noms = {}
		for _, c in ipairs(t.concernes) do noms[#noms + 1] = c.nom or c.sid end
		titre(corps, "Joueurs concernés")
		texteBloc(corps, table.concat(noms, ", "), COL.TexteSombre, "petit")
	end

	titre(corps, "Demande")
	texteBloc(corps, t.description)
	titre(corps, "Discussion")
	if #(t.messages or {}) == 0 then texteBloc(corps, "Aucune réponse pour l'instant.", COL.TexteSombre, "petit") end
	for _, m in ipairs(t.messages or {}) do
		local couleur = m.interne and Color(200, 170, 90) or (m.staff and COL.Succes or COL.Texte)
		local entete = (m.interne and "[Note interne] " or "") .. (m.auteur_nom or "?") .. (m.staff and " (staff)" or "") .. " — " .. date(m.date)
		texteBloc(corps, entete, couleur, "petit_gras")
		texteBloc(corps, m.texte)
	end
	if t.statut == "ferme" then
		titre(corps, "Résolution", T.CouleursStatuts.ferme)
		texteBloc(corps, (t.resolution or "—") .. (t.note and ("\nNote du joueur : " .. t.note .. "/5" ..
			((t.commentaire and t.commentaire ~= "") and (" — " .. t.commentaire) or "")) or ""), COL.TexteSombre)
	end
end

net.Receive("origine_tickets_detail", function() T.AfficherDetail(ORIGINE.NetLireTable()) end)

---------------------------------------------------------------------------
-- Listes
---------------------------------------------------------------------------
function T.AfficherListe(d)
	local f = T.Fenetre
	if not (IsValid(f) and IsValid(f.Liste)) or d.vue ~= T.Vue then return end
	f.Liste:Clear()
	f.Page = d.page or 0
	if #d.tickets == 0 then
		local l = f.Liste:Add("DLabel")
		l:Dock(TOP) l:SetTall(UI.S(34)) l:SetFont(UI.Police("petit")) l:SetTextColor(COL.TexteSombre)
		l:SetText("  Aucun ticket.")
	end
	for _, t in ipairs(d.tickets) do
		local b = f.Liste:Add("DButton")
		b:Dock(TOP) b:SetTall(UI.S(52)) b:SetText("") b:DockMargin(0, 0, 0, UI.S(3))
		b.Paint = function(s, w, h)
			local choisi = T.Actuel and T.Actuel.id == t.id
			UI.Rect(0, 0, w, h, (s:IsHovered() or choisi) and COL.Survol or COL.FondClair)
			UI.Rect(0, 0, UI.S(4), h, T.CouleursStatuts[t.statut] or COL.Bordure)
			UI.Texte("n°" .. t.id .. "  " .. (t.categorie or ""), "texte_gras", UI.S(12), UI.S(4), COL.Texte)
			UI.Texte(T.Statuts[t.statut] or t.statut, "petit_gras", w - UI.S(8), UI.S(6), T.CouleursStatuts[t.statut] or COL.Texte, TEXT_ALIGN_RIGHT)
			local sous = (T.Vue == "mes") and date(t.date) or ((t.auteur_nom or "?") .. "  ·  " .. date(t.date))
			if T.Vue ~= "mes" and t.priorite == 3 then sous = "PRIORITÉ HAUTE  ·  " .. sous end
			if t.staff_nom and T.Vue ~= "mes" then sous = sous .. "  ·  " .. t.staff_nom end
			UI.Texte(sous, "petit", UI.S(12), UI.S(28), (t.priorite == 3 and T.Vue ~= "mes") and COL.Alerte or COL.TexteSombre)
			if T.Vue == "mes" and t.non_lu_joueur == 1 then UI.Texte("Nouvelle réponse", "petit_gras", w - UI.S(8), UI.S(28), COL.Or, TEXT_ALIGN_RIGHT) end
		end
		b.DoClick = function() demande("detail", { id = t.id }) end
	end
end

net.Receive("origine_tickets_liste", function() T.AfficherListe(ORIGINE.NetLireTable()) end)

---------------------------------------------------------------------------
-- Nouveau ticket
---------------------------------------------------------------------------
local function nouveauTicket()
	local pan = T.Fenetre.Detail
	pan:Clear()
	T.Actuel = nil
	titre(pan, "Nouveau ticket")
	local cat = UI.Combo(pan)
	cat:Dock(TOP) cat:SetTall(UI.S(32)) cat:DockMargin(0, 0, 0, UI.S(8))
	for i, c in ipairs(CT.Categories) do cat:AddChoice(c, c, i == 1) end

	local lj = vgui.Create("DLabel", pan)
	lj:Dock(TOP) lj:SetTall(UI.S(20)) lj:SetFont(UI.Police("petit_gras")) lj:SetTextColor(COL.TexteSombre)
	lj:SetText("Joueurs concernés (facultatif)")
	local liste = UI.StyliserScroll(vgui.Create("DScrollPanel", pan))
	liste:Dock(TOP) liste:SetTall(UI.S(110)) liste:DockMargin(0, 0, 0, UI.S(8))
	liste.Paint = function(_, w, h) UI.Rect(0, 0, w, h, Color(0, 0, 0, 60)) end
	local choisis = {}
	for _, p in ipairs(player.GetAll()) do
		if p ~= LocalPlayer() then
			local c = liste:Add("DCheckBoxLabel")
			c:Dock(TOP) c:DockMargin(UI.S(6), UI.S(3), 0, 0)
			c:SetText(ORIGINE.NomSteam(p)) c:SetFont(UI.Police("petit")) c:SetTextColor(COL.Texte)
			local sid = p:SteamID64()
			c.OnChange = function(_, v) choisis[sid] = v or nil end
		end
	end

	local bas = vgui.Create("DPanel", pan)
	bas:Dock(BOTTOM) bas:SetTall(UI.S(40)) bas.Paint = nil
	local compteur = vgui.Create("DPanel", pan)
	compteur:Dock(BOTTOM) compteur:SetTall(UI.S(20))
	local desc = vgui.Create("DTextEntry", pan)
	desc:Dock(FILL)
	desc:SetMultiline(true)
	desc:SetFont(UI.Police("texte"))
	desc:SetPlaceholderText("Décrivez votre demande")
	desc:SetPaintBackground(false)
	desc.Paint = function(s, pw, ph)
		UI.Rect(0, 0, pw, ph, Color(16, 12, 9, 230))
		UI.Contour(0, 0, pw, ph, s:HasFocus() and COL.Or or COL.Bordure, UI.S(2))
		if s:GetText() == "" and not s:HasFocus() then UI.Texte("Décrivez votre demande", "texte", UI.S(8), UI.S(6), COL.TexteSombre) end
		s:DrawTextEntryText(COL.Texte, COL.Or, COL.Texte)
	end
	desc.AllowInput = function(s) return utf8.len(s:GetText() or "") >= CT.LongueurDescription end
	compteur.Paint = function(_, w)
		local n = utf8.len(desc:GetText() or "") or 0
		UI.Texte("Le personnage joué, le job, la position et l'heure sont joints automatiquement.", "petit", 0, UI.S(2), COL.TexteSombre)
		UI.Texte(n .. " / " .. CT.LongueurDescription, "petit", w, UI.S(2), COL.TexteSombre, TEXT_ALIGN_RIGHT)
	end
	local envoyer = UI.Bouton(bas, "Envoyer au staff", function()
		local _, c = cat:GetSelected()
		local concernes = {}
		for sid in pairs(choisis) do concernes[#concernes + 1] = sid end
		demande("creer", { categorie = c or CT.Categories[1], description = desc:GetText(), concernes = concernes })
	end)
	envoyer:Dock(RIGHT) envoyer:SetWide(UI.S(200))
end

---------------------------------------------------------------------------
-- Onglets
---------------------------------------------------------------------------
local function filtres(parent, champs, fn)
	local r = vgui.Create("DPanel", parent)
	r:Dock(TOP) r:SetTall(UI.S(32)) r:DockMargin(0, 0, 0, UI.S(6)) r.Paint = nil
	local valeurs = {}
	for i = #champs, 1, -1 do
		local c = champs[i]
		local el
		if c.choix then
			el = UI.Combo(r)
			for _, ch in ipairs(c.choix) do el:AddChoice(ch[1], ch[2], ch[2] == c.defaut) end
			el.OnSelect = function(_, _, _, v) valeurs[c.cle] = v fn(valeurs) end
			valeurs[c.cle] = c.defaut
		else
			el = UI.Entree(r, c.indication)
			el.OnEnter = function(s) valeurs[c.cle] = s:GetText() fn(valeurs) end
			el.OnChange = function(s) valeurs[c.cle] = s:GetText() end
		end
		el:Dock(i == 1 and FILL or RIGHT)
		if i ~= 1 then el:SetWide(UI.S(c.largeur or 130)) end
		el:DockMargin(UI.S(4), 0, 0, 0)
	end
	return valeurs
end

local function choixCategories()
	local l = { { "Toutes catégories", "" } }
	for _, c in ipairs(CT.Categories) do l[#l + 1] = { c, c } end
	return l
end

local VUES = {
	mes = function(f)
		local b = UI.Bouton(f.Gauche, "Nouveau ticket", nouveauTicket)
		b:Dock(TOP) b:SetTall(UI.S(34)) b:DockMargin(0, 0, 0, UI.S(6))
		demande("mes")
	end,
	file = function(f)
		local v = filtres(f.Gauche, {
			{ cle = "categorie", choix = choixCategories(), defaut = "" },
			{ cle = "statut", choix = { { "Tous statuts", "" }, { "Ouvert", "ouvert" }, { "Pris en charge", "pris" }, { "En attente du joueur", "attente" } }, defaut = "" },
			{ cle = "staff", choix = { { "Tout le staff", "" }, { "Les miens", "moi" }, { "Non attribués", "aucun" } }, defaut = "" },
		}, function(val) demande("file", val) end)
		demande("file", v)
		f.Rafraichir = function() demande("file", v) end
	end,
	historique = function(f)
		local v
		v = filtres(f.Gauche, {
			{ cle = "joueur", indication = "Joueur (nom ou SteamID64)" },
			{ cle = "staff", indication = "Staff", largeur = 110 },
			{ cle = "date", indication = "AAAA-MM-JJ", largeur = 110 },
		}, function(val) val.page = 0 demande("historique", val) end)
		local r = vgui.Create("DPanel", f.Gauche)
		r:Dock(TOP) r:SetTall(UI.S(32)) r:DockMargin(0, 0, 0, UI.S(6)) r.Paint = nil
		local cat = UI.Combo(r)
		cat:Dock(FILL)
		for _, ch in ipairs(choixCategories()) do cat:AddChoice(ch[1], ch[2], ch[2] == "") end
		cat.OnSelect = function(_, _, _, c) v.categorie = c v.page = 0 demande("historique", v) end
		local chercher = UI.Bouton(r, "Chercher", function() v.page = 0 demande("historique", v) end)
		chercher:Dock(RIGHT) chercher:SetWide(UI.S(110)) chercher:DockMargin(UI.S(4), 0, 0, 0)
		local pages = vgui.Create("DPanel", f.Gauche)
		pages:Dock(BOTTOM) pages:SetTall(UI.S(32)) pages:DockMargin(0, UI.S(6), 0, 0) pages.Paint = nil
		local prec = UI.Bouton(pages, "‹", function() v.page = math.max(0, (f.Page or 0) - 1) demande("historique", v) end)
		prec:Dock(LEFT) prec:SetWide(UI.S(60))
		local suiv = UI.Bouton(pages, "›", function() v.page = (f.Page or 0) + 1 demande("historique", v) end)
		suiv:Dock(RIGHT) suiv:SetWide(UI.S(60))
		v.page = 0
		demande("historique", v)
	end,
	stats = function(f)
		f.Detail:Clear()
		demande("stats")
	end,
}

net.Receive("origine_tickets_stats", function()
	local liste = ORIGINE.NetLireTable()
	local f = T.Fenetre
	if not (IsValid(f) and T.Vue == "stats") then return end
	local pan = f.Detail
	pan:Clear()
	titre(pan, "Statistiques par staff (tickets fermés)")
	local entete = vgui.Create("DPanel", pan)
	entete:Dock(TOP) entete:SetTall(UI.S(24))
	local cols = { { "Staff", 0.4 }, { "Traités", 0.15 }, { "1re réponse (moy.)", 0.25 }, { "Note moyenne", 0.2 } }
	entete.Paint = function(_, w, h)
		local x = 0
		for _, c in ipairs(cols) do UI.Texte(c[1], "petit_gras", x, h / 2, COL.TexteSombre, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) x = x + w * c[2] end
	end
	for _, s in ipairs(liste) do
		local r = vgui.Create("DPanel", pan)
		r:Dock(TOP) r:SetTall(UI.S(24))
		local delai = s.delai and (s.delai >= 3600 and string.format("%.1f h", s.delai / 3600) or string.format("%d min", math.ceil(s.delai / 60))) or "—"
		local note = s.note and string.format("%.1f / 5 (%d avis)", s.note, s.notes) or "—"
		local vals = { s.nom, tostring(s.traites), delai, note }
		r.Paint = function(_, w, h)
			local x = 0
			for i, c in ipairs(cols) do UI.Texte(vals[i], "petit", x, h / 2, COL.Texte, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) x = x + w * c[2] end
		end
	end
	if #liste == 0 then texteBloc(pan, "Aucun ticket fermé pour l'instant.", COL.TexteSombre) end
end)

function T.ChangerVue(vue)
	local f = T.Fenetre
	if not IsValid(f) then return end
	T.Vue = vue
	T.Actuel = nil
	f.Rafraichir = nil
	f.Gauche:Clear()
	f.Detail:Clear()
	f.Liste = nil
	if vue ~= "stats" then
		VUES[vue](f)
		f.Liste = UI.StyliserScroll(vgui.Create("DScrollPanel", f.Gauche))
		f.Liste:Dock(FILL)
		if vue == "mes" and not T.EstStaffClient then nouveauTicket() end
	else
		VUES.stats(f)
	end
end

function T.OuvrirFenetre(staff, admin)
	if IsValid(T.Fenetre) then T.Fenetre:Close() return end
	T.EstStaffClient = staff
	local w, h = math.min(ScrW() - UI.S(40), UI.S(1180)), math.min(ScrH() - UI.S(40), UI.S(760))
	local f = UI.Fenetre("Tickets", w, h)
	T.Fenetre = f
	local p = f.Paint
	f.Paint = function(s, pw, ph)
		p(s, pw, ph)
		if T.EstStaffClient then
			UI.Texte(T.EnAttente .. " ticket(s) en attente", "texte_gras", pw - UI.S(56), UI.S(16), T.EnAttente > 0 and COL.Alerte or COL.TexteSombre, TEXT_ALIGN_RIGHT)
		end
	end

	local onglets = vgui.Create("DPanel", f)
	onglets:Dock(TOP) onglets:SetTall(UI.S(36)) onglets:DockMargin(0, 0, 0, UI.S(10)) onglets.Paint = nil
	local liste = { { "mes", "Mes tickets" } }
	if staff then
		liste = { { "file", "File" }, { "historique", "Historique" }, { "mes", "Mes tickets" } }
		if admin then liste[#liste + 1] = { "stats", "Statistiques" } end
	end
	for _, o in ipairs(liste) do
		local b = UI.Bouton(onglets, o[2], function() T.ChangerVue(o[1]) end)
		b:Dock(LEFT) b:SetWide(UI.S(170)) b:DockMargin(0, 0, UI.S(8), 0)
		b.PaintOver = function(_, bw, bh)
			if T.Vue == o[1] then UI.Rect(UI.S(4), bh - UI.S(4), bw - UI.S(8), UI.S(2), COL.Or) end
		end
	end

	f.Gauche = vgui.Create("DPanel", f)
	f.Gauche:Dock(LEFT) f.Gauche:SetWide(math.floor(w * 0.38)) f.Gauche:DockMargin(0, 0, UI.S(12), 0) f.Gauche.Paint = nil
	f.Detail = vgui.Create("DPanel", f)
	f.Detail:Dock(FILL)
	f.Detail:DockPadding(UI.S(12), UI.S(10), UI.S(12), UI.S(10))
	f.Detail.Paint = function(_, pw, ph) UI.Rect(0, 0, pw, ph, Color(0, 0, 0, 50)) end

	T.ChangerVue(staff and "file" or "mes")
end

net.Receive("origine_tickets_ouvrir", function()
	local staff, admin = net.ReadBool(), net.ReadBool()
	T.EnAttente = net.ReadUInt(16)
	T.OuvrirFenetre(staff, admin)
end)

net.Receive("origine_tickets_compteur", function()
	T.EnAttente = net.ReadUInt(16)
	local f = T.Fenetre
	if IsValid(f) and T.Vue == "file" and f.Rafraichir then f.Rafraichir() end
end)

net.Receive("origine_tickets_notif", function()
	local texte, son = net.ReadString(), net.ReadString()
	if son ~= "" then surface.PlaySound(son) end
	UI.Notifier(texte, "info")
	if IsValid(T.Fenetre) and T.Vue == "mes" then demande("mes") end
end)

-- F6 (réglable)
hook.Add("PlayerButtonDown", "origine_tickets", function(ply, touche)
	if touche ~= CT.Touche or ply ~= LocalPlayer() or not IsFirstTimePredicted() then return end
	if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() then return end
	if IsValid(T.Fenetre) then T.Fenetre:Close() return end
	net.Start("origine_tickets_f6") net.SendToServer()
end)
