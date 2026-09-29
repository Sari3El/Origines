--[[-----------------------------------------------------------------------
	Origine du monde — HUD (client)

	Bloc compact en bas à gauche, juste sous la chatbox (position calculée
	depuis chat.GetChatBoxPos : il ne la chevauche jamais).
	Polices et matériaux créés une seule fois, jamais pendant le dessin.
-------------------------------------------------------------------------]]

local UI = ORIGINE.UI
local COL = UI.C
local CH = ORIGINE.ConfigHUD

UI.DefinirPolice("hud_nom", 20, 700, true)
UI.DefinirPolice("hud_texte", 15, 500)
UI.DefinirPolice("hud_chiffres", 14, 700)
UI.DefinirPolice("hud_covan", 18, 700, true)
UI.DefinirPolice("hud_munitions", 34, 700, true)
UI.DefinirPolice("hud_munitions_petit", 18, 600)

---------------------------------------------------------------------------
-- Éléments GMod / DarkRP remplacés
---------------------------------------------------------------------------
local MASQUES = {}
for _, nom in ipairs(CH.Masquer) do MASQUES[nom] = true end

hook.Add("HUDShouldDraw", "origine_hud", function(nom)
	if MASQUES[nom] then return false end
end)

local function hudVisible()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then return false end
	if ORIGINE.MenuOuvert() or ORIGINE.EnMenu(ply) then return false end
	return hook.Run("HUDShouldDraw", "origine_hud") ~= false
end

---------------------------------------------------------------------------
-- Disposition (recalculée toutes les secondes, jamais pendant le dessin)
---------------------------------------------------------------------------
local dispo = { x = 20, y = 20, k = 1, w = 380, h = 196 }
local prochainCalcul = 0

local function calculerDisposition()
	local w, h = UI.S(CH.Largeur), UI.S(CH.Hauteur)
	local cx, cy = chat.GetChatBoxPos()
	local cw, chh = chat.GetChatBoxSize()
	local marge = UI.S(CH.Marge)
	local bas = ScrH() - UI.S(8)
	local haut = cy + chh + marge
	local place = bas - haut
	local k = 1
	local x, y = cx, haut
	if place < h then
		k = place / h
		if k < CH.EchelleMinimum then
			-- Pas assez de place dessous : à droite de la chatbox, calé en bas
			k = 1
			x, y = cx + cw + marge, bas - h
		end
	end
	dispo.x, dispo.y, dispo.k, dispo.w, dispo.h = math.floor(x), math.floor(y), k, w, h
end

---------------------------------------------------------------------------
-- Portrait 3D du playermodel (buste, mis à jour quand le modèle change)
---------------------------------------------------------------------------
local portrait
local signature = ""

local function signatureModele(ply)
	local s = ply:GetModel() .. "|" .. ply:GetSkin()
	for i = 0, math.min(ply:GetNumBodyGroups() - 1, 15) do s = s .. ply:GetBodygroup(i) end
	return s
end

local function majPortrait(ply)
	if not IsValid(portrait) then
		portrait = vgui.Create("DModelPanel")
		portrait:SetPaintedManually(true)
		portrait:SetMouseInputEnabled(false)
		portrait:SetFOV(30)
		portrait.LayoutEntity = function() end
		signature = ""
	end
	local sig = signatureModele(ply)
	if sig == signature then return end
	signature = sig
	portrait:SetModel(ply:GetModel())
	local ent = portrait.Entity
	if not IsValid(ent) then return end
	ent:SetSkin(ply:GetSkin())
	for i = 0, ply:GetNumBodyGroups() - 1 do ent:SetBodygroup(i, ply:GetBodygroup(i)) end
	ent.GetPlayerColor = function() return IsValid(LocalPlayer()) and LocalPlayer():GetPlayerColor() or Vector(1, 1, 1) end
	local osTete = ent:LookupBone("ValveBiped.Bip01_Head1")
	local tete = osTete and ent:GetBonePosition(osTete) or (ent:OBBCenter() + Vector(0, 0, ent:OBBMaxs().z * 0.35))
	portrait:SetLookAt(tete - Vector(0, 0, 4))
	portrait:SetCamPos(tete + Vector(34, 0, 0))
	ent:SetEyeTarget(tete + Vector(40, 0, 0))
