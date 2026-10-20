--[[-----------------------------------------------------------------------
	Origine du monde — parchemin vierge
	E : écrire une missive (consomme le parchemin). Rangeable dans l'inventaire.
-------------------------------------------------------------------------]]

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Parchemin vierge"
ENT.Category = "Origine"
ENT.Spawnable = true
ENT.AdminOnly = true

if SERVER then
	function ENT:Initialize()
		local cfg = ORIGINE and ORIGINE.ConfigCourrier
		self:SetModel(cfg and cfg.ModeleParchemin or "models/props_c17/paper01.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then phys:Wake() end
	end

	function ENT:Use(ply)
		if not (IsValid(ply) and ply:IsPlayer()) or (ply.OrigineParcheminUse or 0) > CurTime() then return end
		ply.OrigineParcheminUse = CurTime() + 1
		if ORIGINE and ORIGINE.Courrier and ORIGINE.Courrier.OuvrirEcriture then ORIGINE.Courrier.OuvrirEcriture(ply, self) end
	end
end
