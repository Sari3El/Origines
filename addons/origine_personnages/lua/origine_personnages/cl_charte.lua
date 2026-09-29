--[[-----------------------------------------------------------------------
	Origine du monde — charte graphique commune (client)

	Style médiéval simple partagé par le HUD, le menu personnage,
	l'inventaire, le sac de mort et le menu staff.
	Polices et matériaux créés une seule fois (jamais pendant le dessin).
-------------------------------------------------------------------------]]

ORIGINE.UI = ORIGINE.UI or {}
local UI = ORIGINE.UI
local CH = ORIGINE.Config.Charte
UI.C = CH.Couleurs
local COL = UI.C

---------------------------------------------------------------------------
-- Échelle : 720p -> 4K
---------------------------------------------------------------------------
function UI.Echelle()
	return math.Clamp(ScrH() / 1080, 0.62, 2.2)
end

function UI.S(v)
	return math.max(1, math.Round(v * UI.Echelle()))
end

---------------------------------------------------------------------------
-- Polices (recréées seulement quand la résolution change)
---------------------------------------------------------------------------
UI.Polices = UI.Polices or {}

function UI.CreerPolice(id)
	local d = UI.Polices[id]
	surface.CreateFont("origine_" .. id, {
		font = d.titre and CH.PoliceTitre or CH.PoliceTexte,
		size = UI.S(d.taille),
		weight = d.poids or 500,
		italic = d.italique or false,
		antialias = true,
		extended = true,
	})
end

function UI.DefinirPolice(id, taille, poids, titre, italique)
	UI.Polices[id] = { taille = taille, poids = poids, titre = titre, italique = italique }
	UI.CreerPolice(id)
end

function UI.Police(id) return "origine_" .. id end

UI.DefinirPolice("geant", 56, 700, true)
UI.DefinirPolice("titre", 34, 700, true)
UI.DefinirPolice("sous_titre", 24, 600, true)
UI.DefinirPolice("texte", 18, 500)
UI.DefinirPolice("texte_gras", 18, 700)
UI.DefinirPolice("bouton", 19, 600, true)
UI.DefinirPolice("petit", 15, 500)
UI.DefinirPolice("petit_gras", 15, 700)
UI.DefinirPolice("italique", 16, 400, false, true)

hook.Add("OnScreenSizeChanged", "origine_polices", function()
	for id in pairs(UI.Polices) do UI.CreerPolice(id) end
	hook.Run("origine_EchelleChangee")
end)

---------------------------------------------------------------------------
-- Matériaux (créés une fois)
---------------------------------------------------------------------------
UI.Mat = {
	degradeHaut = Material("gui/gradient_up"),
	degradeBas = Material("gui/gradient_down"),
	degradeG = Material("vgui/gradient-l"),
	degradeD = Material("vgui/gradient-r"),
}
if CH.FondMenu and CH.FondMenu ~= "" then UI.Mat.fondMenu = Material(CH.FondMenu, "smooth") end

---------------------------------------------------------------------------
-- Dessin
---------------------------------------------------------------------------
function UI.Rect(x, y, w, h, col)
	surface.SetDrawColor(col)
	surface.DrawRect(x, y, w, h)
end

function UI.Contour(x, y, w, h, col, epaisseur)
	surface.SetDrawColor(col)
	surface.DrawOutlinedRect(x, y, w, h, epaisseur or 1)
end

-- Cadre médiéval : fond, bordure, liseré doré, coins renforcés
function UI.Cadre(x, y, w, h, fond, surligne)
	UI.Rect(x, y, w, h, fond or COL.Fond)
	local e = UI.S(2)
	UI.Contour(x, y, w, h, surligne and COL.Or or COL.Bordure, e)
	local m = UI.S(4)
	surface.SetDrawColor(COL.Or.r, COL.Or.g, COL.Or.b, surligne and 160 or 70)
	surface.DrawOutlinedRect(x + m, y + m, w - m * 2, h - m * 2, 1)
	local c, t = UI.S(10), UI.S(3)
	surface.SetDrawColor(COL.Or)
	surface.DrawRect(x, y, c, t) surface.DrawRect(x, y, t, c)
	surface.DrawRect(x + w - c, y, c, t) surface.DrawRect(x + w - t, y, t, c)
	surface.DrawRect(x, y + h - t, c, t) surface.DrawRect(x, y + h - c, t, c)
	surface.DrawRect(x + w - c, y + h - t, c, t) surface.DrawRect(x + w - t, y + h - c, t, c)
