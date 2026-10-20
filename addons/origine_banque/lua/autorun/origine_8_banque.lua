--[[-----------------------------------------------------------------------
	Origine du monde — chargement de origine_banque
	Dépend de : origine_personnages, origine_staff
-------------------------------------------------------------------------]]

if not (ORIGINE and ORIGINE.PersonnagesCharge and ORIGINE.StaffCharge) then
	if SERVER then
		MsgC(Color(230, 60, 50), "[Origine] origine_banque ne se lance pas : origine_personnages, origine_staff doit être chargé.\n")
	end
	return
end

local DOSSIER = "origine_banque/"
local PARTAGES = { "sh_config.lua", "sh_banque.lua" }
local SERVEUR = { "sv_banque.lua", "sv_admin.lua" }
local CLIENT_ = { "cl_banque.lua" }

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

ORIGINE.BanqueCharge = true
MsgC(Color(201, 164, 92), "[Origine] ", Color(255, 255, 255), "origine_banque chargé.\n")
