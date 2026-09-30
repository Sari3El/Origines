--[[-----------------------------------------------------------------------
	Origine du monde — HUD (client)

	Bloc en bas à gauche, juste sous la chatbox (position calculée depuis
	chat.GetChatBoxPos : il ne la chevauche jamais).
	Les accents du cadre prennent la couleur de la faction du joueur
	(couleur de son job) : Empire bleu, Créatures de la nuit rouge,
	Consortium doré, Civils vert.

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
UI.DefinirPolice("hud_chiffres", 13, 700)
UI.DefinirPolice("hud_covan", 19, 700, true)
UI.DefinirPolice("hud_variation", 15, 700)
UI.DefinirPolice("hud_munitions", 34, 700, true)
UI.DefinirPolice("hud_munitions_petit", 16, 600)

local MAT_BAS = Material("gui/gradient_down")
local MAT_HAUT = Material("gui/gradient_up")
local MAT_D = Material("vgui/gradient-r")
local MAT_G = Material("vgui/gradient-l")

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
	return not ORIGINE.SansFaim() and ply.getDarkRPVar and ply:getDarkRPVar("Energy") ~= nil
end

local SANS_METIER = {}
if TEAM_UNASSIGNED then SANS_METIER[TEAM_UNASSIGNED] = true end
if TEAM_CONNECTING then SANS_METIER[TEAM_CONNECTING] = true end
if TEAM_SPECTATOR then SANS_METIER[TEAM_SPECTATOR] = true end

-- Métier, grade et faction du joueur (champs origine_* de jobs.lua)
local function infosJob(ply)
	local t = ply:Team()
	if SANS_METIER[t] then return nil end
	local nom = team.GetName(t)
	if not nom or nom == "" or nom == "Unassigned" then return nil end
	local job = RPExtraTeams and RPExtraTeams[t]
	return nom, job and job.category, job and job.origine_grade
end

---------------------------------------------------------------------------
-- Couleurs (objets réutilisés)
---------------------------------------------------------------------------
local cFaction = Color(201, 164, 92)
local cFactionSombre = Color(60, 45, 30)
local cFactionVoile = Color(201, 164, 92, 60)
local cTemp = Color(255, 255, 255)
local cFondJauge = Color(8, 6, 5, 235)
local cGraduation = Color(0, 0, 0, 110)
local cReflet = Color(255, 255, 255, 55)
local cOmbre = Color(0, 0, 0, 170)
local cFondPlaque = Color(12, 9, 7, 200)
local cMie = Color(236, 200, 140)
local cPieceInt = Color(150, 112, 40)
local cVariation = Color(255, 255, 255)
local cFondPortrait = Color(10, 8, 6, 255)

local function majCouleurFaction(ply)
	local c = team.GetColor(ply:Team())
	if not c or SANS_METIER[ply:Team()] then c = COL.Or end
	cFaction.r, cFaction.g, cFaction.b = c.r, c.g, c.b
	cFactionSombre.r, cFactionSombre.g, cFactionSombre.b = c.r * 0.28, c.g * 0.28, c.b * 0.28
	cFactionVoile.r, cFactionVoile.g, cFactionVoile.b = c.r, c.g, c.b
end

---------------------------------------------------------------------------
-- Géométrie (coordonnées locales du bloc, recalculées si l'échelle change)
---------------------------------------------------------------------------
local G = {}
local piecesPos, pieceExt, pieceInt   -- pièce des Covan (recréée seulement si sa position change)

local function construireGeometrie(avecFaim)
	local S = UI.S
	G.avecFaim = avecFaim
	G.w = S(CH.Largeur)
	G.pad = S(12)
	G.banniere = S(4)                  -- plus de bandeau : simple marge en haut
	G.rayon = S(32)                    -- portrait rond
	G.cx, G.cy = G.pad + S(4) + G.rayon, G.banniere + S(10) + G.rayon
	G.tx = G.cx + G.rayon + S(16)      -- début de la colonne de droite
	G.nomY = G.banniere + S(7)         -- nom (à gauche) et Covan (à droite)
	G.infoY = G.nomY + S(26)           -- race · métier
	G.barreY = G.infoY + S(24)         -- jauges côte à côte
	G.bh = S(14)
	G.h = math.max(G.barreY + G.bh, G.cy + G.rayon + S(5)) + S(10)
	G.icone = S(15)

	-- Jauges sur une seule ligne : PV | armure | faim
	local n = avecFaim and 3 or 2
	local ecart = S(8)
	local dispo_ = G.w - G.tx - G.pad
	local lj = math.floor((dispo_ - (n - 1) * ecart) / n)
	G.jauges = {}
	for i = 1, n do
		local x = G.tx + (i - 1) * (lj + ecart)
		G.jauges[i] = { icx = x + G.icone / 2, x = x + G.icone + S(6), w = lj - G.icone - S(6) }
	end

	-- Cadre : coins en équerre et losanges
	local c, e = S(14), S(3)
	G.equerre, G.epaisseur = c, e
	G.losCoins = {
		UI.PolyLosange(S(5), S(5), S(5)), UI.PolyLosange(G.w - S(5), S(5), S(5)),
		UI.PolyLosange(S(5), G.h - S(5), S(5)), UI.PolyLosange(G.w - S(5), G.h - S(5), S(5)),
	}

	-- Portrait : anneaux
	G.anneauExt = UI.PolyCercle(G.cx, G.cy, G.rayon + S(5), 40)
	G.anneauMil = UI.PolyCercle(G.cx, G.cy, G.rayon + S(3), 40)
	G.disque = UI.PolyCercle(G.cx, G.cy, G.rayon, 40)
	-- Gemme de race sur l'anneau (en bas à droite)
	local a = math.rad(45)
	G.gx, G.gy = G.cx + math.cos(a) * (G.rayon + S(2)), G.cy + math.sin(a) * (G.rayon + S(2))
	G.gemmeFond = UI.PolyLosange(G.gx, G.gy, S(9))
	G.gemme = UI.PolyLosange(G.gx, G.gy, S(6))
	G.gemmeReflet = UI.PolyLosange(G.gx - S(2), G.gy - S(2), S(2))

	-- Icônes des jauges
	G.icones = {}
	local ic, y = G.icone, G.barreY + G.bh / 2
	do -- cœur
		local cx, r = G.jauges[1].icx, ic * 0.27
		G.icones.pv = {
			UI.PolyCercle(cx - r * 0.95, y - r * 0.55, r, 14),
			UI.PolyCercle(cx + r * 0.95, y - r * 0.55, r, 14),
			{ { x = cx - r * 1.9, y = y - r * 0.35 }, { x = cx + r * 1.9, y = y - r * 0.35 }, { x = cx, y = y + ic * 0.45 } },
		}
	end
	do -- bouclier
		local cx, d = G.jauges[2].icx, ic / 2
		G.icones.armure = {
			{ { x = cx - d * 0.85, y = y - d }, { x = cx + d * 0.85, y = y - d }, { x = cx + d * 0.85, y = y },
			  { x = cx, y = y + d }, { x = cx - d * 0.85, y = y } },
		}
		G.icones.armureInt = {
			{ { x = cx - d * 0.45, y = y - d * 0.6 }, { x = cx + d * 0.45, y = y - d * 0.6 }, { x = cx + d * 0.45, y = y - d * 0.05 },
			  { x = cx, y = y + d * 0.55 }, { x = cx - d * 0.45, y = y - d * 0.05 } },
		}
	end
	if avecFaim then
		local cx = G.jauges[3].icx
		G.icones.faim = { x = cx - ic / 2, y = y - ic * 0.32, w = ic, h = ic * 0.64 }
	end
	do -- pièce (Covan, en haut à droite)
		G.pieceY = G.nomY + S(11)
		G.pieceR = ic * 0.58
	end
	G.echelle = UI.Echelle()
	piecesPos = nil
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
	-- Cercle du portrait en coordonnées écran (pour le masque rond)
	dispo.disqueEcran = UI.PolyCercle(dispo.x + G.cx * k, dispo.y + G.cy * k, G.rayon * k, 40)
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
		portrait:SetFOV(28)
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
	portrait:SetLookAt(tete - Vector(0, 0, 2))
	portrait:SetCamPos(tete + Vector(30, 0, 1))
	ent:SetEyeTarget(tete + Vector(40, 0, 0))
end

-- Portrait masqué en cercle (stencil)
local function dessinerPortrait()
	if not IsValid(portrait) or not dispo.disqueEcran then return end
	local k = dispo.k
	local d = math.floor(G.rayon * 2 * k)
	portrait:SetPos(math.floor(dispo.x + (G.cx - G.rayon) * k), math.floor(dispo.y + (G.cy - G.rayon) * k))
	portrait:SetSize(d, d)

	render.ClearStencil()
	render.SetStencilEnable(true)
	render.SetStencilWriteMask(255)
	render.SetStencilTestMask(255)
	render.SetStencilReferenceValue(1)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)
	render.SetStencilPassOperation(STENCIL_REPLACE)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_KEEP)
	UI.DessinerPoly(dispo.disqueEcran, cFondPortrait)
	render.SetStencilCompareFunction(STENCIL_EQUAL)
	render.SetStencilPassOperation(STENCIL_KEEP)
	portrait:PaintManual()
	-- Ombre intérieure en bas du portrait
	surface.SetMaterial(MAT_HAUT)
	surface.SetDrawColor(0, 0, 0, 200)
	surface.DrawTexturedRect(portrait:GetX(), portrait:GetY() + d * 0.55, d, d * 0.45)
	render.SetStencilEnable(false)
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
	cTemp.r = Lerp(a, col.r, COL.Alerte.r)
	cTemp.g = Lerp(a, col.g, COL.Alerte.g)
	cTemp.b = Lerp(a, col.b, COL.Alerte.b)
	cTemp.a = 255
	return cTemp
end

-- Jauge : fond creusé, traînée, remplissage, reflet, graduations, valeur au centre
local function jauge(j, frac, col, id, alerte, texte)
	local x, y, w, h, S = j.x, G.barreY, j.w, G.bh, UI.S
	frac = math.Clamp(frac, 0, 1)
	local t = traine(id, frac)
	UI.Rect(x - 1, y - 1, w + 2, h + 2, COL.Bordure)
	UI.Rect(x, y, w, h, cFondJauge)
	if t > frac then UI.Rect(x, y, w * t, h, COL.Traine) end
	local c = couleurAlerte(col, frac, alerte)
	UI.Rect(x, y, w * frac, h, c)
	surface.SetMaterial(MAT_BAS)
	surface.SetDrawColor(cReflet)
	surface.DrawTexturedRect(x, y, w * frac, h * 0.55)
	surface.SetMaterial(MAT_HAUT)
	surface.SetDrawColor(0, 0, 0, 90)
	surface.DrawTexturedRect(x, y + h * 0.5, w * frac, h * 0.5)
	-- Bord lumineux au bout de la jauge
	if frac > 0 and frac < 1 then
		surface.SetDrawColor(255, 255, 255, 120)
		surface.DrawRect(x + w * frac - 1, y, 1, h)
	end
	surface.SetDrawColor(cGraduation)
	for i = 1, 9 do surface.DrawRect(x + math.floor(w * i / 10), y + h - S(4), 1, S(4)) end
	UI.TexteOmbre(texte, "hud_chiffres", x + w / 2, y + h / 2, COL.Texte, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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

---------------------------------------------------------------------------
-- Cadre
---------------------------------------------------------------------------
local function equerre(x, y, sx, sy)
	local c, e = G.equerre, G.epaisseur
	surface.DrawRect(sx > 0 and x or x - c, y, c, e)
	surface.DrawRect(x, sy > 0 and y or y - c, e, c)
end

local function dessinerCadre(w, h)
	local S = UI.S
	-- Fond : bois sombre, lumière venant du haut, voile de la faction
	UI.Rect(0, 0, w, h, COL.Fond)
	surface.SetMaterial(MAT_BAS)
	surface.SetDrawColor(COL.FondClair.r + 22, COL.FondClair.g + 18, COL.FondClair.b + 12, 110)
	surface.DrawTexturedRect(0, 0, w, h * 0.65)
	surface.SetMaterial(MAT_G)
	surface.SetDrawColor(cFactionVoile.r, cFactionVoile.g, cFactionVoile.b, 28)
	surface.DrawTexturedRect(0, 0, w * 0.6, h)
	-- Fines stries horizontales (texture de bois)
	surface.SetDrawColor(0, 0, 0, 22)
	for yy = S(6), h - S(6), S(5) do surface.DrawRect(S(4), yy, w - S(8), 1) end

	-- Fin liseré de faction en haut (remplace l'ancien bandeau)
	surface.SetMaterial(MAT_D)
	surface.SetDrawColor(cFaction.r, cFaction.g, cFaction.b, 200)
	surface.DrawTexturedRect(S(3), S(3), w - S(6), S(2))

	-- Bordures : extérieure sombre, filet de faction, filet doré intérieur
	UI.Contour(0, 0, w, h, COL.Bordure, S(2))
	UI.Contour(S(2), S(2), w - S(4), h - S(4), cFactionSombre, 1)
	surface.SetDrawColor(COL.Or.r, COL.Or.g, COL.Or.b, 70)
	surface.DrawOutlinedRect(S(5), S(5), w - S(10), h - S(10), 1)

	-- Coins en équerre dorés + losanges de faction
	surface.SetDrawColor(COL.Or)
	equerre(S(1), S(1), 1, 1)
	equerre(w - S(1) - G.epaisseur, S(1), -1, 1)
	equerre(S(1), h - S(1) - G.epaisseur, 1, -1)
	equerre(w - S(1) - G.epaisseur, h - S(1) - G.epaisseur, -1, -1)
	for _, l in ipairs(G.losCoins) do UI.DessinerPoly(l, cFaction) end
end

---------------------------------------------------------------------------
-- Bloc complet (coordonnées locales, réduites par la matrice si besoin)
---------------------------------------------------------------------------
-- Nom coupé avec « … » s'il touche les Covan (résultat gardé tant que nom et place ne changent pas)
local cacheNom = {}
local function nomAjuste(nom, largeur)
	if cacheNom.nom == nom and cacheNom.largeur == largeur then return cacheNom.texte end
	surface.SetFont(UI.Police("hud_nom"))
	local texte = nom
	if surface.GetTextSize(nom) > largeur then
		local n = utf8.len(nom) or #nom
		repeat
			n = n - 1
			local fin = utf8.offset(nom, n + 1)
			texte = (fin and string.sub(nom, 1, fin - 1) or nom) .. "…"
		until n <= 1 or surface.GetTextSize(texte) <= largeur
	end
	cacheNom.nom, cacheNom.largeur, cacheNom.texte = nom, largeur, texte
	return texte
end

local function dessinerBloc(ply)
	local w, h, S = G.w, G.h, UI.S
	local race = ORIGINE.RaceJoueur(ply)
	local colRace = ORIGINE.CouleurRace(race)
	local metier = infosJob(ply)

	dessinerCadre(w, h)

	-- Anneaux du portrait (le portrait lui-même est dessiné ensuite, masqué en rond)
	UI.DessinerPoly(G.anneauExt, COL.Or)
	UI.DessinerPoly(G.anneauMil, cFaction)
	UI.DessinerPoly(G.disque, cFondPortrait)

	-- Gemme de la race sur l'anneau
	UI.DessinerPoly(G.gemmeFond, COL.Or)
	UI.DessinerPoly(G.gemme, colRace)
	UI.DessinerPoly(G.gemmeReflet, cReflet)

	-- Covan (en haut à droite) : pièce + montant qui défile, variation dessous
	local argent = ply.getDarkRPVar and ply:getDarkRPVar("money") or 0
	majCovan(argent)
	local texteCovan = ORIGINE.FormaterCovan(math.Round(covanAffiche))
	surface.SetFont(UI.Police("hud_covan"))
	local lc = surface.GetTextSize(texteCovan)
	local xc = w - G.pad - lc
	local px = xc - S(8) - G.pieceR
	if piecesPos ~= px then
		piecesPos = px
		pieceExt = UI.PolyCercle(px, G.pieceY, G.pieceR, 20)
		pieceInt = UI.PolyCercle(px, G.pieceY, G.pieceR * 0.65, 20)
	end
	UI.DessinerPoly(pieceExt, COL.Or)
	UI.DessinerPoly(pieceInt, cPieceInt)
	UI.TexteOmbre(texteCovan, "hud_covan", xc, G.pieceY, COL.Or, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	if CurTime() < finVariation and variation ~= 0 then
		local reste = (finVariation - CurTime()) / CH.DureeVariationCovan
		local base = variation > 0 and COL.Succes or COL.Alerte
		cVariation.r, cVariation.g, cVariation.b = base.r, base.g, base.b
		cVariation.a = math.Clamp(reste * 2, 0, 1) * 255
		UI.TexteOmbre((variation > 0 and "+" or "-") .. ORIGINE.FormaterNombre(math.abs(variation)), "hud_variation",
			w - G.pad, G.infoY + S(9) - (1 - reste) * S(6), cVariation, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	-- Identité : nom, puis race · métier
	local tx = G.tx
	UI.TexteOmbre(nomAjuste(ORIGINE.NomComplet(ply), px - G.pieceR - tx - S(10)), "hud_nom", tx, G.nomY, COL.Texte)
	surface.SetMaterial(MAT_D)
	surface.SetDrawColor(cFaction.r, cFaction.g, cFaction.b, 150)
	surface.DrawTexturedRect(tx, G.infoY - S(3), px - G.pieceR - tx - S(10), 1)
	local xi = tx
	if race then
		xi = xi + UI.TexteOmbre(ORIGINE.NomRace(race), "hud_texte", xi, G.infoY, colRace)
	end
	if metier then
		if race then xi = xi + UI.TexteOmbre("  ·  ", "hud_texte", xi, G.infoY, COL.TexteSombre) end
		UI.TexteOmbre(metier, "hud_texte", xi, G.infoY, cFaction)
	end

	-- Jauges côte à côte
	local pv, pvmax = math.max(0, ply:Health()), math.max(1, ply:GetMaxHealth())
	for _, poly in ipairs(G.icones.pv) do UI.DessinerPoly(poly, COL.PV) end
	jauge(G.jauges[1], pv / pvmax, COL.PV, "pv", true, pv .. " / " .. pvmax)

	local armax = ply:GetMaxArmor()
	for _, poly in ipairs(G.icones.armure) do UI.DessinerPoly(poly, COL.Armure) end
	for _, poly in ipairs(G.icones.armureInt) do UI.DessinerPoly(poly, COL.Fond) end
	jauge(G.jauges[2], armax > 0 and ply:Armor() / armax or 0, COL.Armure, "armure", false, ply:Armor() .. " / " .. armax)

	if G.avecFaim then
		local faim = ply:getDarkRPVar("Energy") or 0
		local ic = G.icones.faim
		draw.RoundedBox(math.floor(ic.h / 2), ic.x, ic.y, ic.w, ic.h, COL.Faim)
		for i = 1, 3 do UI.Rect(ic.x + ic.w * i / 4, ic.y + ic.h * 0.2, 1, ic.h * 0.45, cMie) end
		jauge(G.jauges[3], faim / 100, COL.Faim, "faim", true, math.Round(faim) .. " %")
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
	UI.Rect(x + UI.S(3), y + UI.S(3), lw - UI.S(6), UI.S(3), cFaction)
	local cy = y + UI.S(35)
	if chargeur >= 0 then
		surface.SetFont(UI.Police("hud_munitions"))
		local cw = surface.GetTextSize(tostring(chargeur))
		local x0 = x + lw / 2 - (cw + UI.S(68)) / 2
		UI.TexteOmbre(tostring(chargeur), "hud_munitions", x0, cy, chargeur == 0 and COL.Alerte or COL.Texte, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		UI.TexteOmbre("/ " .. reserve, "hud_munitions_petit", x0 + cw + UI.S(8), cy + UI.S(6), COL.TexteSombre, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	else
		UI.TexteOmbre(tostring(reserve), "hud_munitions", x + lw / 2, cy, COL.Texte, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	if secondaire > 0 then
		UI.Texte("Secondaire : " .. secondaire, "hud_munitions_petit", x + lw / 2, y + UI.S(68), COL.TexteSombre, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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
	majCouleurFaction(ply)

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

	dessinerPortrait()
	dessinerMunitions(ply)
end)

hook.Add("origine_EchelleChangee", "origine_hud", function()
	G.w = nil
end)
