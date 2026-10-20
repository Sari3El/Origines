--[[-----------------------------------------------------------------------
	Origine du monde — chargement de origine_personnages

	Ce dossier doit être chargé en premier : origine_inventaire, origine_hud
	et origine_staff en dépendent (d'où le « 1 » dans le nom du fichier).
-------------------------------------------------------------------------]]

ORIGINE = ORIGINE or {}
ORIGINE.Version = "1.0.0"

local DOSSIER = "origine_personnages/"

local PARTAGES = { "sh_config.lua", "sh_util.lua", "sh_darkrp.lua", "sh_sweps.lua" }
local SERVEUR = {
	"sv_db.lua", "sv_historique.lua", "sv_personnages.lua", "sv_darkrp.lua",
	"sv_races.lua", "sv_menu.lua", "sv_sauvegarde.lua",
}
local CLIENT_ = { "cl_charte.lua", "cl_personnages.lua", "cl_menu.lua" }

for _, f in ipairs(PARTAGES) do
	if SERVER then AddCSLuaFile(DOSSIER .. f) end
	include(DOSSIER .. f)
end

if SERVER then
	for _, f in ipairs(CLIENT_) do AddCSLuaFile(DOSSIER .. f) end
	for _, f in ipairs(SERVEUR) do include(DOSSIER .. f) end
	if ORIGINE.Config.WorkshopID ~= "" then resource.AddWorkshop(ORIGINE.Config.WorkshopID) end
else
	for _, f in ipairs(CLIENT_) do include(DOSSIER .. f) end
end

ORIGINE.PersonnagesCharge = true
MsgC(Color(201, 164, 92), "[Origine] ", Color(255, 255, 255), "origine_personnages chargé.\n")
