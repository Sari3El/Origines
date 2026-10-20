--[[-----------------------------------------------------------------------
	Origine du monde — fenêtre d'inventaire (client)
	Clic droit sur une icône : Équiper (armes), Déposer, Détruire.
-------------------------------------------------------------------------]]

local I = ORIGINE.Inv
local UI = ORIGINE.UI
local COL = UI.C

I.Client = I.Client or { cases = {}, capacite = 20 }

---------------------------------------------------------------------------
-- Grille d'icônes (partagée avec la fenêtre du sac)
---------------------------------------------------------------------------
-- surClicDroit(index, objet) ; nbCases = cases vides à dessiner (optionnel)
function I.CreerGrille(parent, cases, surClicDroit, nbCases)
	local scroll = UI.StyliserScroll(vgui.Create("DScrollPanel", parent))
	scroll:Dock(FILL)
	local grille = scroll:Add("DIconLayout")
	grille:Dock(FILL)
	grille:SetSpaceX(UI.S(6))
	grille:SetSpaceY(UI.S(6))
	local taille = UI.S(72)

	local total = math.max(#cases, nbCases or 0)
	for index = 1, total do
		local objet = cases[index]
		local case = grille:Add("DPanel")
		case:SetSize(taille, taille)
		case.Paint = function(s, w, h)
			UI.Rect(0, 0, w, h, COL.FondClair)
			UI.Contour(0, 0, w, h, s:IsChildHovered() and COL.Or or COL.Bordure, UI.S(2))
		end
		if objet then
			local icone = vgui.Create("SpawnIcon", case)
			icone:SetModel(objet.modele or "models/props_junk/cardboard_box004a.mdl")
			icone:Dock(FILL)
			icone:DockMargin(UI.S(3), UI.S(3), UI.S(3), UI.S(3))
			icone:SetTooltip(I.NomObjet(objet))
			icone.PaintOver = function(_, w, h)
				if (objet.n or 1) > 1 then
					UI.TexteOmbre("×" .. objet.n, "petit_gras", w - UI.S(4), h - UI.S(2), COL.Texte, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
				end
			end
			icone.DoClick = function() surClicDroit(index, objet) end
			icone.DoRightClick = function() surClicDroit(index, objet) end
			icone.OpenMenu = function() end
		end
	end
	return scroll
end

-- Menu contextuel commun : Équiper / Déposer / Détruire
function I.MenuObjet(objet, envoyerAction)
	local m = DermaMenu()
	if objet.arme then
		local equiper = m:AddOption("Équiper", function() envoyerAction("equiper") end)
		equiper:SetIcon("icon16/gun.png")
		if LocalPlayer():HasWeapon(objet.arme) then
			equiper:SetEnabled(false)
			equiper:SetText("Équiper (déjà en main)")
		end
	end
	for id, a in SortedPairs(I.ActionsObjet[objet.classe] or {}) do
		m:AddOption(a.nom, function() envoyerAction(id) end):SetIcon(a.icone or "icon16/star.png")
	end
	m:AddOption("Déposer", function() envoyerAction("deposer") end):SetIcon("icon16/arrow_down.png")
	m:AddSpacer()
	m:AddOption("Détruire", function()
		UI.Confirmer("Détruire", "Détruire définitivement « " .. I.NomObjet(objet) .. " » ?", function()
			envoyerAction("detruire")
		end, "Détruire")
	end):SetIcon("icon16/cross.png")
	m:Open()
end

---------------------------------------------------------------------------
-- Fenêtre de la sacoche
---------------------------------------------------------------------------
function I.OuvrirFenetre()
	if IsValid(I.Fenetre) then I.Fenetre:Close() return end
	local colonnes = 6
	local largeur = colonnes * UI.S(78) + UI.S(44)
	local f = UI.Fenetre("Sacoche", largeur, UI.S(520))
	I.Fenetre = f

	local bas = vgui.Create("DPanel", f)
	bas:Dock(BOTTOM)
	bas:SetTall(UI.S(26))
	bas.Paint = function(_, w, h)
		local c = I.Client
		local plein = #c.cases >= c.capacite
		UI.Texte(#c.cases .. " / " .. c.capacite .. " cases", "petit_gras", w, h / 2,
			plein and COL.Alerte or COL.TexteSombre, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		UI.Texte("Clic droit sur un objet pour les actions", "petit", 0, h / 2, COL.TexteSombre, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	f.Contenu = vgui.Create("DPanel", f)
	f.Contenu:Dock(FILL)
	f.Contenu.Paint = nil
	I.RafraichirFenetre()
end

function I.RafraichirFenetre()
	local f = I.Fenetre
	if not IsValid(f) then return end
	f.Contenu:Clear()
	I.CreerGrille(f.Contenu, I.Client.cases, function(index, objet)
		I.MenuObjet(objet, function(action)
			net.Start("origine_inv_action")
				net.WriteString(action)
				net.WriteUInt(index, 8)
			net.SendToServer()
		end)
	end, I.Client.capacite)
end

net.Receive("origine_inv", function()
	I.Client.cases = net.ReadTable()
	I.Client.capacite = net.ReadUInt(8)
	I.RafraichirFenetre()
end)

net.Receive("origine_inv_ouvrir", function()
	I.OuvrirFenetre()
end)
