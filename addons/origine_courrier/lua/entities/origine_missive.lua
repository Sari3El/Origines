--[[-----------------------------------------------------------------------
	Origine du monde — missive papier (sortie du coffret)
	N'importe qui peut la lire (E), la ranger dans son inventaire ou la
	détruire : elle peut être montrée, perdue ou volée.
-------------------------------------------------------------------------]]

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Missive"
ENT.Category = "Origine"
ENT.Spawnable = false

if SERVER then
	function ENT:Initialize()
		local cfg = ORIGINE and ORIGINE.ConfigCourrier
		self:SetModel(cfg and cfg.ModeleMissive or "models/props_c17/paper01.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then phys:Wake() end
		self.OrigineMissive = self.OrigineMissive or { objet = "?", texte = "", auteur = "?" }
	end

	-- Données gardées quand elle est rangée dans l'inventaire (origine_inventaire)
	function ENT:OrigineVersObjet()
		local d = table.Copy(self.OrigineMissive or {})
		d.nom = "Missive : " .. (d.objet or "?")
		return d
	end

	function ENT:OrigineDepuisObjet(d)
		self.OrigineMissive = { objet = d.objet, texte = d.texte, auteur = d.auteur, date = d.date }
		self:SetNW2String("origine_missive_objet", d.objet or "")
	end

	function ENT:Use(ply)
		if not (IsValid(ply) and ply:IsPlayer()) or (ply.OrigineMissiveUse or 0) > CurTime() then return end
		ply.OrigineMissiveUse = CurTime() + 1
		if ORIGINE and ORIGINE.Courrier then ORIGINE.Courrier.EnvoyerPapier(ply, self.OrigineMissive or {}, self) end
	end
end
