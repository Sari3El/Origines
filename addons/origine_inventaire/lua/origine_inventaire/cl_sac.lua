--[[-----------------------------------------------------------------------
	Origine du monde — fenêtre du sac de mort (client)
	Le contenu se met à jour pour tous ceux qui l'ont ouvert.
-------------------------------------------------------------------------]]

local I = ORIGINE.Inv
local UI = ORIGINE.UI
local COL = UI.C

local function fermerFenetre(prevenir)
	local f = I.FenetreSac
	if not IsValid(f) then return end
	f.PasDePrevenir = not prevenir
	f:Close()
end

local function ouvrir(sac, contenu)
	if IsValid(I.FenetreSac) and I.FenetreSac.Sac ~= sac then fermerFenetre(true) end
	local f = I.FenetreSac
	if not IsValid(f) then
		local largeur = 6 * UI.S(78) + UI.S(44)
		local nom = sac:GetNW2String("origine_sac_nom", "")
		f = UI.Fenetre(nom ~= "" and ("Sac de " .. nom) or "Sac", largeur, UI.S(480))
		f.Sac = sac
		I.FenetreSac = f
		f.OnClose = function(s)
			if s.PasDePrevenir then return end
			net.Start("origine_sac_fermer")
				net.WriteEntity(s.Sac)
			net.SendToServer()
		end

		local bas = vgui.Create("DPanel", f)
		bas:Dock(BOTTOM)
		bas:SetTall(UI.S(42))
		bas:DockMargin(0, UI.S(8), 0, 0)
		bas.Paint = function(_, w, h)
			UI.Texte("Clic droit sur un objet pour les actions", "petit", 0, h / 2, COL.TexteSombre, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		local tout = UI.Bouton(bas, "Tout transférer", function()
			net.Start("origine_sac_tout")
				net.WriteEntity(sac)
			net.SendToServer()
		end)
		tout:Dock(RIGHT)
		tout:SetWide(UI.S(200))

		f.Contenu = vgui.Create("DPanel", f)
		f.Contenu:Dock(FILL)
		f.Contenu.Paint = nil
	end

	f.Contenu:Clear()
	I.CreerGrille(f.Contenu, contenu, function(index, objet)
		I.MenuObjet(objet, function(action)
			net.Start("origine_sac_action")
				net.WriteEntity(sac)
				net.WriteString(action)
				net.WriteUInt(index, 8)
			net.SendToServer()
		end)
	end)
end

net.Receive("origine_sac", function()
	local sac = net.ReadEntity()
	local contenu = net.ReadTable()
	if IsValid(sac) then ouvrir(sac, contenu) end
end)

net.Receive("origine_sac_ferme", function()
	local sac = net.ReadEntity()
	local f = I.FenetreSac
	if IsValid(f) and (f.Sac == sac or not IsValid(f.Sac)) then fermerFenetre(false) end
end)
