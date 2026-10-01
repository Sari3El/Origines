--[[-----------------------------------------------------------------------
	Origine du monde — SWEP de race « Crachat de feu » (Sang de Dragon)
	Réglages : ORIGINE.Config.SwepCrachat (origine_personnages/sh_config.lua)
-------------------------------------------------------------------------]]

AddCSLuaFile()

SWEP.PrintName = "Crachat de feu"
SWEP.Author = "Origine du monde"
SWEP.Instructions = "Clic gauche : souffle de feu devant vous."
SWEP.Category = "Origine"
SWEP.Spawnable = false
SWEP.AdminOnly = true

SWEP.Slot = 5
SWEP.SlotPos = 2
SWEP.DrawAmmo = false
SWEP.ViewModel = "models/weapons/c_arms.mdl"
SWEP.WorldModel = ""
SWEP.UseHands = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.OrigineSwepRace = true

function SWEP:Initialize()
	self:SetHoldType("normal")
end

function SWEP:SecondaryAttack() end

function SWEP:PrimaryAttack()
	if not ORIGINE then return end
	local cfg = ORIGINE.Config.SwepCrachat
	self:SetNextPrimaryFire(CurTime() + math.max(0.5, cfg.Recharge))
	local ply = self:GetOwner()
	if not IsValid(ply) then return end
	local origine, dir = ply:GetShootPos(), ply:GetAimVector()

	if CLIENT then
		if not IsFirstTimePredicted() then return end
		local em = ParticleEmitter(origine)
		if not em then return end
		local vitesse = math.max(200, cfg.Portee * 2)
		for _ = 1, 45 do
			local p = em:Add("particles/flamelet" .. math.random(1, 5), origine + dir * 24 + Vector(0, 0, -6))
			if p then
				p:SetVelocity((dir + VectorRand() * 0.12) * math.Rand(vitesse * 0.7, vitesse))
				p:SetDieTime(math.Rand(0.35, 0.6))
				p:SetStartAlpha(230)
				p:SetEndAlpha(0)
				p:SetStartSize(math.Rand(5, 9))
				p:SetEndSize(math.Rand(28, 46))
				p:SetRoll(math.Rand(0, 360))
				p:SetRollDelta(math.Rand(-2, 2))
				p:SetAirResistance(120)
			end
		end
		em:Finish()
		return
	end

	ply:EmitSound("ambient/fire/ignite.wav", 75, 90)
	local cosMax = math.cos(math.rad(cfg.Angle))
	for _, ent in ipairs(ents.FindInSphere(origine, cfg.Portee)) do
		if ent ~= ply and IsValid(ent) and (ent:IsPlayer() or ent:IsNPC() or ent:GetClass() == "prop_physics") then
			local vers = ent:WorldSpaceCenter() - origine
			vers:Normalize()
			if vers:Dot(dir) >= cosMax then
				local tr = util.TraceLine({ start = origine, endpos = ent:WorldSpaceCenter(), filter = { ply, ent }, mask = MASK_SHOT })
				if not tr.Hit and not (ent:IsPlayer() and ORIGINE.EnMenu(ent)) then
					if cfg.Degats > 0 then
						local d = DamageInfo()
						d:SetDamage(cfg.Degats)
						d:SetDamageType(DMG_BURN)
						d:SetAttacker(ply)
						d:SetInflictor(self)
						ent:TakeDamageInfo(d)
					end
					if cfg.Brulure > 0 then ent:Ignite(cfg.Brulure) end
				end
			end
		end
	end
end
