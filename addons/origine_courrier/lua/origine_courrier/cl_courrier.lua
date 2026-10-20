--[[-----------------------------------------------------------------------
	Origine du monde — missives (client)

	Coffret (onglets Personnelles, Faction, Général), fenêtre d'écriture et
	de lecture en style parchemin. Les textes sont affichés en texte brut.
-------------------------------------------------------------------------]]

local MC = ORIGINE.Courrier
local CC = ORIGINE.ConfigCourrier
local UI = ORIGINE.UI
local COL = UI.C

UI.DefinirPolice("parchemin_titre", 26, 700, true)
UI.DefinirPolice("parchemin", 18, 500, false, true)

local ONGLETS = { { id = "perso", nom = "Personnelles" }, { id = "faction", nom = "Faction" }, { id = "general", nom = "Général" } }

local function date(t) return t and os.date("%d/%m/%Y %H:%M", t) or "" end

local function resumeDestinataires(m)
	local d = m.destinataires or {}
	if m.portee == "general" then return "Tout le serveur" end
	if m.portee == "perso" then return table.concat(d.persos or {}, ", ") end
	return table.concat(d.factions or {}, ", ")
end

-- Cadre « parchemin »
local function peindreParchemin(w, h)
	local p = CC.CouleurParchemin
	surface.SetDrawColor(p)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(p.r - 40, p.g - 40, p.b - 40, 255)
	surface.DrawOutlinedRect(0, 0, w, h, UI.S(3))
	surface.SetDrawColor(p.r - 70, p.g - 70, p.b - 70, 90)
	surface.DrawOutlinedRect(UI.S(8), UI.S(8), w - UI.S(16), h - UI.S(16), 1)
end

-- Texte brut qui défile (jamais interprété)
local function texteBrut(parent, texte, couleur, police)
	local rt = vgui.Create("RichText", parent)
	rt:SetVerticalScrollbarEnabled(true)
	rt.PerformLayout = function(s)
		s:SetFontInternal(UI.Police(police or "parchemin"))
		s:SetFGColor(couleur or CC.CouleurEncre)
	end
	rt:InsertColorChange((couleur or CC.CouleurEncre).r, (couleur or CC.CouleurEncre).g, (couleur or CC.CouleurEncre).b, 255)
	rt:AppendText(texte or "")
	return rt
end

