--[[-----------------------------------------------------------------------
	Origine du monde — infos au-dessus de la tête des joueurs (client)

	Nom du personnage, métier, et race dans la couleur de sa rareté.
	Race avec « discrétion » : visible seulement de près.
	Remplace DarkRP_EntityDisplay (qui affichait aussi les infos des portes :
	on les redessine ici).
-------------------------------------------------------------------------]]

local UI = ORIGINE.UI
local COL = UI.C
local CH = ORIGINE.ConfigHUD

UI.DefinirPolice("tete_nom", 22, 700, true)
UI.DefinirPolice("tete_texte", 16, 600)

local function visible(ply, cible)
	local tr = util.TraceLine({
		start = ply:EyePos(),
		endpos = cible:EyePos(),
		filter = { ply, cible },
		mask = MASK_VISIBLE,
	})
	return not tr.Hit
end

local function positionTete(cible)
	local os_ = cible:LookupBone("ValveBiped.Bip01_Head1")
	local pos = os_ and cible:GetBonePosition(os_) or cible:EyePos()
	return pos + Vector(0, 0, 14)
end

hook.Add("HUDPaint", "origine_tetes", function()
	local ply = LocalPlayer()
	if not IsValid(ply) or ORIGINE.MenuOuvert() or ORIGINE.EnMenu(ply) then return end
	local oeil = ply:EyePos()

	for _, cible in ipairs(player.GetAll()) do
		if cible ~= ply and cible:Alive() and not cible:GetNoDraw() and not ORIGINE.EnMenu(cible) then
			local race = ORIGINE.RaceJoueur(cible)
			local m = ORIGINE.ModsJoueur(cible)
			local max = (m and m.Discretion) and CH.InfosTete.DistanceDiscretion or CH.InfosTete.Distance
			local dist = oeil:Distance(cible:EyePos())
			if dist <= max and visible(ply, cible) then
				local ecran = positionTete(cible):ToScreen()
				if ecran.visible then
					local alpha = math.Clamp((1 - dist / max) * 2, 0, 1) * 255
					local x, y = ecran.x, ecran.y
					local blanc = Color(COL.Texte.r, COL.Texte.g, COL.Texte.b, alpha)
					local couleurJob = team.GetColor(cible:Team())
					local couleurRace = ORIGINE.CouleurRace(race)
					UI.TexteOmbre(ORIGINE.NomComplet(cible), "tete_nom", x, y - UI.S(44), blanc, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					UI.TexteOmbre(team.GetName(cible:Team()) or "", "tete_texte", x, y - UI.S(22),
						Color(couleurJob.r, couleurJob.g, couleurJob.b, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					if race then
						UI.TexteOmbre(ORIGINE.NomRace(race), "tete_texte", x, y - UI.S(4),
							Color(couleurRace.r, couleurRace.g, couleurRace.b, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					end
					if cible.getDarkRPVar and cible:getDarkRPVar("wanted") then
						UI.TexteOmbre("Recherché", "tete_texte", x, y - UI.S(66),
							Color(COL.Alerte.r, COL.Alerte.g, COL.Alerte.b, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					end
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
