--[[-----------------------------------------------------------------------
	Origine du monde — indication de la nourriture (client)
	Discret : le nom en petit au-dessus de l'objet visé, la touche à
	maintenir, et une fine barre pendant qu'on mange.
-------------------------------------------------------------------------]]

local I = ORIGINE.Inv
local UI = ORIGINE.UI
local COL = UI.C
local CI = ORIGINE.ConfigInv

UI.DefinirPolice("nourriture_nom", 16, 700, true)
UI.DefinirPolice("nourriture_aide", 13, 500)

local cTexte, cAide, cBarre, cFondBarre = Color(255, 255, 255), Color(255, 255, 255), Color(255, 255, 255), Color(0, 0, 0, 160)
local decalage = Vector(0, 0, 10)

local function teinte(c, source, a)
	c.r, c.g, c.b, c.a = source.r, source.g, source.b, a
	return c
end

hook.Add("HUDPaint", "origine_nourriture", function()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() or ORIGINE.MenuOuvert() or ORIGINE.EnMenu(ply) then return end
	local ent = ply:GetEyeTrace().Entity
	if not IsValid(ent) or not ent.OrigineNourriture then return end
	local cfg = CI.Nourritures[ent:GetClass()]
	if not cfg then return end
	local dist = ply:GetShootPos():Distance(ent:GetPos())
	if dist > cfg.Portee then return end

	local ecran = (ent:WorldSpaceCenter() + decalage):ToScreen()
	if not ecran.visible then return end
	local x, y = ecran.x, ecran.y
	local a = math.Clamp((1 - dist / cfg.Portee) * 3, 0, 1) * 230

	local nom = ent:GetNW2String("origine_nourriture_nom", "")
	UI.TexteOmbre(cfg.Nom .. (nom ~= "" and (" de " .. nom) or ""), "nourriture_nom", x, y, teinte(cTexte, COL.Texte, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)

	local peut = I.PeutManger(ply, ent:GetClass())
	if not peut then
		UI.TexteOmbre("Immangeable pour vous", "nourriture_aide", x, y + UI.S(2), teinte(cAide, COL.Alerte, a * 0.8), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		return
	end

	local mange = ply:GetNW2Entity("origine_mange") == ent and ply:KeyDown(IN_USE)
	if not mange then
		UI.TexteOmbre("[E] " .. (cfg.Action or "Manger"), "nourriture_aide", x, y + UI.S(2), teinte(cAide, COL.TexteSombre, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		return
	end

	-- Fine barre de progression
	local frac = math.Clamp((CurTime() - ply:GetNW2Float("origine_mange_debut", CurTime())) / cfg.Temps, 0, 1)
	local bw, bh = UI.S(90), math.max(2, UI.S(3))
	local bx, by = x - bw / 2, y + UI.S(6)
	UI.Rect(bx, by, bw, bh, cFondBarre)
	UI.Rect(bx, by, bw * frac, bh, teinte(cBarre, COL.Or, a))
end)
