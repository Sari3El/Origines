--[[-----------------------------------------------------------------------
	Origine du monde — guichet de la banque
	Placé par le staff (permission origine_banque_admin), gardé au redémarrage.
	E : ouvre le menu de la banque.
-------------------------------------------------------------------------]]

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Guichet de la banque"
ENT.Category = "Origine"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.OrigineNePasNettoyer = true

if SERVER then
	function ENT:Initialize()
		local cfg = ORIGINE and ORIGINE.ConfigBanque
		self:SetModel(cfg and cfg.Modele or "models/props_wasteland/controlroom_desk001b.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then phys:EnableMotion(false) end
	end

	function ENT:Use(ply)
		if not (IsValid(ply) and ply:IsPlayer()) then return end
		if (ply.OrigineGuichetUse or 0) > CurTime() then return end
		ply.OrigineGuichetUse = CurTime() + 1
		if ORIGINE and ORIGINE.Banque and ORIGINE.Banque.Ouvrir then ORIGINE.Banque.Ouvrir(ply, self) end
	end

	-- Reste figé après un déplacement au physgun
	function ENT:PhysicsUpdate(phys)
		if not self:IsPlayerHolding() then phys:EnableMotion(false) end
	end
else
	function ENT:Draw()
		self:DrawModel()
		local ply = LocalPlayer()
		if not IsValid(ply) or ply:GetPos():DistToSqr(self:GetPos()) > 250000 then return end
		local UI = ORIGINE and ORIGINE.UI
		if not UI then return end
		local pos = self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 14)
		local ang = Angle(0, (ply:EyePos() - pos):Angle().y + 90, 90)
		cam.Start3D2D(pos, ang, 0.1)
			draw.SimpleTextOutlined("Banque", UI.Police("titre"), 0, 0, UI.C.Or, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 200))
			draw.SimpleTextOutlined("[E] Guichet", UI.Police("texte"), 0, 34, UI.C.Texte, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 200))
		cam.End3D2D()
	end
end
