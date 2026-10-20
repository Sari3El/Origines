--[[-----------------------------------------------------------------------
	Origine du monde — chargement de origine_staff
	Dépend de : origine_personnages, origine_inventaire
-------------------------------------------------------------------------]]

if not (ORIGINE and ORIGINE.PersonnagesCharge and ORIGINE.InventaireCharge) then
	if SERVER then
		MsgC(Color(230, 60, 50), "[Origine] origine_staff ne se lance pas : origine_personnages et origine_inventaire doivent être chargés.\n")
	end
	return
end

local DOSSIER = "origine_staff/"
local PARTAGES = { "sh_config.lua" }
local SERVEUR = { "sv_staff.lua", "sv_logs.lua" }
local CLIENT_ = { "cl_staff.lua" }

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

ORIGINE.StaffCharge = true
MsgC(Color(201, 164, 92), "[Origine] ", Color(255, 255, 255), "origine_staff chargé.\n")
