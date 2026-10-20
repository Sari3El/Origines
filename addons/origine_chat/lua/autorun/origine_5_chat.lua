--[[-----------------------------------------------------------------------
	Origine du monde — chargement de origine_chat
	Dépend de : origine_personnages (origine_hud conseillé : le chat lui laisse sa place)
-------------------------------------------------------------------------]]

if not (ORIGINE and ORIGINE.PersonnagesCharge) then
	if SERVER then
		MsgC(Color(230, 60, 50), "[Origine] origine_chat ne se lance pas : origine_personnages n'est pas chargé.\n")
	end
	return
end

local DOSSIER = "origine_chat/"
local PARTAGES = { "sh_config.lua" }
local SERVEUR = { "sv_chat.lua" }
local CLIENT_ = { "cl_chat.lua" }

for _, f in ipairs(PARTAGES) do
	if SERVER then AddCSLuaFile(DOSSIER .. f) end
	include(DOSSIER .. f)
end

if SERVER then
	for _, f in ipairs(CLIENT_) do AddCSLuaFile(DOSSIER .. f) end
	for _, f in ipairs(SERVEUR) do include(DOSSIER .. f) end
else
	for _, f in ipairs(CLIENT_) do include(DOSSIER .. f) end
end

ORIGINE.ChatCharge = true
MsgC(Color(201, 164, 92), "[Origine] ", Color(255, 255, 255), "origine_chat chargé.\n")
