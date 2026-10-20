--[[-----------------------------------------------------------------------
	Origine du monde — chargement de origine_armes (armes wOS de base)
	Dépend de : wOS ALCS (les armes sont des sabres wOS). Les liens avec
	origine_personnages, origine_inventaire et origine_selecteur sont
	facultatifs.
-------------------------------------------------------------------------]]

ORIGINE = ORIGINE or {}

if SERVER then
	AddCSLuaFile("origine_armes/sh_armes.lua")
	AddCSLuaFile("origine_armes/sh_epee.lua")
	AddCSLuaFile("origine_armes/sh_modele.lua")
	-- Matériau de la lame invisible (aussi dans la collection Workshop du serveur)
	resource.AddFile("materials/origine_armes/lame_invisible.vmt")
end
include("origine_armes/sh_armes.lua")
include("origine_armes/sh_epee.lua")
include("origine_armes/sh_modele.lua")

ORIGINE.ArmesCharge = true
MsgC(Color(201, 164, 92), "[Origine] ", Color(255, 255, 255), "origine_armes chargé.\n")
