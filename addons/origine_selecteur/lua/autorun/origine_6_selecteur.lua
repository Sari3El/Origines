--[[-----------------------------------------------------------------------
	Origine du monde — chargement de origine_selecteur (sélecteur d'armes)
	Fonctionne seul ; avec origine_personnages, reprend sa charte et ses
	couleurs de rareté.
-------------------------------------------------------------------------]]

ORIGINE = ORIGINE or {}

local DOSSIER = "origine_selecteur/"

if SERVER then
	AddCSLuaFile(DOSSIER .. "sh_config.lua")
	AddCSLuaFile(DOSSIER .. "cl_selecteur.lua")
	include(DOSSIER .. "sh_config.lua")
	-- Sons (aussi distribués par la collection Workshop du serveur)
	for _, son in pairs(ORIGINE.ConfigSelecteur.Sons.Fichiers) do
		if son ~= "" and file.Exists("sound/" .. son, "GAME") then resource.AddSingleFile("sound/" .. son) end
	end
else
	include(DOSSIER .. "sh_config.lua")
	include(DOSSIER .. "cl_selecteur.lua")
end

ORIGINE.SelecteurCharge = true
MsgC(Color(201, 164, 92), "[Origine] ", Color(255, 255, 255), "origine_selecteur chargé.\n")
