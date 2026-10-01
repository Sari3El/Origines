--[[-----------------------------------------------------------------------
	Origine du monde — chargement de origine_mise_a_terre
	Dépend de : origine_personnages, origine_inventaire
-------------------------------------------------------------------------]]

if not (ORIGINE and ORIGINE.PersonnagesCharge and ORIGINE.InventaireCharge) then
	if SERVER then
		MsgC(Color(230, 60, 50), "[Origine] origine_mise_a_terre ne se lance pas : origine_personnages, origine_inventaire doit être chargé.\n")
	end
	return
end

local DOSSIER = "origine_mise_a_terre/"
local PARTAGES = { "sh_config.lua", "sh_mise_a_terre.lua" }
local SERVEUR = { "sv_mise_a_terre.lua" }
local CLIENT_ = { "cl_mise_a_terre.lua" }

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

ORIGINE.MiseATerreCharge = true
MsgC(Color(201, 164, 92), "[Origine] ", Color(255, 255, 255), "origine_mise_a_terre chargé.\n")
