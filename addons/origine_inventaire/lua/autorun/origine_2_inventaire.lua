--[[-----------------------------------------------------------------------
	Origine du monde — chargement de origine_inventaire
	Dépend de : origine_personnages
-------------------------------------------------------------------------]]

if not (ORIGINE and ORIGINE.PersonnagesCharge) then
	if SERVER then
		MsgC(Color(230, 60, 50), "[Origine] origine_inventaire ne se lance pas : origine_personnages n'est pas chargé.\n")
	end
	return
end

local DOSSIER = "origine_inventaire/"
local PARTAGES = { "sh_config.lua", "sh_entites.lua", "sh_inventaire.lua" }
local SERVEUR = { "sv_inventaire.lua", "sv_sac.lua" }
local CLIENT_ = { "cl_inventaire.lua", "cl_sac.lua" }

for _, f in ipairs(PARTAGES) do
	if SERVER then AddCSLuaFile(DOSSIER .. f) end
	include(DOSSIER .. f)
end
ORIGINE.Inv.ChargerListe()

if SERVER then
	for _, f in ipairs(CLIENT_) do AddCSLuaFile(DOSSIER .. f) end
	for _, f in ipairs(SERVEUR) do include(DOSSIER .. f) end
else
	for _, f in ipairs(CLIENT_) do include(DOSSIER .. f) end
end

ORIGINE.InventaireCharge = true
MsgC(Color(201, 164, 92), "[Origine] ", Color(255, 255, 255), "origine_inventaire chargé.\n")
