--[[-----------------------------------------------------------------------
	Origine du monde — HUD (client)

	Bloc compact en bas à gauche, juste sous la chatbox (position calculée
	depuis chat.GetChatBoxPos : il ne la chevauche jamais).
	Polices, matériaux et formes créés une seule fois, jamais pendant le
	dessin ; aucune couleur ni table créée à chaque image.
-------------------------------------------------------------------------]]

local UI = ORIGINE.UI
local COL = UI.C
local CH = ORIGINE.ConfigHUD

ORIGINE.HUD = ORIGINE.HUD or {}
local HUD = ORIGINE.HUD

UI.DefinirPolice("hud_nom", 21, 700, true)
UI.DefinirPolice("hud_texte", 15, 600)
UI.DefinirPolice("hud_chiffres", 14, 700)
UI.DefinirPolice("hud_covan", 20, 700, true)
UI.DefinirPolice("hud_variation", 15, 700)
UI.DefinirPolice("hud_munitions", 34, 700, true)
UI.DefinirPolice("hud_munitions_petit", 16, 600)

local MAT_DEGRADE_BAS = Material("gui/gradient_down")
local MAT_DEGRADE_D = Material("vgui/gradient-r")

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

local function faimActive(ply)
	return ply.getDarkRPVar and ply:getDarkRPVar("Energy") ~= nil
end

local EQUIPES_SANS_METIER = {}
local function nomMetier(ply)
	local t = ply:Team()
	if EQUIPES_SANS_METIER[t] then return nil end
	local nom = team.GetName(t)
	if not nom or nom == "" or nom == "Unassigned" then return nil end
	return nom
end
if TEAM_UNASSIGNED then EQUIPES_SANS_METIER[TEAM_UNASSIGNED] = true end
if TEAM_CONNECTING then EQUIPES_SANS_METIER[TEAM_CONNECTING] = true end
if TEAM_SPECTATOR then EQUIPES_SANS_METIER[TEAM_SPECTATOR] = true end

