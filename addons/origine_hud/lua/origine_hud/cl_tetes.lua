--[[-----------------------------------------------------------------------
	Origine du monde — infos au-dessus de la tête des joueurs (client)

	Nom du personnage, métier, et race dans la couleur de sa rareté.
	Race avec « discrétion » : visible seulement de près.
	Remplace DarkRP_EntityDisplay (qui affichait aussi les infos des portes :
	on les redessine ici).

	Optimisation : les tests de visibilité (traces) ne sont faits que
	quelques fois par seconde ; aucune couleur n'est créée à chaque image.
-------------------------------------------------------------------------]]

local UI = ORIGINE.UI
local COL = UI.C
local CH = ORIGINE.ConfigHUD

UI.DefinirPolice("tete_nom", 22, 700, true)
UI.DefinirPolice("tete_texte", 16, 600)

local visibles = {}   -- { { ply = , max = } }
local prochainTest = 0
local traceDonnees = { mask = MASK_VISIBLE, filter = {} }

local function estVisible(ply, cible)
	traceDonnees.start = ply:EyePos()
	traceDonnees.endpos = cible:EyePos()
	traceDonnees.filter[1], traceDonnees.filter[2] = ply, cible
	return not util.TraceLine(traceDonnees).Hit
end

local function rafraichir(ply)
	for i = #visibles, 1, -1 do visibles[i] = nil end
	local oeil = ply:EyePos()
	for _, cible in ipairs(player.GetAll()) do
		if cible ~= ply and cible:Alive() and not cible:GetNoDraw() and not ORIGINE.EnMenu(cible) then
			local m = ORIGINE.ModsJoueur(cible)
			local max = (m and m.Discretion) and CH.InfosTete.DistanceDiscretion or CH.InfosTete.Distance
			if oeil:DistToSqr(cible:EyePos()) <= max * max and estVisible(ply, cible) then
				visibles[#visibles + 1] = { ply = cible, max = max }
			end
		end
	end
end

local cBlanc, cJob, cRace, cAlerte = Color(255, 255, 255), Color(255, 255, 255), Color(255, 255, 255), Color(255, 255, 255)
local function teinte(c, source, alpha)
	c.r, c.g, c.b, c.a = source.r, source.g, source.b, alpha
	return c
end

local decalage = Vector(0, 0, 14)
local function positionTete(cible)
	local os_ = cible:LookupBone("ValveBiped.Bip01_Head1")
	local pos = os_ and cible:GetBonePosition(os_) or cible:EyePos()
	return pos + decalage
end

hook.Add("HUDPaint", "origine_tetes", function()
	local ply = LocalPlayer()
	if not IsValid(ply) or ORIGINE.MenuOuvert() or ORIGINE.EnMenu(ply) then return end

	if CurTime() >= prochainTest then
		prochainTest = CurTime() + CH.InfosTete.Rafraichissement
		rafraichir(ply)
	end

	local oeil = ply:EyePos()
	for _, v in ipairs(visibles) do
		local cible = v.ply
		if IsValid(cible) and cible:Alive() then
			local dist = oeil:Distance(cible:EyePos())
			local ecran = positionTete(cible):ToScreen()
			if dist <= v.max and ecran.visible then
				local alpha = math.Clamp((1 - dist / v.max) * 2, 0, 1) * 255
				local x, y = ecran.x, ecran.y
				local race = ORIGINE.RaceJoueur(cible)
				UI.TexteOmbre(ORIGINE.NomComplet(cible), "tete_nom", x, y - UI.S(44), teinte(cBlanc, COL.Texte, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				UI.TexteOmbre(team.GetName(cible:Team()) or "", "tete_texte", x, y - UI.S(22),
					teinte(cJob, team.GetColor(cible:Team()), alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				if race then
					UI.TexteOmbre(ORIGINE.NomRace(race), "tete_texte", x, y - UI.S(4),
						teinte(cRace, ORIGINE.CouleurRace(race), alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
				if not ORIGINE.Config.DesactiverPolice and cible.getDarkRPVar and cible:getDarkRPVar("wanted") then
					UI.TexteOmbre("Recherché", "tete_texte", x, y - UI.S(66), teinte(cAlerte, COL.Alerte, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
			end
		end
	end

	-- Infos des portes (propriétaire, à vendre…) : fournies par DarkRP
	local tr = ply:GetEyeTrace()
	local ent = tr.Entity
	if IsValid(ent) and ent.isKeysOwnable and ent:isKeysOwnable() and ent.drawOwnableInfo
		and tr.HitPos:DistToSqr(oeil) < 40000 then
		ent:drawOwnableInfo()
	end
end)
