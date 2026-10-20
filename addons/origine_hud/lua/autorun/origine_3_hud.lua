--[[-----------------------------------------------------------------------
	Origine du monde — chargement de origine_hud
	Dépend de : origine_personnages
-------------------------------------------------------------------------]]

if not (ORIGINE and ORIGINE.PersonnagesCharge) then
	if SERVER then
		MsgC(Color(230, 60, 50), "[Origine] origine_hud ne se lance pas : origine_personnages n'est pas chargé.\n")
	end
	return
end

local DOSSIER = "origine_hud/"
local PARTAGES = { "sh_config.lua" }
local CLIENT_ = { "cl_hud.lua", "cl_tetes.lua" }

for _, f in ipairs(PARTAGES) do
	if SERVER then AddCSLuaFile(DOSSIER .. f) end
	include(DOSSIER .. f)
end

if SERVER then
	for _, f in ipairs(CLIENT_) do AddCSLuaFile(DOSSIER .. f) end
else
	for _, f in ipairs(CLIENT_) do include(DOSSIER .. f) end
end

ORIGINE.HUDCharge = true
MsgC(Color(201, 164, 92), "[Origine] ", Color(255, 255, 255), "origine_hud chargé.\n")