---------------------------------------------------------------------------
-- Lecture en style parchemin (missive papier ou rangée dans l'inventaire)
---------------------------------------------------------------------------
function MC.FenetreLecture(d, ent)
	if IsValid(MC.Lecture) then MC.Lecture:Remove() end
	local w, h = UI.S(560), UI.S(620)
	local f = vgui.Create("DFrame")
	MC.Lecture = f
	f:SetSize(w, h) f:Center() f:SetTitle("") f:ShowCloseButton(false) f:MakePopup()
	f:DockPadding(UI.S(30), UI.S(24), UI.S(30), UI.S(20))
	f.Paint = function(_, pw, ph) peindreParchemin(pw, ph) end

	local haut = vgui.Create("DPanel", f)
	haut:Dock(TOP) haut:SetTall(UI.S(56))
	haut.Paint = function(_, pw)
		UI.Texte(d.objet or "", "parchemin_titre", pw / 2, 0, CC.CouleurEncre, TEXT_ALIGN_CENTER)
		UI.Texte(date(d.date), "petit", pw / 2, UI.S(32), Color(90, 70, 50), TEXT_ALIGN_CENTER)
	end

	local bas = vgui.Create("DPanel", f)
	bas:Dock(BOTTOM) bas:SetTall(UI.S(40)) bas.Paint = nil
	local fermer = UI.Bouton(bas, "Fermer", function() f:Remove() end)
	fermer:Dock(RIGHT) fermer:SetWide(UI.S(130))
	if IsValid(ent) then
		local function agir(action)
			net.Start("origine_courrier_papier_action")
				net.WriteEntity(ent)
				net.WriteString(action)
			net.SendToServer()
			f:Remove()
		end
		local ranger = UI.Bouton(bas, "Ranger", function() agir("ranger") end)
		ranger:Dock(LEFT) ranger:SetWide(UI.S(130))
		local detruire = UI.Bouton(bas, "Détruire", function()
			UI.Confirmer("Détruire", "Détruire définitivement cette missive ?", function() if IsValid(ent) then agir("detruire") end end, "Détruire")
		end)
		detruire:Dock(LEFT) detruire:SetWide(UI.S(130)) detruire:DockMargin(UI.S(8), 0, 0, 0)
	end

	local signature = vgui.Create("DPanel", f)
	signature:Dock(BOTTOM) signature:SetTall(UI.S(34)) signature.Paint = function(_, pw)
		UI.Texte("— " .. (d.auteur or "?"), "parchemin", pw, UI.S(6), CC.CouleurEncre, TEXT_ALIGN_RIGHT)
	end
	local t = texteBrut(f, d.texte)
	t:Dock(FILL)
end

net.Receive("origine_courrier_papier", function()
	local ent = net.ReadEntity()
	MC.FenetreLecture(ORIGINE.NetLireTable(), IsValid(ent) and ent or nil)
end)

---------------------------------------------------------------------------
-- Écriture
---------------------------------------------------------------------------
-- pre = { objet, portee, persos = {noms}, factions = {…} } (réponse)
function MC.FenetreEcriture(ent, infos, pre)
	pre = pre or {}
	if IsValid(MC.Ecriture) then MC.Ecriture:Remove() end
	local w, h = math.min(ScrW() - UI.S(40), UI.S(760)), math.min(ScrH() - UI.S(40), UI.S(720))
	local f = vgui.Create("DFrame")
	MC.Ecriture = f
	f:SetSize(w, h) f:Center() f:SetTitle("") f:ShowCloseButton(false) f:MakePopup()
	f:DockPadding(UI.S(28), UI.S(22), UI.S(28), UI.S(18))
	f.Paint = function(_, pw, ph)
		peindreParchemin(pw, ph)
		UI.Texte("Nouvelle missive", "parchemin_titre", pw / 2, UI.S(14), CC.CouleurEncre, TEXT_ALIGN_CENTER)
	end
	local espace = vgui.Create("DPanel", f)
	espace:Dock(TOP) espace:SetTall(UI.S(34)) espace.Paint = nil

	local function libelle(texte)
		local l = vgui.Create("DLabel", f)
		l:Dock(TOP) l:SetTall(UI.S(22))
		l:SetFont(UI.Police("petit_gras")) l:SetTextColor(CC.CouleurEncre) l:SetText(texte)
		return l
	end

	libelle("Objet")
	local objet = UI.Entree(f, "Objet de la missive")
	objet:Dock(TOP) objet:SetTall(UI.S(32)) objet:DockMargin(0, 0, 0, UI.S(8))
	objet:SetText(pre.objet or "")
	objet.AllowInput = function(s) return utf8.len(s:GetText() or "") >= CC.LongueurObjet end

	libelle("Destinataires")
	local choix = UI.Combo(f)
	choix:Dock(TOP) choix:SetTall(UI.S(32)) choix:DockMargin(0, 0, 0, UI.S(6))
	local zone = vgui.Create("DPanel", f)
	zone:Dock(TOP) zone:SetTall(UI.S(130)) zone:DockMargin(0, 0, 0, UI.S(8))
	zone.Paint = function(_, pw, ph) UI.Rect(0, 0, pw, ph, Color(0, 0, 0, 25)) end

	local selection = { persos = {}, factions = {} }
	for _, n in ipairs(pre.persos or {}) do selection.persos[n] = true end
	for _, n in ipairs(pre.factions or {}) do selection.factions[n] = true end
	local autres

	local function remplir(portee)
		zone:Clear()
		f.Portee = portee
		if portee == "perso" then
			autres = UI.Entree(zone, "Autres personnages (Prénom Nom, séparés par des virgules)")
			autres:Dock(BOTTOM) autres:SetTall(UI.S(30))
			local liste = UI.StyliserScroll(vgui.Create("DScrollPanel", zone))
			liste:Dock(FILL)
			local enLigne = {}
			for _, p in ipairs(player.GetAll()) do
				if p ~= LocalPlayer() and ORIGINE.Prenom(p) ~= "" and not ORIGINE.EnMenu(p) then enLigne[ORIGINE.NomComplet(p)] = true end
			end
			for n in pairs(selection.persos) do enLigne[n] = true end
			for n in SortedPairs(enLigne) do
				local c = liste:Add("DCheckBoxLabel")
				c:Dock(TOP) c:DockMargin(UI.S(6), UI.S(3), 0, 0)
				c:SetText(n) c:SetTextColor(CC.CouleurEncre) c:SetFont(UI.Police("petit"))
				c:SetValue(selection.persos[n] and 1 or 0)
				c.OnChange = function(_, v) selection.persos[n] = v or nil end
			end
		elseif portee == "factions" then
			local liste = UI.StyliserScroll(vgui.Create("DScrollPanel", zone))
			liste:Dock(FILL)
			for _, fa in ipairs(infos.factions or {}) do
				if fa ~= infos.faction then
					local c = liste:Add("DCheckBoxLabel")
					c:Dock(TOP) c:DockMargin(UI.S(6), UI.S(3), 0, 0)
					c:SetText(fa) c:SetTextColor(CC.CouleurEncre) c:SetFont(UI.Police("petit"))
					c:SetValue(selection.factions[fa] and 1 or 0)
					c.OnChange = function(_, v) selection.factions[fa] = v or nil end
				end
			end
		else
			local l = vgui.Create("DLabel", zone)
			l:Dock(FILL) l:SetContentAlignment(5) l:SetFont(UI.Police("texte")) l:SetTextColor(CC.CouleurEncre)
			l:SetText(portee == "faction" and ("Registre de votre faction : " .. (infos.faction or "aucune")) or "Onglet Général de tous les coffrets")
		end
	end

	for id, nom in pairs(MC.Portees) do
		if (id ~= "general" or infos.generale) and (id ~= "faction" or infos.faction) then
			choix:AddChoice(nom, id, id == (pre.portee or "perso"))
		end
	end
	choix.OnSelect = function(_, _, _, id) remplir(id) end
	remplir(pre.portee or "perso")

	local bas = vgui.Create("DPanel", f)
	bas:Dock(BOTTOM) bas:SetTall(UI.S(40)) bas.Paint = nil
	local compteur = vgui.Create("DPanel", f)
	compteur:Dock(BOTTOM) compteur:SetTall(UI.S(24))

	libelle("Texte")
	local texte = vgui.Create("DTextEntry", f)
	texte:Dock(FILL)
	texte:SetMultiline(true)
	texte:SetFont(UI.Police("parchemin"))
	texte:SetPaintBackground(false)
	texte.Paint = function(s, pw, ph)
		UI.Rect(0, 0, pw, ph, Color(255, 255, 255, 40))
		s:DrawTextEntryText(CC.CouleurEncre, Color(120, 90, 50), CC.CouleurEncre)
	end
	texte.AllowInput = function(s) return utf8.len(s:GetText() or "") >= CC.LongueurTexte end
	compteur.Paint = function(_, pw)
		local n = utf8.len(texte:GetText() or "") or 0
		UI.Texte("Signé : " .. ORIGINE.NomComplet(LocalPlayer()), "parchemin", 0, UI.S(2), CC.CouleurEncre)
		UI.Texte(n .. " / " .. CC.LongueurTexte, "petit", pw, UI.S(4), n >= CC.LongueurTexte and COL.Alerte or CC.CouleurEncre, TEXT_ALIGN_RIGHT)
	end

	local annuler = UI.Bouton(bas, "Annuler", function() f:Remove() end)
	annuler:Dock(LEFT) annuler:SetWide(UI.S(160))
	local envoyer = UI.Bouton(bas, "Envoyer", function()
		local d = { objet = objet:GetText(), texte = texte:GetText(), portee = f.Portee, persos = {}, factions = {} }
		for n in pairs(selection.persos) do d.persos[#d.persos + 1] = n end
		if IsValid(autres) then
			for _, n in ipairs(string.Explode(",", autres:GetText() or "")) do
				n = string.Trim(n)
				if n ~= "" then d.persos[#d.persos + 1] = n end
			end
		end
		for n in pairs(selection.factions) do d.factions[#d.factions + 1] = n end
		net.Start("origine_courrier_envoyer")
			net.WriteEntity(IsValid(ent) and ent or NULL)
			ORIGINE.NetEcrireTable(d)
		net.SendToServer()
		f:Remove()
	end)
	envoyer:Dock(RIGHT) envoyer:SetWide(UI.S(160))
end

net.Receive("origine_courrier_ecrire", function()
	local ent = net.ReadEntity()
	local infos = ORIGINE.NetLireTable()
	MC.FenetreEcriture(IsValid(ent) and ent or nil, infos, MC.ReponseEnAttente)
	MC.ReponseEnAttente = nil
end)

---------------------------------------------------------------------------
-- Coffret
---------------------------------------------------------------------------
local function demanderListe(onglet, page)
	net.Start("origine_courrier_liste")
		net.WriteString(onglet)
		net.WriteUInt(page or 0, 12)
	net.SendToServer()
end

local function afficherMissive(m)
	local pan = MC.Coffret and MC.Coffret.Lecture
	if not IsValid(pan) then return end
	pan:Clear()
	MC.Selection = m
	local haut = vgui.Create("DPanel", pan)
	haut:Dock(TOP) haut:SetTall(UI.S(78))
	haut.Paint = function(_, w)
		UI.Texte(m.objet or "", "sous_titre", 0, 0, COL.Or)
		UI.Texte("De : " .. (m.auteur or "?") .. "  ·  " .. date(m.date), "petit", 0, UI.S(30), COL.TexteSombre)
		UI.Texte("À : " .. resumeDestinataires(m), "petit", 0, UI.S(50), COL.TexteSombre)
		surface.SetDrawColor(COL.Or.r, COL.Or.g, COL.Or.b, 80)
		surface.DrawRect(0, UI.S(74), w, 1)
	end
	local bas = vgui.Create("DPanel", pan)
	bas:Dock(BOTTOM) bas:SetTall(UI.S(36)) bas.Paint = nil
	local function action(nom)
		net.Start("origine_courrier_action")
			net.WriteUInt(m.id, 32)
			net.WriteString(nom)
		net.SendToServer()
		pan:Clear()
	end
	local repondre = UI.Bouton(bas, "Répondre", function()
		-- Mêmes destinataires ; il faut un parchemin dans l'inventaire
		local pre = { objet = "Re : " .. (m.objet or ""), portee = m.portee }
		if m.portee == "perso" then
			pre.persos = { m.auteur }
			for _, n in ipairs(m.destinataires and m.destinataires.persos or {}) do
				if n ~= ORIGINE.NomComplet(LocalPlayer()) and n ~= m.auteur then pre.persos[#pre.persos + 1] = n end
			end
		elseif m.portee == "factions" then
			pre.factions = m.destinataires and m.destinataires.factions or {}
		end
		MC.ReponseEnAttente = pre
		net.Start("origine_courrier_ecrire_inventaire") net.SendToServer()
	end)
	repondre:Dock(LEFT) repondre:SetWide(UI.S(140))
	local papier = UI.Bouton(bas, "Sortir en papier", function() action("papier") end)
	papier:Dock(LEFT) papier:SetWide(UI.S(170)) papier:DockMargin(UI.S(6), 0, 0, 0)
	local suppr = UI.Bouton(bas, "Supprimer", function()
		UI.Confirmer("Supprimer", "Supprimer cette missive de votre coffret ?", function() action("supprimer") end, "Supprimer")
	end)
	suppr:Dock(RIGHT) suppr:SetWide(UI.S(140))
	local t = texteBrut(pan, m.texte, COL.Texte, "texte")
	t:Dock(FILL) t:DockMargin(0, UI.S(6), 0, UI.S(6))
end

local function afficherListe(d)
	local c = MC.Coffret
	if not (IsValid(c) and IsValid(c.Liste)) or d.onglet ~= MC.Onglet then return end
	c.Liste:Clear()
	c.Page = d.page
	if d.onglet == "faction" and not d.faction then
		local l = c.Liste:Add("DLabel")
		l:Dock(TOP) l:SetTall(UI.S(40)) l:SetFont(UI.Police("petit")) l:SetTextColor(COL.TexteSombre)
		l:SetText("  Vous n'appartenez à aucune faction.")
	elseif #d.missives == 0 then
		local l = c.Liste:Add("DLabel")
		l:Dock(TOP) l:SetTall(UI.S(40)) l:SetFont(UI.Police("petit")) l:SetTextColor(COL.TexteSombre)
		l:SetText("  Aucune missive.")
	end
	for _, m in ipairs(d.missives) do
		local b = c.Liste:Add("DButton")
		b:Dock(TOP) b:SetTall(UI.S(48)) b:SetText("") b:DockMargin(0, 0, 0, UI.S(3))
		b.Paint = function(s, w, h)
			UI.Rect(0, 0, w, h, (s:IsHovered() or (MC.Selection and MC.Selection.id == m.id)) and COL.Survol or COL.FondClair)
			if not m.lu then UI.Rect(0, 0, UI.S(4), h, COL.Or) end
			UI.Texte(UI.Couper(m.objet or "", m.lu and "texte" or "texte_gras", w - UI.S(20))[1] or "", m.lu and "texte" or "texte_gras", UI.S(10), UI.S(4), COL.Texte)
			UI.Texte((m.auteur or "?") .. "  ·  " .. date(m.date), "petit", UI.S(10), UI.S(26), COL.TexteSombre)
		end
		b.DoClick = function()
			m.lu = true
			net.Start("origine_courrier_lire")
				net.WriteUInt(m.id, 32)
			net.SendToServer()
		end
	end
	c.Precedent:SetEnabled(d.page > 0)
	c.Suivant:SetEnabled(#d.missives >= (d.parPage or CC.ParPage))
end

net.Receive("origine_courrier_liste", function() afficherListe(ORIGINE.NetLireTable()) end)
net.Receive("origine_courrier_texte", function() afficherMissive(ORIGINE.NetLireTable()) end)

function MC.OuvrirCoffret(aParchemin)
	if IsValid(MC.Coffret) then MC.Coffret:Close() end
	local w, h = math.min(ScrW() - UI.S(40), UI.S(1060)), math.min(ScrH() - UI.S(40), UI.S(660))
	local f = UI.Fenetre("Coffret de missives", w, h)
	MC.Coffret = f
	MC.Onglet = MC.Onglet or "perso"
	MC.Selection = nil

	local onglets = vgui.Create("DPanel", f)
	onglets:Dock(TOP) onglets:SetTall(UI.S(36)) onglets:DockMargin(0, 0, 0, UI.S(10)) onglets.Paint = nil
	for _, o in ipairs(ONGLETS) do
		local b = UI.Bouton(onglets, o.nom, function()
			MC.Onglet = o.id
			f.Lecture:Clear()
			demanderListe(o.id, 0)
		end)
		b:Dock(LEFT) b:SetWide(UI.S(170)) b:DockMargin(0, 0, UI.S(8), 0)
		b.PaintOver = function(_, bw, bh)
			if MC.Onglet == o.id then UI.Rect(UI.S(4), bh - UI.S(4), bw - UI.S(8), UI.S(2), COL.Or) end
		end
	end
	local ecrire = UI.Bouton(onglets, "Écrire une missive", function()
		MC.ReponseEnAttente = nil
		net.Start("origine_courrier_ecrire_inventaire") net.SendToServer()
	end)
	ecrire:Dock(RIGHT) ecrire:SetWide(UI.S(220))
	ecrire:SetEnabled(aParchemin)
	if not aParchemin then ecrire.Texte = "Écrire (parchemin requis)" end

	local gauche = vgui.Create("DPanel", f)
	gauche:Dock(LEFT) gauche:SetWide(math.floor(w * 0.38)) gauche:DockMargin(0, 0, UI.S(12), 0) gauche.Paint = nil
	local pages = vgui.Create("DPanel", gauche)
	pages:Dock(BOTTOM) pages:SetTall(UI.S(32)) pages:DockMargin(0, UI.S(6), 0, 0) pages.Paint = nil
	f.Precedent = UI.Bouton(pages, "‹ Précédentes", function() demanderListe(MC.Onglet, math.max(0, (f.Page or 0) - 1)) end)
	f.Precedent:Dock(LEFT) f.Precedent:SetWide(UI.S(150))
	f.Suivant = UI.Bouton(pages, "Suivantes ›", function() demanderListe(MC.Onglet, (f.Page or 0) + 1) end)
	f.Suivant:Dock(RIGHT) f.Suivant:SetWide(UI.S(150))
	f.Liste = UI.StyliserScroll(vgui.Create("DScrollPanel", gauche))
	f.Liste:Dock(FILL)

	f.Lecture = vgui.Create("DPanel", f)
	f.Lecture:Dock(FILL)
	f.Lecture.Paint = function(_, pw, ph) UI.Rect(0, 0, pw, ph, Color(0, 0, 0, 50)) end
	f.Lecture:DockPadding(UI.S(12), UI.S(10), UI.S(12), UI.S(10))

	demanderListe(MC.Onglet, 0)
end

net.Receive("origine_courrier_ouvrir", function() MC.OuvrirCoffret(net.ReadBool()) end)

-- Réception : bruit de parchemin et notification
net.Receive("origine_courrier_nouvelle", function()
	local onglet, objet, auteur = net.ReadString(), net.ReadString(), net.ReadString()
	surface.PlaySound(CC.SonReception)
	local noms = { perso = "personnelle", faction = "de faction", general = "générale" }
	if auteur == "" then
		UI.Notifier("Coffret : " .. objet .. " (!missives)", "info")
	else
		UI.Notifier("Missive " .. (noms[onglet] or "") .. " de " .. auteur .. " : « " .. objet .. " »", "info")
	end
	if IsValid(MC.Coffret) and MC.Onglet == onglet then demanderListe(onglet, 0) end
end)

-- Touche du coffret (aucune par défaut)
hook.Add("PlayerButtonDown", "origine_courrier", function(ply, touche)
	if not CC.Touche or touche ~= CC.Touche or ply ~= LocalPlayer() or not IsFirstTimePredicted() then return end
	if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() then return end
	net.Start("origine_courrier_coffret") net.SendToServer()
end)

---------------------------------------------------------------------------
-- Staff : onglet « Missives » de !origine (permission origine_courrier_admin)
---------------------------------------------------------------------------
local S = ORIGINE.Staff
local admin = {}

local function adminEnvoyer(action, a)
	net.Start("origine_courrier_admin")
		net.WriteString(action)
		ORIGINE.NetEcrireTable(a or {})
	net.SendToServer()
end

local function adminLire(d)
	if not IsValid(admin.Lecture) then return end
	admin.Lecture:Clear()
	local haut = vgui.Create("DPanel", admin.Lecture)
	haut:Dock(TOP) haut:SetTall(UI.S(96))
	haut.Paint = function()
		UI.Texte(d.objet or "", "sous_titre", 0, 0, d.supprimee and COL.Alerte or COL.Or)
		UI.Texte("De : " .. (d.auteur or "?") .. " (" .. (d.sid or "?") .. ")  ·  " .. date(d.date), "petit", 0, UI.S(30), COL.TexteSombre)
		UI.Texte("À : " .. resumeDestinataires(d), "petit", 0, UI.S(50), COL.TexteSombre)
		if d.supprimee then UI.Texte("Supprimée par le staff", "petit_gras", 0, UI.S(70), COL.Alerte) end
	end
	if not d.supprimee then
		local b = UI.Bouton(admin.Lecture, "Supprimer pour tout le monde", function()
			UI.Demander("Supprimer la missive", { { libelle = "Raison" } }, function(v)
				adminEnvoyer("supprimer", { id = d.id, raison = v[1] })
				timer.Simple(0.3, function() adminEnvoyer("liste", { texte = admin.Texte or "", page = admin.Page or 0 }) end)
				admin.Lecture:Clear()
			end, "Supprimer")
		end)
		b:Dock(BOTTOM) b:SetTall(UI.S(34))
	end
	local t = texteBrut(admin.Lecture, d.texte, COL.Texte, "texte")
	t:Dock(FILL)
end

net.Receive("origine_courrier_admin_texte", function() adminLire(ORIGINE.NetLireTable()) end)
net.Receive("origine_courrier_admin_liste", function()
	local d = ORIGINE.NetLireTable()
	if not IsValid(admin.Liste) then return end
	admin.Liste:Clear()
	admin.Page = d.page
	for _, m in ipairs(d.missives or {}) do
		local b = admin.Liste:Add("DButton")
		b:Dock(TOP) b:SetTall(UI.S(46)) b:SetText("") b:DockMargin(0, 0, 0, UI.S(3))
		b.Paint = function(s, w, h)
			UI.Rect(0, 0, w, h, s:IsHovered() and COL.Survol or COL.FondClair)
			UI.Texte(UI.Couper(m.objet or "", "texte_gras", w - UI.S(20))[1] or "", "texte_gras", UI.S(8), UI.S(4), m.supprimee and COL.Alerte or COL.Texte)
			UI.Texte((m.auteur or "?") .. "  ·  " .. (MC.Portees[m.portee] or m.portee) .. "  ·  " .. date(m.date), "petit", UI.S(8), UI.S(25), COL.TexteSombre)
		end
		b.DoClick = function() adminEnvoyer("lire", { id = m.id }) end
	end
end)

if S and S.AjouterOnglet then
	S.AjouterOnglet("Missives", function(corps)
		local gauche = vgui.Create("DPanel", corps)
		gauche:Dock(LEFT) gauche:SetWide(math.floor(corps:GetWide() * 0.4)) gauche:DockMargin(0, 0, UI.S(10), 0)
		if gauche:GetWide() < UI.S(200) then gauche:SetWide(UI.S(420)) end
		gauche.Paint = nil
		local e = UI.Entree(gauche, "Auteur, objet, texte ou SteamID64")
		e:Dock(TOP) e:SetTall(UI.S(32))
		local function chercher(page)
			admin.Texte = e:GetText()
			adminEnvoyer("liste", { texte = admin.Texte, page = page or 0 })
		end
		e.OnEnter = function() chercher(0) end
		local pages = vgui.Create("DPanel", gauche)
		pages:Dock(BOTTOM) pages:SetTall(UI.S(32)) pages:DockMargin(0, UI.S(6), 0, 0) pages.Paint = nil
		local prec = UI.Bouton(pages, "‹", function() chercher(math.max(0, (admin.Page or 0) - 1)) end)
		prec:Dock(LEFT) prec:SetWide(UI.S(60))
		local suiv = UI.Bouton(pages, "›", function() chercher((admin.Page or 0) + 1) end)
		suiv:Dock(RIGHT) suiv:SetWide(UI.S(60))
		local b = UI.Bouton(gauche, "Rechercher", function() chercher(0) end)
		b:Dock(TOP) b:SetTall(UI.S(32)) b:DockMargin(0, UI.S(6), 0, UI.S(6))
		admin.Liste = UI.StyliserScroll(vgui.Create("DScrollPanel", gauche))
		admin.Liste:Dock(FILL)
		admin.Lecture = vgui.Create("DPanel", corps)
		admin.Lecture:Dock(FILL)
		admin.Lecture:DockPadding(UI.S(10), UI.S(10), UI.S(10), UI.S(10))
		admin.Lecture.Paint = function(_, pw, ph) UI.Rect(0, 0, pw, ph, Color(0, 0, 0, 50)) end
		chercher(0)
	end, function() return ORIGINE.APermission(LocalPlayer(), "origine_courrier_admin") end)
end
