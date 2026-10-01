--[[-----------------------------------------------------------------------
	Origine du monde — SWEP de race « Vol » (Céleste)
	Réglages : ORIGINE.Config.SwepVol (origine_personnages/sh_config.lua)
-------------------------------------------------------------------------]]

AddCSLuaFile()

SWEP.PrintName = "Vol"
SWEP.Author = "Origine du monde"
SWEP.Instructions = "Clic gauche : s'envoler. Saut : monter. Accroupi : descendre. Clic droit : se poser."
SWEP.Category = "Origine"
SWEP.Spawnable = false
SWEP.AdminOnly = true

SWEP.Slot = 5
SWEP.SlotPos = 1
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
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

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + 0.5)
	if CLIENT or not ORIGINE then return end
	local ply = self:GetOwner()
	if not IsValid(ply) or ORIGINE.EnVol(ply) then return end
	local recharge = ply:GetNW2Float("origine_vol_recharge", 0)
	if recharge > CurTime() then
		ORIGINE.Notifier(ply, "Vol disponible dans " .. math.ceil(recharge - CurTime()) .. " s.", "erreur")
		return
	end
	if ORIGINE.ZoneVolInterdite(ply:GetPos()) then
		ORIGINE.Notifier(ply, "Impossible de voler ici.", "erreur")
		return
	end
	ORIGINE.DemarrerVol(ply)
	ply:SetVelocity(Vector(0, 0, 300))
	ply:EmitSound("ambient/wind/wind_snippet2.wav", 70, 110)
end

function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire(CurTime() + 0.5)
	if CLIENT or not ORIGINE then return end
	ORIGINE.ArreterVol(self:GetOwner())
end

function SWEP:Holster()
	if SERVER and ORIGINE and IsValid(self:GetOwner()) then ORIGINE.ArreterVol(self:GetOwner()) end
	return true
end

if CLIENT then
	function SWEP:DrawHUD()
		if not ORIGINE or not ORIGINE.UI then return end
		local ply = LocalPlayer()
		local UI = ORIGINE.UI
		local texte
		if ORIGINE.EnVol(ply) then
			texte = "En vol : " .. math.ceil(ply:GetNW2Float("origine_vol_fin", 0) - CurTime()) .. " s"
		else
			local r = ply:GetNW2Float("origine_vol_recharge", 0) - CurTime()
			texte = r > 0 and ("Recharge : " .. math.ceil(r) .. " s") or "Vol prêt"
		end
		UI.TexteOmbre(texte, "texte_gras", ScrW() / 2, ScrH() * 0.62, UI.C.Texte, TEXT_ALIGN_CENTER)
	end
end
