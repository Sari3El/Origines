--[[-----------------------------------------------------------------------
	Origine du monde — chargement de origine_tickets
	Dépend de : origine_personnages
-------------------------------------------------------------------------]]

if not (ORIGINE and ORIGINE.PersonnagesCharge) then
	if SERVER then
		MsgC(Color(230, 60, 50), "[Origine] origine_tickets ne se lance pas : origine_personnages doit être chargé.\n")
	end
	return
end

local DOSSIER = "origine_tickets/"
local PARTAGES = { "sh_config.lua", "sh_tickets.lua" }
local SERVEUR = { "sv_tickets.lua" }
local CLIENT_ = { "cl_tickets.lua" }

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

ORIGINE.TicketsCharge = true
MsgC(Color(201, 164, 92), "[Origine] ", Color(255, 255, 255), "origine_tickets chargé.\n")
