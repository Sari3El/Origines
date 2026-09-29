--[[-----------------------------------------------------------------------
	Origine du monde — SWEP « Sacoche » (remplace la poche DarkRP)
	Clic gauche : ranger l'entité visée. Clic droit : ouvrir l'inventaire.
-------------------------------------------------------------------------]]

AddCSLuaFile()

SWEP.PrintName = "Sacoche"
SWEP.Author = "Origine du monde"
SWEP.Instructions = "Clic gauche : ranger l'objet visé. Clic droit : ouvrir la sacoche."
SWEP.Category = "Origine"
SWEP.Spawnable = false
SWEP.AdminOnly = true

SWEP.Slot = 1
SWEP.SlotPos = 1
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

function SWEP:Initialize()
	self:SetHoldType("normal")
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + 0.4)
	if CLIENT or not ORIGINE or not ORIGINE.Inv then return end
	local ply = self:GetOwner()
	local tr = util.TraceLine({
		start = ply:GetShootPos(),
		endpos = ply:GetShootPos() + ply:GetAimVector() * ORIGINE.ConfigInv.Portee,
		filter = ply,
	})
	if IsValid(tr.Entity) then ORIGINE.Inv.Ranger(ply, tr.Entity) end
end

function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire(CurTime() + 0.4)
	if CLIENT then return end
	net.Start("origine_inv_ouvrir")
	net.Send(self:GetOwner())
end

function SWEP:Reload() end

if CLIENT then
	function SWEP:DrawHUD()
		if not ORIGINE or not ORIGINE.UI or not ORIGINE.Inv then return end
		local ply = LocalPlayer()
		local tr = ply:GetEyeTrace()
		local ent = tr.Entity
		if not IsValid(ent) or tr.HitPos:Distance(ply:GetShootPos()) > ORIGINE.ConfigInv.Portee then return end
		local classe = ent:GetClass()
		if classe == "spawned_weapon" and ent.GetWeaponClass then classe = ent:GetWeaponClass() end
		if ORIGINE.Inv.EstAutorisee(classe) then
			ORIGINE.UI.TexteOmbre("Clic gauche : ranger dans la sacoche", "texte_gras", ScrW() / 2, ScrH() / 2 + 40,
				ORIGINE.UI.C.Or, TEXT_ALIGN_CENTER)
		end
	end
end
