--[[-----------------------------------------------------------------------
	Origine du monde — interface de la nourriture (client)
	En visant une nourriture : nom, qui peut la manger, ce qu'elle rend,
	temps avant disparition ; en maintenant E : barre de progression.
-------------------------------------------------------------------------]]

local I = ORIGINE.Inv
local UI = ORIGINE.UI
local COL = UI.C
local CI = ORIGINE.ConfigInv

UI.DefinirPolice("nourriture_titre", 20, 700, true)
UI.DefinirPolice("nourriture_texte", 15, 600)

local MAT_BAS = Material("gui/gradient_down")
local MAT_D = Material("vgui/gradient-r")
local cFond = Color(8, 6, 5, 235)
local cReflet = Color(255, 255, 255, 55)
local cAccent = Color(255, 255, 255)
local losange = {}

local function dessinerLosange(x, y, r, col)
	losange[1] = losange[1] or {} losange[2] = losange[2] or {} losange[3] = losange[3] or {} losange[4] = losange[4] or {}
	losange[1].x, losange[1].y = x, y - r
	losange[2].x, losange[2].y = x + r, y
	losange[3].x, losange[3].y = x, y + r
	losange[4].x, losange[4].y = x - r, y
	UI.DessinerPoly(losange, col)
end

hook.Add("HUDPaint", "origine_nourriture", function()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() or ORIGINE.MenuOuvert() or ORIGINE.EnMenu(ply) then return end
	local tr = ply:GetEyeTrace()
	local ent = tr.Entity
	if not IsValid(ent) or not ent.OrigineNourriture then return end
	local cfg = CI.Nourritures[ent:GetClass()]
	if not cfg or ply:GetShootPos():Distance(ent:GetPos()) > cfg.Portee then return end

	local S = UI.S
	local peut = I.PeutManger(ply, ent:GetClass())
	local mange = peut and ply:GetNW2Entity("origine_mange") == ent and ply:KeyDown(IN_USE)
	local accent = peut and COL.Succes or COL.Alerte
	cAccent.r, cAccent.g, cAccent.b = accent.r, accent.g, accent.b

	local w, h = S(340), S(mange and 128 or 104)
	local x, y = ScrW() / 2 - w / 2, ScrH() / 2 + S(60)

	-- Cadre
	UI.Cadre(x, y, w, h, COL.Fond)
	surface.SetMaterial(MAT_D)
	surface.SetDrawColor(cAccent.r, cAccent.g, cAccent.b, 170)
	surface.DrawTexturedRect(x + S(4), y + S(4), w - S(8), S(3))
	dessinerLosange(x + w / 2, y + S(5), S(6), COL.Or)
	dessinerLosange(x + w / 2, y + S(5), S(3), cAccent)

	-- Titre
	local nom = ent:GetNW2String("origine_nourriture_nom", "")
	local titre = cfg.Nom .. (nom ~= "" and (" de " .. nom) or "")
	UI.TexteOmbre(titre, "nourriture_titre", x + w / 2, y + S(24), COL.Or, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	UI.Separateur(x + S(20), y + S(40), w - S(40))

	-- Qui peut manger / ce que ça rend
	if peut then
		UI.Texte("Maintenir E pour " .. string.lower(cfg.Action or "manger"), "nourriture_texte", x + w / 2, y + S(54), COL.Texte, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	else
		UI.Texte(cfg.Refus or "Vous ne pouvez pas manger ça.", "nourriture_texte", x + w / 2, y + S(54), COL.Alerte, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	local gains = {}
	if (cfg.Faim or 0) > 0 and ply.getDarkRPVar and ply:getDarkRPVar("Energy") then gains[#gains + 1] = "+" .. cfg.Faim .. " % faim" end
	if (cfg.PV or 0) > 0 then gains[#gains + 1] = "+" .. cfg.PV .. " PV" end
	local fin = ent:GetNW2Float("origine_fin", 0)
	if fin > 0 then gains[#gains + 1] = "disparaît dans " .. math.max(0, math.ceil(fin - CurTime())) .. " s" end
	UI.Texte(table.concat(gains, "  ·  "), "nourriture_texte", x + w / 2, y + S(78), COL.TexteSombre, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	-- Progression
	if mange then
		local frac = math.Clamp((CurTime() - ply:GetNW2Float("origine_mange_debut", CurTime())) / cfg.Temps, 0, 1)
		local bx, by, bw, bh = x + S(20), y + h - S(30), w - S(40), S(14)
		UI.Rect(bx - 1, by - 1, bw + 2, bh + 2, COL.Bordure)
		UI.Rect(bx, by, bw, bh, cFond)
		UI.Rect(bx, by, bw * frac, bh, cAccent)
		surface.SetMaterial(MAT_BAS)
		surface.SetDrawColor(cReflet)
		surface.DrawTexturedRect(bx, by, bw * frac, bh * 0.55)
		UI.TexteOmbre((cfg.Action or "Manger") .. "…  " .. math.floor(frac * 100) .. " %", "hud_chiffres", bx + bw / 2, by + bh / 2, COL.Texte, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end)