end

---------------------------------------------------------------------------
-- Jauges avec traînée claire
---------------------------------------------------------------------------
local traines = {}

local function traine(id, frac)
	local t = traines[id]
	if not t then
		t = { valeur = frac, depuis = nil }
		traines[id] = t
	end
	if frac >= t.valeur then
		t.valeur, t.depuis = frac, nil
	else
		t.depuis = t.depuis or CurTime()
		if CurTime() - t.depuis >= CH.DelaiTraine then
			t.valeur = math.max(frac, t.valeur - FrameTime() * CH.VitesseTraine)
			if t.valeur <= frac then t.depuis = nil end
		end
	end
	return t.valeur
end

local function couleurAlerte(col, frac, alerte)
	if not alerte or frac >= CH.SeuilAlerte then return col end
	local a = math.abs(math.sin(CurTime() * 6))
	return Color(Lerp(a, col.r, COL.Alerte.r), Lerp(a, col.g, COL.Alerte.g), Lerp(a, col.b, COL.Alerte.b))
end

local function jauge(x, y, w, h, frac, col, id, alerte)
	frac = math.Clamp(frac, 0, 1)
	local t = traine(id, frac)
	UI.Rect(x, y, w, h, Color(10, 8, 6, 220))
	if t > frac then UI.Rect(x, y, w * t, h, COL.Traine) end
	UI.Rect(x, y, w * frac, h, couleurAlerte(col, frac, alerte))
	surface.SetDrawColor(255, 255, 255, 30)
	surface.DrawRect(x, y, w * frac, math.max(1, math.floor(h / 3)))
	UI.Contour(x, y, w, h, COL.Bordure, 1)
end

---------------------------------------------------------------------------
-- Dessin du bloc (coordonnées locales, réduites par la matrice si besoin)
---------------------------------------------------------------------------
local matrice = Matrix()

