--[[-----------------------------------------------------------------------
	Origine du monde — logique partagée des SWEPs de race (Vol)
-------------------------------------------------------------------------]]

local C = ORIGINE.Config

function ORIGINE.ZoneVolInterdite(pos)
	for _, z in ipairs(C.SwepVol.ZonesInterdites or {}) do
		if z.Min and z.Max and pos:WithinAABox(z.Min, z.Max) then return true end
	end
	return false
end

function ORIGINE.EnVol(ply)
	return ply:GetNW2Float("origine_vol_fin", 0) > CurTime()
end

-- Mouvement en vol : SAUT pour monter, ACCROUPI pour descendre, sinon on plane
hook.Add("Move", "origine_vol", function(ply, mv)
	if not ORIGINE.EnVol(ply) then return end
	local cfg = C.SwepVol
	local vel = mv:GetVelocity()
	if mv:KeyDown(IN_JUMP) then
		vel.z = cfg.VitesseMontee
	elseif mv:KeyDown(IN_DUCK) then
		vel.z = -cfg.VitesseDescente
	else
		vel.z = math.max(vel.z, -cfg.ChuteMax)
	end
	mv:SetVelocity(vel)
end)

if SERVER then
	function ORIGINE.DemarrerVol(ply)
		ply:SetNW2Float("origine_vol_fin", CurTime() + C.SwepVol.Duree)
		ply.OrigineVolActif = true
	end

	function ORIGINE.ArreterVol(ply)
		if not ply.OrigineVolActif then return end
		ply.OrigineVolActif = nil
		ply.OrigineFinVol = CurTime()
		ply:SetNW2Float("origine_vol_fin", 0)
		ply:SetNW2Float("origine_vol_recharge", CurTime() + C.SwepVol.Recharge)
	end

	timer.Create("origine_vol", 0.25, 0, function()
		for _, ply in ipairs(player.GetAll()) do
			if ply.OrigineVolActif then
				local arreter = not ORIGINE.EnVol(ply) or not ply:Alive() or ORIGINE.EnMenu(ply)
					or not ply:HasWeapon("origine_vol") or ORIGINE.ZoneVolInterdite(ply:GetPos())
				if arreter then ORIGINE.ArreterVol(ply) end
			end
		end
	end)

	-- Pas de dégâts de chute en vol ni juste après
	hook.Add("GetFallDamage", "origine_vol", function(ply)
		if ORIGINE.EnVol(ply) or (ply.OrigineFinVol and CurTime() - ply.OrigineFinVol < 3) then return 0 end
	end)
end