end

-- Polygones (à créer une fois et garder en cache, puis surface.DrawPoly)
function UI.PolyCercle(cx, cy, r, segments)
	local poly = {}
	segments = segments or 24
	for i = 0, segments - 1 do
		local a = i / segments * math.pi * 2
		poly[#poly + 1] = { x = cx + math.cos(a) * r, y = cy + math.sin(a) * r }
	end
	return poly
end

function UI.PolyLosange(cx, cy, r)
	return { { x = cx, y = cy - r }, { x = cx + r, y = cy }, { x = cx, y = cy + r }, { x = cx - r, y = cy } }
end

function UI.DessinerPoly(poly, col)
	draw.NoTexture()
	surface.SetDrawColor(col)
	surface.DrawPoly(poly)
end

-- Séparateur orné : ligne dorée avec un losange au centre
function UI.SeparateurOrne(x, y, w, poly)
	surface.SetDrawColor(COL.Or.r, COL.Or.g, COL.Or.b, 110)
	surface.DrawRect(x, y, w, 1)
	if poly then UI.DessinerPoly(poly, COL.Or) end
end

-- Séparateur doré horizontal
function UI.Separateur(x, y, w)
	surface.SetDrawColor(COL.Or.r, COL.Or.g, COL.Or.b, 120)
	surface.DrawRect(x, y, w, 1)
end

-- Fond fixe du menu personnage
function UI.FondMenu(w, h)
	if UI.Mat.fondMenu and not UI.Mat.fondMenu:IsError() then
		surface.SetDrawColor(255, 255, 255)
		surface.SetMaterial(UI.Mat.fondMenu)
		surface.DrawTexturedRect(0, 0, w, h)
	else
		UI.Rect(0, 0, w, h, Color(22, 17, 13))
		surface.SetMaterial(UI.Mat.degradeBas)
		surface.SetDrawColor(58, 42, 28, 255)
		surface.DrawTexturedRect(0, 0, w, h * 0.6)
		surface.SetMaterial(UI.Mat.degradeHaut)
		surface.SetDrawColor(10, 8, 6, 255)
		surface.DrawTexturedRect(0, h * 0.5, w, h * 0.5)
	end
	-- Vignette
	surface.SetDrawColor(0, 0, 0, 200)
	surface.SetMaterial(UI.Mat.degradeG)
	surface.DrawTexturedRect(0, 0, w * 0.25, h)
	surface.SetMaterial(UI.Mat.degradeD)
	surface.DrawTexturedRect(w * 0.75, 0, w * 0.25, h)
end

function UI.Texte(texte, police, x, y, col, ax, ay)
	return draw.SimpleText(texte, UI.Police(police), x, y, col or COL.Texte, ax or TEXT_ALIGN_LEFT, ay or TEXT_ALIGN_TOP)
end

function UI.TexteOmbre(texte, police, x, y, col, ax, ay)
	draw.SimpleText(texte, UI.Police(police), x + 1, y + 1, Color(0, 0, 0, 200), ax or TEXT_ALIGN_LEFT, ay or TEXT_ALIGN_TOP)
	return draw.SimpleText(texte, UI.Police(police), x, y, col or COL.Texte, ax or TEXT_ALIGN_LEFT, ay or TEXT_ALIGN_TOP)
end

-- Coupe un texte en lignes qui tiennent dans une largeur
function UI.Couper(texte, police, largeur)
	surface.SetFont(UI.Police(police))
	local lignes, ligne = {}, ""
	for mot in string.gmatch(texte, "%S+") do
		local essai = ligne == "" and mot or (ligne .. " " .. mot)
		if surface.GetTextSize(essai) > largeur and ligne ~= "" then
			lignes[#lignes + 1] = ligne
			ligne = mot
		else
			ligne = essai
		end
	end
	if ligne ~= "" then lignes[#lignes + 1] = ligne end
	return lignes
end

---------------------------------------------------------------------------
-- Composants VGUI
---------------------------------------------------------------------------
function UI.Bouton(parent, texte, fn)
	local b = vgui.Create("DButton", parent)
	b:SetText("")
	b.Texte = texte
	b.DoClick = function(s)
		if not s:IsEnabled() then return end
		surface.PlaySound("ui/buttonclick.wav")
		if fn then fn(s) end
	end
	b.Paint = function(s, w, h)
		local fond = COL.FondClair
		if not s:IsEnabled() then fond = COL.Grise
		elseif s:IsHovered() then fond = COL.Survol end
		UI.Rect(0, 0, w, h, fond)
		UI.Contour(0, 0, w, h, s:IsEnabled() and COL.Bordure or COL.Grise, UI.S(2))
		if s:IsHovered() and s:IsEnabled() then UI.Contour(UI.S(3), UI.S(3), w - UI.S(6), h - UI.S(6), COL.Or, 1) end
		UI.Texte(s.Texte, "bouton", w / 2, h / 2, s:IsEnabled() and COL.Texte or COL.TexteSombre, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	return b
end

function UI.Entree(parent, indication)
	local e = vgui.Create("DTextEntry", parent)
	e:SetFont(UI.Police("texte"))
	e:SetPlaceholderText(indication or "")
	e:SetPaintBackground(false)
	e.Paint = function(s, w, h)
		UI.Rect(0, 0, w, h, Color(16, 12, 9, 230))
		UI.Contour(0, 0, w, h, s:HasFocus() and COL.Or or COL.Bordure, UI.S(2))
		if s:GetText() == "" and not s:HasFocus() then
			UI.Texte(s:GetPlaceholderText(), "texte", UI.S(8), h / 2, COL.TexteSombre, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		s:DrawTextEntryText(COL.Texte, COL.Or, COL.Texte)
	end
	e:SetTextInset(UI.S(8), 0)
	return e
end

function UI.StyliserScroll(scroll)
	local barre = scroll:GetVBar()
	barre:SetWide(UI.S(8))
	barre:SetHideButtons(true)
	barre.Paint = function(_, w, h) UI.Rect(0, 0, w, h, Color(0, 0, 0, 80)) end
	barre.btnGrip.Paint = function(_, w, h) UI.Rect(0, 0, w, h, COL.Bordure) end
	return scroll
end

function UI.Combo(parent)
	local c = vgui.Create("DComboBox", parent)
	c:SetFont(UI.Police("texte"))
	c:SetTextColor(COL.Texte)
	c.Paint = function(s, w, h)
		UI.Rect(0, 0, w, h, Color(16, 12, 9, 230))
		UI.Contour(0, 0, w, h, s:IsMenuOpen() and COL.Or or COL.Bordure, UI.S(2))
	end
	return c
end

-- Fenêtre standard (inventaire, sac, staff…)
function UI.Fenetre(titre, w, h)
	local f = vgui.Create("DFrame")
	f:SetSize(w, h)
	f:Center()
	f:SetTitle("")
	f:ShowCloseButton(false)
	f:SetDraggable(true)
	f:MakePopup()
	f.Titre = titre
	f.Paint = function(s, pw, ph)
		UI.Cadre(0, 0, pw, ph, COL.Fond)
		UI.Texte(s.Titre, "sous_titre", UI.S(16), UI.S(12), COL.Or)
		UI.Separateur(UI.S(12), UI.S(46), pw - UI.S(24))
	end
	local fermer = vgui.Create("DButton", f)
	fermer:SetText("")
	fermer:SetSize(UI.S(28), UI.S(28))
	fermer:SetPos(w - UI.S(40), UI.S(12))
	fermer.Paint = function(s, bw, bh)
		UI.Texte("×", "sous_titre", bw / 2, bh / 2, s:IsHovered() and COL.Alerte or COL.TexteSombre, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	fermer.DoClick = function() f:Close() end
	f.BoutonFermer = fermer
	f:DockPadding(UI.S(14), UI.S(56), UI.S(14), UI.S(14))
	return f
end

-- Petite boîte de confirmation
function UI.Confirmer(titre, texte, fn, texteOui)
	local f = UI.Fenetre(titre, UI.S(460), UI.S(220))
	f:SetDrawOnTop(true)
	local lignes = UI.Couper(texte, "texte", UI.S(420))
	local corps = vgui.Create("DPanel", f)
	corps:Dock(FILL)
	corps.Paint = function(_, w)
		for i, l in ipairs(lignes) do
			UI.Texte(l, "texte", w / 2, (i - 1) * UI.S(22), COL.Texte, TEXT_ALIGN_CENTER)
		end
	end
	local bas = vgui.Create("DPanel", f)
	bas:Dock(BOTTOM)
	bas:SetTall(UI.S(40))
	bas.Paint = nil
	local non = UI.Bouton(bas, "Annuler", function() f:Close() end)
	non:Dock(LEFT) non:SetWide(UI.S(200))
	local oui = UI.Bouton(bas, texteOui or "Confirmer", function() f:Close() fn() end)
	oui:Dock(RIGHT) oui:SetWide(UI.S(200))
	return f
end

-- Demande de texte (une ou plusieurs lignes) ; fn(valeurs)
function UI.Demander(titre, champs, fn, texteOui)
	local f = UI.Fenetre(titre, UI.S(480), UI.S(120 + #champs * 70))
	f:SetDrawOnTop(true)
	local entrees = {}
	for i, ch in ipairs(champs) do
		local l = vgui.Create("DLabel", f)
		l:Dock(TOP)
		l:SetFont(UI.Police("petit_gras"))
		l:SetTextColor(COL.TexteSombre)
		l:SetText(ch.libelle or "")
		l:SetTall(UI.S(20))
		local e = UI.Entree(f, ch.indication)
		e:Dock(TOP)
		e:SetTall(UI.S(34))
		e:DockMargin(0, 0, 0, UI.S(12))
		if ch.valeur then e:SetText(ch.valeur) end
		if ch.numerique then e:SetNumeric(true) end
		entrees[i] = e
	end
	local oui = UI.Bouton(f, texteOui or "Valider", function()
		local valeurs = {}
		for i, e in ipairs(entrees) do valeurs[i] = e:GetText() end
		f:Close()
		fn(valeurs)
	end)
	oui:Dock(BOTTOM)
	oui:SetTall(UI.S(38))
	if entrees[1] then entrees[1]:RequestFocus() end
	return f
end

---------------------------------------------------------------------------
-- Notifications (au-dessus de tout, même des menus)
---------------------------------------------------------------------------
UI.Notifs = UI.Notifs or {}

function UI.Notifier(texte, typ)
	local col = COL.Texte
	if typ == "erreur" then col = COL.Alerte elseif typ == "succes" then col = COL.Succes end
	local p = vgui.Create("DPanel")
	p:SetDrawOnTop(true)
	p:SetMouseInputEnabled(false)
	surface.SetFont(UI.Police("texte_gras"))
	local tw = surface.GetTextSize(texte)
	p:SetSize(tw + UI.S(40), UI.S(40))
	p.Texte, p.Couleur, p.Fin = texte, col, CurTime() + 5
	p.Paint = function(s, w, h)
		UI.Cadre(0, 0, w, h, COL.Fond)
		UI.Texte(s.Texte, "texte_gras", w / 2, h / 2, s.Couleur, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	p.Think = function(s)
		if CurTime() > s.Fin then s:Remove() end
	end
	table.insert(UI.Notifs, 1, p)
	for i = #UI.Notifs, 1, -1 do
		if not IsValid(UI.Notifs[i]) then table.remove(UI.Notifs, i) end
	end
	for i, n in ipairs(UI.Notifs) do
		n:SetPos(ScrW() / 2 - n:GetWide() / 2, UI.S(24) + (i - 1) * UI.S(46))
	end
	if typ == "erreur" then surface.PlaySound("buttons/button10.wav") end
end