local function dessinerBloc(ply)
	local w, h, S = dispo.w, dispo.h, UI.S
	UI.Cadre(0, 0, w, h, COL.Fond)

	-- Portrait
	local p = S(86)
	local px, py = S(12), S(12)
	UI.Rect(px, py, p, p, Color(12, 10, 8, 230))
	UI.Contour(px, py, p, p, COL.Or, 1)

	-- Identité
	local tx = px + p + S(12)
	UI.TexteOmbre(ORIGINE.NomComplet(ply), "hud_nom", tx, S(14), COL.Texte)
	local race = ORIGINE.RaceJoueur(ply)
	UI.Texte(race and ORIGINE.NomRace(race) or "", "hud_texte", tx, S(42), ORIGINE.CouleurRace(race))
	UI.Texte(team.GetName(ply:Team()) or "", "hud_texte", tx, S(64), COL.TexteSombre)

	-- Jauges
	local lx, bx = S(14), S(78)
	local bw, bh = w - bx - S(96), S(12)
	local vx = w - S(14)
	local y = S(110)

	local pv, pvmax = ply:Health(), math.max(1, ply:GetMaxHealth())
	UI.Texte("PV", "hud_texte", lx, y + bh / 2, COL.Texte, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	jauge(bx, y, bw, bh, pv / pvmax, COL.PV, "pv", true)
	UI.Texte(math.max(0, pv) .. " / " .. pvmax, "hud_chiffres", vx, y + bh / 2, COL.Texte, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	y = y + S(20)
	local ar, armax = ply:Armor(), math.max(1, ply:GetMaxArmor())
	UI.Texte("Armure", "hud_texte", lx, y + bh / 2, COL.Texte, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	jauge(bx, y, bw, bh, ar / armax, COL.Armure, "armure", false)
	UI.Texte(ar .. " / " .. ply:GetMaxArmor(), "hud_chiffres", vx, y + bh / 2, COL.Texte, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	y = y + S(20)
	local faim = ply.getDarkRPVar and ply:getDarkRPVar("Energy")
	UI.Texte("Faim", "hud_texte", lx, y + bh / 2, COL.Texte, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	jauge(bx, y, bw, bh, (faim or 100) / 100, COL.Faim, "faim", true)
	UI.Texte(faim and (math.Round(faim) .. " %") or "—", "hud_chiffres", vx, y + bh / 2, COL.Texte, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	-- Covan
	y = y + S(22)
	UI.Separateur(S(12), y, w - S(24))
	local argent = ply.getDarkRPVar and ply:getDarkRPVar("money") or 0
	UI.TexteOmbre(ORIGINE.FormaterCovan(argent), "hud_covan", lx, y + S(6), COL.Or)

	return px, py, p
end

---------------------------------------------------------------------------
-- Compteur de munitions (bas à droite)
---------------------------------------------------------------------------
local function dessinerMunitions(ply)
	local w = ply:GetActiveWeapon()
	if not IsValid(w) or w.DrawAmmo == false then return end
	local type1 = w:GetPrimaryAmmoType()
	local chargeur = w:Clip1()
	if type1 == -1 and chargeur < 0 then return end -- l'arme n'utilise pas de munitions

	local reserve = type1 ~= -1 and ply:GetAmmoCount(type1) or 0
	local texte = chargeur >= 0 and (chargeur .. " / " .. reserve) or tostring(reserve)
	local type2 = w:GetSecondaryAmmoType()
	local secondaire = type2 ~= -1 and ply:GetAmmoCount(type2) or 0

	local lw, lh = UI.S(210), UI.S(secondaire > 0 and 84 or 64)
	local x, y = ScrW() - lw - UI.S(24), ScrH() - lh - UI.S(24)
	UI.Cadre(x, y, lw, lh, COL.Fond)
	UI.TexteOmbre(texte, "hud_munitions", x + lw / 2, y + UI.S(30), COL.Texte, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	if secondaire > 0 then
		UI.Texte("Secondaire : " .. secondaire, "hud_munitions_petit", x + lw / 2, y + UI.S(62), COL.TexteSombre, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

---------------------------------------------------------------------------
hook.Add("HUDPaint", "origine_hud", function()
	if not hudVisible() then return end
	local ply = LocalPlayer()

	if CurTime() >= prochainCalcul then
		prochainCalcul = CurTime() + 1
		calculerDisposition()
		majPortrait(ply)
	end

	local k = dispo.k
	matrice:Identity()
	matrice:Translate(Vector(dispo.x, dispo.y, 0))
	matrice:Scale(Vector(k, k, 1))
	render.PushFilterMag(TEXFILTER.ANISOTROPIC)
	render.PushFilterMin(TEXFILTER.ANISOTROPIC)
	cam.PushModelMatrix(matrice, true)
		local px, py, p = dessinerBloc(ply)
	cam.PopModelMatrix()
	render.PopFilterMin()
	render.PopFilterMag()

	-- Le portrait est un panneau : on le place aux coordonnées écran réelles
	if IsValid(portrait) then
		local m = math.max(1, math.floor(2 * k))
		portrait:SetPos(dispo.x + math.floor(px * k) + m, dispo.y + math.floor(py * k) + m)
		portrait:SetSize(math.floor(p * k) - m * 2, math.floor(p * k) - m * 2)
		portrait:PaintManual()
	end

	dessinerMunitions(ply)
end)

hook.Add("origine_EchelleChangee", "origine_hud", function()
	prochainCalcul = 0
end)
