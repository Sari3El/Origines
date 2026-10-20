--[[-----------------------------------------------------------------------
	Origine du monde — crâne laissé à la mort
	Seules les créatures de la nuit peuvent s'en nourrir (maintenir E).
	Disparaît au bout de 30 secondes. Réglages : ConfigInv.Nourritures.origine_crane
-------------------------------------------------------------------------]]

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "origine_nourriture_base"
ENT.PrintName = "Crâne"
ENT.Category = "Origine"
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.OrigineNourriture = true
ENT.OrigineNePasNettoyer = true