---------------------------------------------------------------------------
-- Géométrie (coordonnées locales du bloc, recalculées si l'échelle change)
---------------------------------------------------------------------------
local G = {}

local function construireGeometrie(avecFaim)
	local S = UI.S
	G.avecFaim = avecFaim
	G.w = S(CH.Largeur)
	G.pad = S(12)
	G.portrait = S(80)
	G.px, G.py = G.pad, G.pad
	G.tx = G.px + G.portrait + S(14)
	G.sepY = G.py + G.portrait + S(10)
	G.barreY = G.sepY + S(12)
	G.ligne = S(21)
	G.nbBarres = avecFaim and 3 or 2
	G.covanY = G.barreY + G.nbBarres * G.ligne + S(2)
	G.h = G.covanY + S(32)
	G.icone = S(14)
	G.bx = G.pad + G.icone + S(10)
	G.bw = G.w - G.bx - S(92)
	G.bh = S(12)
	G.vx = G.w - G.pad

	-- Formes en cache
	local c = S(6)
	G.coins = {
		UI.PolyLosange(0, 0, c), UI.PolyLosange(G.w, 0, c),
		UI.PolyLosange(0, G.h, c), UI.PolyLosange(G.w, G.h, c),
	}
	G.losangeHaut = UI.PolyLosange(G.w / 2, 0, S(5))
	G.losangeSep = UI.PolyLosange(G.w / 2, G.sepY, S(4))
	G.gemmeRace = UI.PolyLosange(G.tx + S(5), G.py + S(41), S(5))
	G.pointJob = UI.PolyCercle(G.tx + S(5), G.py + S(62), S(3.5), 12)

	-- Icônes des jauges
	G.icones = {}
	local function yLigne(i) return G.barreY + (i - 1) * G.ligne + G.bh / 2 end
	local ic, cx = G.icone, G.pad + G.icone / 2
	do -- cœur
		local y, r = yLigne(1), ic * 0.27
		G.icones.pv = {
			UI.PolyCercle(cx - r * 0.95, y - r * 0.55, r, 14),
			UI.PolyCercle(cx + r * 0.95, y - r * 0.55, r, 14),
			{ { x = cx - r * 1.9, y = y - r * 0.35 }, { x = cx + r * 1.9, y = y - r * 0.35 }, { x = cx, y = y + ic * 0.45 } },
		}
	end
	do -- bouclier
		local y, d = yLigne(2), ic / 2
		G.icones.armure = {
			{ { x = cx - d * 0.85, y = y - d }, { x = cx + d * 0.85, y = y - d }, { x = cx + d * 0.85, y = y },
			  { x = cx, y = y + d }, { x = cx - d * 0.85, y = y } },
		}
		G.icones.armureInt = {
			{ { x = cx - d * 0.45, y = y - d * 0.6 }, { x = cx + d * 0.45, y = y - d * 0.6 }, { x = cx + d * 0.45, y = y - d * 0.05 },
			  { x = cx, y = y + d * 0.55 }, { x = cx - d * 0.45, y = y - d * 0.05 } },
		}
	end
	do -- pain
		local y = yLigne(3)
		G.icones.faim = { x = cx - ic / 2, y = y - ic * 0.32, w = ic, h = ic * 0.64 }
	end
	do -- pièce
		local y = G.covanY + S(12)
		G.pieceX = cx
		G.icones.piece = UI.PolyCercle(cx, y, ic * 0.55, 20)
		G.icones.pieceInt = UI.PolyCercle(cx, y, ic * 0.36, 20)
		G.pieceY = y
	end
	G.echelle = UI.Echelle()
end

---------------------------------------------------------------------------
-- Disposition à l'écran (recalculée toutes les secondes)
---------------------------------------------------------------------------
local dispo = { x = 20, y = 20, k = 1 }

function HUD.Hauteur()
	if not G.h then construireGeometrie(true) end
	return G.h
end

local function calculerDisposition()
	local cx, cy = chat.GetChatBoxPos()
	local cw, chh = chat.GetChatBoxSize()
	local marge = UI.S(CH.Marge)
	local bas = ScrH() - UI.S(8)
	local haut = cy + chh + marge
	local k = 1
	local x, y = cx, haut
	if bas - haut < G.h then
		k = (bas - haut) / G.h
		if k < CH.EchelleMinimum then
			k = 1
			x, y = cx + cw + marge, bas - G.h
		end
	end
	dispo.x, dispo.y, dispo.k = math.floor(x), math.floor(y), k
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
	portrait:SetLookAt(tete - Vector(0, 0, 3))
	portrait:SetCamPos(tete + Vector(32, 0, 1))
	ent:SetEyeTarget(tete + Vector(40, 0, 0))
end

---------------------------------------------------------------------------
-- Jauges avec traînée claire
---------------------------------------------------------------------------
local traines = {}
local couleurTemp = Color(255, 255, 255)
local couleurFond = Color(10, 8, 6, 230)
local couleurGraduation = Color(0, 0, 0, 90)
local couleurReflet = Color(255, 255, 255, 45)

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

-- Couleur qui clignote en rouge sous le seuil (objet réutilisé, pas d'allocation)
local function couleurAlerte(col, frac, alerte)
	if not alerte or frac >= CH.SeuilAlerte then return col end
	local a = math.abs(math.sin(CurTime() * 6))
	couleurTemp.r = Lerp(a, col.r, COL.Alerte.r)
	couleurTemp.g = Lerp(a, col.g, COL.Alerte.g)
	couleurTemp.b = Lerp(a, col.b, COL.Alerte.b)
	couleurTemp.a = 255
	return couleurTemp
end

local function jauge(y, frac, col, id, alerte)
	local x, w, h = G.bx, G.bw, G.bh
	frac = math.Clamp(frac, 0, 1)
	local t = traine(id, frac)
	UI.Rect(x, y, w, h, couleurFond)
	if t > frac then UI.Rect(x, y, w * t, h, COL.Traine) end
	local c = couleurAlerte(col, frac, alerte)
	UI.Rect(x, y, w * frac, h, c)
	-- Reflet sur la moitié haute
	surface.SetMaterial(MAT_DEGRADE_BAS)
	surface.SetDrawColor(couleurReflet)
	surface.DrawTexturedRect(x, y, w * frac, h * 0.6)
	-- Graduations tous les 25 %
	surface.SetDrawColor(couleurGraduation)
	for i = 1, 3 do surface.DrawRect(x + math.floor(w * i / 4), y + 1, 1, h - 2) end
	UI.Contour(x - 1, y - 1, w + 2, h + 2, COL.Bordure, 1)
end

---------------------------------------------------------------------------
-- Covan : défilement et variation
---------------------------------------------------------------------------
local covanAffiche, covanReel
local variation, finVariation = 0, 0

local function majCovan(argent)
	if not covanReel then covanReel, covanAffiche = argent, argent return end
	if argent ~= covanReel then
		local d = argent - covanReel
		if CurTime() < finVariation then variation = variation + d else variation = d end
		finVariation = CurTime() + CH.DureeVariationCovan
		covanReel = argent
	end
	covanAffiche = Lerp(math.min(1, FrameTime() * 7), covanAffiche, covanReel)
	if math.abs(covanAffiche - covanReel) < 1 then covanAffiche = covanReel end
end

local couleurVariation = Color(255, 255, 255)

---------------------------------------------------------------------------
-- Dessin du bloc (coordonnées locales, réduites par la matrice si besoin)
---------------------------------------------------------------------------
local couleurCadreRace = Color(255, 255, 255)
local couleurFondPortrait = Color(14, 11, 8, 240)
local couleurMie = Color(236, 200, 140)
local couleurPieceInt = Color(150, 112, 40)

local function dessinerBloc(ply)
	local w, h, S = G.w, G.h, UI.S
	local race = ORIGINE.RaceJoueur(ply)
	local colRace = ORIGINE.CouleurRace(race)

	-- Fond : bois sombre avec lumière venant du haut
	UI.Rect(0, 0, w, h, COL.Fond)
	surface.SetMaterial(MAT_DEGRADE_BAS)
	surface.SetDrawColor(COL.FondClair.r + 20, COL.FondClair.g + 16, COL.FondClair.b + 10, 120)
	surface.DrawTexturedRect(0, 0, w, h * 0.7)

	-- Liseré de la couleur de la rareté
	surface.SetMaterial(MAT_DEGRADE_D)
	surface.SetDrawColor(colRace.r, colRace.g, colRace.b, 200)
	surface.DrawTexturedRect(S(4), S(4), w - S(8), S(2))

	-- Cadre : bordure, filet doré, coins ornés
	UI.Contour(0, 0, w, h, COL.Bordure, S(2))
	surface.SetDrawColor(COL.Or.r, COL.Or.g, COL.Or.b, 80)
	surface.DrawOutlinedRect(S(4), S(4), w - S(8), h - S(8), 1)
	for _, c in ipairs(G.coins) do UI.DessinerPoly(c, COL.Or) end
	UI.DessinerPoly(G.losangeHaut, colRace)

	-- Portrait (médaillon)
	local px, py, p = G.px, G.py, G.portrait
	UI.Rect(px, py, p, p, couleurFondPortrait)
	couleurCadreRace.r, couleurCadreRace.g, couleurCadreRace.b = colRace.r, colRace.g, colRace.b
	UI.Contour(px - S(2), py - S(2), p + S(4), p + S(4), COL.Or, 1)
	UI.Contour(px - 1, py - 1, p + 2, p + 2, couleurCadreRace, S(2))

	-- Identité
	local tx = G.tx
	UI.TexteOmbre(ORIGINE.NomComplet(ply), "hud_nom", tx, py + S(4), COL.Texte)
	if race then
		UI.DessinerPoly(G.gemmeRace, colRace)
		UI.Texte(ORIGINE.NomRace(race), "hud_texte", tx + S(16), py + S(41), colRace, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	local metier = nomMetier(ply)
	if metier then
		UI.DessinerPoly(G.pointJob, team.GetColor(ply:Team()))
		UI.Texte(metier, "hud_texte", tx + S(16), py + S(62), COL.TexteSombre, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	UI.SeparateurOrne(S(12), G.sepY, w - S(24), G.losangeSep)

	-- Jauges
	local y, vx, bh = G.barreY, G.vx, G.bh
	local pv, pvmax = math.max(0, ply:Health()), math.max(1, ply:GetMaxHealth())
	for _, poly in ipairs(G.icones.pv) do UI.DessinerPoly(poly, COL.PV) end
	jauge(y, pv / pvmax, COL.PV, "pv", true)
	UI.TexteOmbre(pv .. " / " .. pvmax, "hud_chiffres", vx, y + bh / 2, COL.Texte, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	y = y + G.ligne
	local armax = ply:GetMaxArmor()
	for _, poly in ipairs(G.icones.armure) do UI.DessinerPoly(poly, COL.Armure) end
	for _, poly in ipairs(G.icones.armureInt) do UI.DessinerPoly(poly, COL.Fond) end
	jauge(y, armax > 0 and ply:Armor() / armax or 0, COL.Armure, "armure", false)
	UI.TexteOmbre(ply:Armor() .. " / " .. armax, "hud_chiffres", vx, y + bh / 2, COL.Texte, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	if G.avecFaim then
		y = y + G.ligne
		local faim = ply:getDarkRPVar("Energy") or 0
		local ic = G.icones.faim
		draw.RoundedBox(math.floor(ic.h / 2), ic.x, ic.y, ic.w, ic.h, COL.Faim)
		UI.Rect(ic.x + ic.w * 0.25, ic.y + ic.h * 0.2, 1, ic.h * 0.45, couleurMie)
		UI.Rect(ic.x + ic.w * 0.5, ic.y + ic.h * 0.2, 1, ic.h * 0.45, couleurMie)
		UI.Rect(ic.x + ic.w * 0.75, ic.y + ic.h * 0.2, 1, ic.h * 0.45, couleurMie)
		jauge(y, faim / 100, COL.Faim, "faim", true)
		UI.TexteOmbre(math.Round(faim) .. " %", "hud_chiffres", vx, y + bh / 2, COL.Texte, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	-- Covan
	UI.DessinerPoly(G.icones.piece, COL.Or)
	UI.DessinerPoly(G.icones.pieceInt, couleurPieceInt)
	local argent = ply.getDarkRPVar and ply:getDarkRPVar("money") or 0
	majCovan(argent)
	local texte = ORIGINE.FormaterCovan(math.Round(covanAffiche))
	UI.TexteOmbre(texte, "hud_covan", G.bx, G.pieceY, COL.Or, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	if CurTime() < finVariation and variation ~= 0 then
		local reste = (finVariation - CurTime()) / CH.DureeVariationCovan
		local base = variation > 0 and COL.Succes or COL.Alerte
		couleurVariation.r, couleurVariation.g, couleurVariation.b = base.r, base.g, base.b
		couleurVariation.a = math.Clamp(reste * 2, 0, 1) * 255
		surface.SetFont(UI.Police("hud_covan"))
		local tw = surface.GetTextSize(texte)
		UI.TexteOmbre((variation > 0 and "+" or "-") .. ORIGINE.FormaterNombre(math.abs(variation)), "hud_variation",
			G.bx + tw + S(10), G.pieceY - (1 - reste) * S(6), couleurVariation, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
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
	local type2 = w:GetSecondaryAmmoType()
	local secondaire = type2 ~= -1 and ply:GetAmmoCount(type2) or 0

	local lw, lh = UI.S(200), UI.S(secondaire > 0 and 86 or 66)
	local x, y = ScrW() - lw - UI.S(24), ScrH() - lh - UI.S(24)
	UI.Cadre(x, y, lw, lh, COL.Fond)
	local cy = y + UI.S(33)
	if chargeur >= 0 then
		surface.SetFont(UI.Police("hud_munitions"))
		local cw = surface.GetTextSize(tostring(chargeur))
		local total = cw + UI.S(8) + UI.S(60)
		local x0 = x + lw / 2 - total / 2
		UI.TexteOmbre(tostring(chargeur), "hud_munitions", x0, cy, chargeur == 0 and COL.Alerte or COL.Texte, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		UI.TexteOmbre("/ " .. reserve, "hud_munitions_petit", x0 + cw + UI.S(8), cy + UI.S(6), COL.TexteSombre, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	else
		UI.TexteOmbre(tostring(reserve), "hud_munitions", x + lw / 2, cy, COL.Texte, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	if secondaire > 0 then
		UI.Texte("Secondaire : " .. secondaire, "hud_munitions_petit", x + lw / 2, y + UI.S(66), COL.TexteSombre, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

---------------------------------------------------------------------------
local matrice = Matrix()
local vecPos, vecEchelle = Vector(), Vector(1, 1, 1)
local prochainCalcul = 0

hook.Add("HUDPaint", "origine_hud", function()
	if not hudVisible() then return end
	local ply = LocalPlayer()

	local avecFaim = faimActive(ply)
	if not G.w or G.avecFaim ~= avecFaim or G.echelle ~= UI.Echelle() then
		construireGeometrie(avecFaim)
		prochainCalcul = 0
	end
	if CurTime() >= prochainCalcul then
		prochainCalcul = CurTime() + 1
		calculerDisposition()
		majPortrait(ply)
	end

	local k = dispo.k
	vecPos.x, vecPos.y = dispo.x, dispo.y
	vecEchelle.x, vecEchelle.y = k, k
	matrice:Identity()
	matrice:Translate(vecPos)
	matrice:Scale(vecEchelle)
	render.PushFilterMag(TEXFILTER.ANISOTROPIC)
	render.PushFilterMin(TEXFILTER.ANISOTROPIC)
	cam.PushModelMatrix(matrice, true)
		dessinerBloc(ply)
	cam.PopModelMatrix()
	render.PopFilterMin()
	render.PopFilterMag()

	-- Le portrait est un panneau : on le place aux coordonnées écran réelles
	if IsValid(portrait) then
		local p = G.portrait
		portrait:SetPos(dispo.x + math.floor(G.px * k), dispo.y + math.floor(G.py * k))
		portrait:SetSize(math.floor(p * k), math.floor(p * k))
		portrait:PaintManual()
	end

	dessinerMunitions(ply)
end)

hook.Add("origine_EchelleChangee", "origine_hud", function()
	G.w = nil
end)
