--[[-----------------------------------------------------------------------
	Origine du monde — SWEP « Mains »
	Aucune arme en main : les bras restent le long du corps.
-------------------------------------------------------------------------]]

AddCSLuaFile()

SWEP.PrintName = "Mains"
SWEP.Author = "Origine du monde"
SWEP.Instructions = "Aucune arme en main."
SWEP.Category = "Origine"
SWEP.Spawnable = false
SWEP.AdminOnly = false

SWEP.Slot = 0
SWEP.SlotPos = 1
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true
SWEP.ViewModel = "models/weapons/c_arms.mdl"
SWEP.WorldModel = ""
SWEP.UseHands = false

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

function SWEP:Initialize()
	-- « normal » : bras le long du corps (vue à la troisième personne)
	self:SetHoldType("normal")
end

function SWEP:Deploy()
	self:SetHoldType("normal")
	return true
end

function SWEP:PrimaryAttack() end
function SWEP:SecondaryAttack() end
function SWEP:Reload() end

-- Rien à l'écran en vue à la première personne, rien dans les mains en troisième personne
function SWEP:ShouldDrawViewModel() return false end
function SWEP:DrawWorldModel() end
function SWEP:DrawWorldModelTranslucent() end
