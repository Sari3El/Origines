--[[-----------------------------------------------------------------------
	Origine du monde — sac de mort
	Touche E : fouiller. Disparaît vide ou au bout de ORIGINE.ConfigInv.Sac.Duree.
-------------------------------------------------------------------------]]

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Sac de mort"
ENT.Author = "Origine du monde"
ENT.Spawnable = false
ENT.OrigineNePasNettoyer = true

if SERVER then
	function ENT:Initialize()
		local cfg = ORIGINE and ORIGINE.ConfigInv and ORIGINE.ConfigInv.Sac
		self:SetModel(cfg and cfg.Modele or "models/props_junk/garbage_bag001a.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then phys:Wake() end
		self.Contenu = self.Contenu or {}
		self.Spectateurs = {}
		self.Fin = CurTime() + (cfg and cfg.Duree or 30)
		self:SetNW2Float("origine_fin", self.Fin)
	end

	function ENT:Use(ply)
		if not ORIGINE or not ORIGINE.Inv or not IsValid(ply) or not ply:IsPlayer() then return end
		if not ORIGINE.PersoActuel(ply) or ply:GetPos():Distance(self:GetPos()) > ORIGINE.ConfigInv.Sac.Portee then return end
		ORIGINE.Inv.PrendreCovanSac(ply, self)
		if #(self.Contenu or {}) == 0 then
			self:Remove() -- plus rien dedans
			return
		end
		ORIGINE.Inv.OuvrirSac(ply, self)
	end

	function ENT:Think()
		if CurTime() >= self.Fin then
			self:Remove()
			return
		end
		-- Ceux qui s'éloignent ne voient plus le sac
		local portee = ORIGINE.ConfigInv.Sac.Portee + 40
		for ply in pairs(self.Spectateurs) do
			if not IsValid(ply) or not ply:Alive() or ply:GetPos():Distance(self:GetPos()) > portee then
				ORIGINE.Inv.FermerSac(ply, self)
			end
		end
		self:NextThink(CurTime() + 1)
		return true
	end

	function ENT:OnRemove()
		if ORIGINE and ORIGINE.Inv then ORIGINE.Inv.FermerSacPourTous(self) end
	end

	-- Jamais rangeable, jamais ramassable au physgun par les joueurs
	function ENT:PhysgunPickup(ply) return ply:IsAdmin() end
else
	function ENT:Draw()
		self:DrawModel()
		local ply = LocalPlayer()
		if not ORIGINE or not ORIGINE.UI or ply:GetPos():DistToSqr(self:GetPos()) > 250 * 250 then return end
		local UI = ORIGINE.UI
		local pos = self:GetPos() + Vector(0, 0, 30)
		local ang = Angle(0, ply:EyeAngles().y - 90, 90)
		cam.Start3D2D(pos, ang, 0.08)
			local nom = self:GetNW2String("origine_sac_nom", "")
			local covan = self:GetNW2Int("origine_sac_covan", 0)
			local reste = math.max(0, math.ceil(self:GetNW2Float("origine_fin", 0) - CurTime()))
			UI.TexteOmbre(nom ~= "" and ("Sac de " .. nom) or "Sac", "sous_titre", 0, 0, UI.C.Or, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			if covan > 0 then
				UI.TexteOmbre(ORIGINE.FormaterCovan(covan), "texte_gras", 0, 34, UI.C.Or, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
			UI.TexteOmbre("E pour prendre  ·  " .. reste .. " s", "texte", 0, covan > 0 and 62 or 34, UI.C.Texte, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cam.End3D2D()
	end
end
