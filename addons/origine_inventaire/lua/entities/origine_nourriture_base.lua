--[[-----------------------------------------------------------------------
	Origine du monde — base des nourritures (crâne, pastèque…)
	Maintenir E en visant l'entité pour la manger.
	Réglages : ORIGINE.ConfigInv.Nourritures[classe]
-------------------------------------------------------------------------]]

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Nourriture"
ENT.Author = "Origine du monde"
ENT.Spawnable = false
ENT.OrigineNourriture = true

function ENT:Config()
	return ORIGINE and ORIGINE.ConfigInv and ORIGINE.ConfigInv.Nourritures[self:GetClass()]
end

if SERVER then
	function ENT:Initialize()
		local cfg = self:Config() or {}
		self:SetModel(cfg.Modele or "models/props_junk/watermelon01.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(CONTINUOUS_USE)
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then phys:Wake() end
		if (cfg.Duree or 0) > 0 then
			self.Fin = CurTime() + cfg.Duree
			self:SetNW2Float("origine_fin", self.Fin)
		end
	end

	-- Appelé à chaque tick tant que le joueur maintient E sur l'entité
	function ENT:Use(ply)
		local cfg = self:Config()
		if not cfg or not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() or not ORIGINE.PersoActuel(ply) then return end
		if ply:GetEyeTrace().Entity ~= self or ply:GetShootPos():Distance(self:GetPos()) > cfg.Portee + 20 then return end
		local maintenant = CurTime()
		if not ORIGINE.Inv.PeutManger(ply, self:GetClass()) then
			if (ply.OrigineRefusNourriture or 0) < maintenant then
				ply.OrigineRefusNourriture = maintenant + 2
				ORIGINE.Notifier(ply, cfg.Refus or "Vous ne pouvez pas manger ça.", "erreur")
			end
			return
		end
		if ply:GetNW2Entity("origine_mange") ~= self or maintenant - (ply.OrigineMangeDernier or 0) > 0.3 then
			ply:SetNW2Entity("origine_mange", self)
			ply:SetNW2Float("origine_mange_debut", maintenant)
		end
		ply.OrigineMangeDernier = maintenant
		if maintenant - ply:GetNW2Float("origine_mange_debut", maintenant) >= cfg.Temps then
			ORIGINE.Inv.Manger(ply, self)
		end
	end

	function ENT:Think()
		if self.Fin and CurTime() >= self.Fin then
			self:Remove()
			return
		end
		-- Ceux qui ont lâché E arrêtent de manger
		for _, ply in ipairs(player.GetAll()) do
			if ply:GetNW2Entity("origine_mange") == self and CurTime() - (ply.OrigineMangeDernier or 0) > 0.3 then
				ply:SetNW2Entity("origine_mange", NULL)
			end
		end
		self:NextThink(CurTime() + 0.1)
		return true
	end

	function ENT:OnRemove()
		for _, ply in ipairs(player.GetAll()) do
			if ply:GetNW2Entity("origine_mange") == self then ply:SetNW2Entity("origine_mange", NULL) end
		end
	end
else
	function ENT:Draw()
		self:DrawModel()
	end
end
