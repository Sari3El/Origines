--[[-----------------------------------------------------------------------
	Origine du monde — intégration DarkRP (serveur)
-------------------------------------------------------------------------]]

local C = ORIGINE.Config

---------------------------------------------------------------------------
-- Choix du job au chargement d'un personnage
---------------------------------------------------------------------------
function ORIGINE.RaceAutoriseePourJob(ply, t)
	local job = RPExtraTeams and RPExtraTeams[t]
	if not job then return true end
	local liste = C.RestrictionsJobs[job.command]
	if not liste or #liste == 0 then return true end
	return ORIGINE.DansListe(liste, ORIGINE.RaceJoueur(ply))
end

-- Le job est-il encore accessible (places, VIP, whitelist, race) ?
function ORIGINE.JobDisponible(ply, t)
	if not t or t == ORIGINE.EquipeSelection then return false end
	local job = RPExtraTeams and RPExtraTeams[t]
	if not job then return false end
	if ply:Team() ~= t then
		local max = job.max or 0
		if max > 0 then
			if max < 1 then max = math.ceil(player.GetCount() * max) end
			if team.NumPlayers(t) >= max then return false end
		end
	end
	if job.admin == 1 and not ply:IsAdmin() then return false end
	if (job.admin or 0) > 1 and not ply:IsSuperAdmin() then return false end
	if job.customCheck then
		local ok, res = pcall(job.customCheck, ply)
		if not ok or not res then return false end
	end
	if not ORIGINE.RaceAutoriseePourJob(ply, t) then return false end
	if hook.Run("playerCanChangeTeam", ply, t, false) == false then return false end
	return true
end

function ORIGINE.EquipeParDefaut()
	return GAMEMODE and GAMEMODE.DefaultTeam or 1
end

-- Job sauvegardé s'il est disponible, sinon job par défaut (sans vote)
function ORIGINE.EquipePourPerso(ply, p)
	local t = p.job and ORIGINE.EquipeDeCommande(p.job)
	if t and ORIGINE.JobDisponible(ply, t) then return t end
	return ORIGINE.EquipeParDefaut()
end

hook.Add("playerCanChangeTeam", "origine_jobs", function(ply, t, force)
	if force then return end
	if t == ORIGINE.EquipeSelection then
		return false, "Ce job est réservé au menu personnage."
	end
	if not ORIGINE.PersoActuel(ply) then
		return false, "Choisissez d'abord un personnage."
	end
	if not ORIGINE.RaceAutoriseePourJob(ply, t) then
		return false, "Votre race ne peut pas exercer ce métier."
	end
end)

---------------------------------------------------------------------------
-- Armes : uniquement C.Loadout (DarkRP ne donne plus rien : ni stunstick,
-- ni clés, ni armes de job ou d'admin)
---------------------------------------------------------------------------
hook.Add("PlayerLoadout", "origine_loadout", function(ply)
	if not C.LoadoutStrict or ORIGINE.EnMenu(ply) then return end
	for _, classe in ipairs(C.Loadout) do
		if not ply:HasWeapon(classe) then ply:Give(classe) end
	end
	return true -- empêche le loadout de DarkRP
end)

-- Filet de sécurité : DarkRP peut donner les armes du job au changement de job
-- sans passer par PlayerLoadout. On retire celles qui ne sont pas dans C.Loadout.
local function retirerArmesDarkRP(ply)
	if not C.LoadoutStrict or not IsValid(ply) or ORIGINE.EnMenu(ply) then return end
	local garder = {}
	for _, c in ipairs(C.Loadout) do garder[c] = true end
	local aRetirer = {}
	local job = RPExtraTeams and RPExtraTeams[ply:Team()]
	for _, c in ipairs(job and job.weapons or {}) do aRetirer[c] = true end
	local cfg = GAMEMODE and GAMEMODE.Config or {}
	for _, c in ipairs(cfg.DefaultWeapons or {}) do aRetirer[c] = true end
	for _, c in ipairs(cfg.AdminWeapons or {}) do aRetirer[c] = true end
	for _, c in ipairs({ "stunstick", "weapon_stunstick", "arrest_stick", "unarrest_stick", "door_ram", "keys", "pocket", "weaponchecker", "weapon_keypadchecker" }) do
		aRetirer[c] = true
	end
	for c in pairs(aRetirer) do
		if not garder[c] and ply:HasWeapon(c) then ply:StripWeapon(c) end
	end
	for c in pairs(garder) do
		if not ply:HasWeapon(c) then ply:Give(c) end
	end
end
hook.Add("OnPlayerChangedTeam", "origine_loadout", function(ply)
	timer.Simple(0.2, function() retirerArmesDarkRP(ply) end)
end)
hook.Add("PlayerSpawn", "origine_loadout", function(ply)
	timer.Simple(0.2, function() retirerArmesDarkRP(ply) end)
end)

---------------------------------------------------------------------------
-- Pendant le menu : pas de salaire, faim en pause
---------------------------------------------------------------------------
hook.Add("playerGetSalary", "origine_menu", function(ply)
	if ORIGINE.EnMenu(ply) or not ORIGINE.PersoActuel(ply) then return true, nil, 0 end
end)

hook.Add("hungerUpdate", "origine_menu", function(ply)
	if ORIGINE.EnMenu(ply) then return true end
end)

local function envelopperFaim()
	local meta = FindMetaTable("Player")
	if not meta.hungerUpdate or meta.OrigineFaimEnveloppee then return end
	meta.OrigineFaimEnveloppee = true
	local ancien = meta.hungerUpdate
	meta.hungerUpdate = function(self, ...)
		if ORIGINE.EnMenu(self) then return end
		return ancien(self, ...)
	end
end
hook.Add("DarkRPFinishedLoading", "origine_faim", envelopperFaim)
hook.Add("InitPostEntity", "origine_faim", envelopperFaim)

---------------------------------------------------------------------------
-- Nom RP : uniquement par le personnage
---------------------------------------------------------------------------
hook.Add("CanChangeRPName", "origine_noms", function()
	return false, "Le nom se choisit à la création du personnage."
end)

---------------------------------------------------------------------------
-- Poche DarkRP désactivée
---------------------------------------------------------------------------
hook.Add("canPocket", "origine_poche", function()
	return false, "La poche est remplacée par la sacoche."
end)

hook.Add("PlayerLoadout", "origine_poche", function(ply)
	timer.Simple(0, function()
		if IsValid(ply) and ply:HasWeapon("pocket") then ply:StripWeapon("pocket") end
	end)
end)

---------------------------------------------------------------------------
-- Temps restant d'arrestation et de recherche (pour la sauvegarde)
---------------------------------------------------------------------------
hook.Add("playerArrested", "origine_suivi", function(criminel, duree)
	if IsValid(criminel) then criminel.OrigineFinArrestation = CurTime() + (tonumber(duree) or 0) end
end)

hook.Add("playerUnArrested", "origine_suivi", function(criminel)
	if IsValid(criminel) then criminel.OrigineFinArrestation = nil end
end)

hook.Add("playerWanted", "origine_suivi", function(criminel)
	if IsValid(criminel) then
		local duree = GAMEMODE and GAMEMODE.Config and GAMEMODE.Config.wantedtime or 120
		criminel.OrigineFinRecherche = CurTime() + duree
	end
end)

hook.Add("playerUnWanted", "origine_suivi", function(criminel)
	if IsValid(criminel) then criminel.OrigineFinRecherche = nil end
end)

---------------------------------------------------------------------------
-- Modèle F4 par personnage
---------------------------------------------------------------------------
ORIGINE.NetRecevoir("origine_modele_f4", function(ply)
	local t = net.ReadUInt(16)
	local modele = net.ReadString()
	local p = ORIGINE.PersoActuel(ply)
	local job = RPExtraTeams and RPExtraTeams[t]
	if not p or not job or not ORIGINE.ModeleDuJob(t, modele) then return end
	p.modeles = p.modeles or {}
	p.modeles[job.command] = modele
end, 4)

local function envelopperModele()
	local meta = FindMetaTable("Player")
	if not meta.getPreferredModel or meta.OrigineModeleEnveloppe then return end
	meta.OrigineModeleEnveloppe = true
	local ancien = meta.getPreferredModel
	meta.getPreferredModel = function(self, t, ...)
		local p = ORIGINE.PersoActuel(self)
		local job = RPExtraTeams and RPExtraTeams[t]
		if p and job and p.modeles and p.modeles[job.command] then
			return p.modeles[job.command]
		end
		return ancien(self, t, ...)
	end
end
hook.Add("DarkRPFinishedLoading", "origine_modele", envelopperModele)
hook.Add("InitPostEntity", "origine_modele", envelopperModele)

-- Si la version de DarkRP n'a pas getPreferredModel : on applique après le spawn
hook.Add("PlayerSetModel", "origine_modele", function(ply)
	if FindMetaTable("Player").getPreferredModel then return end
	timer.Simple(0, function()
		if not IsValid(ply) then return end
		local p = ORIGINE.PersoActuel(ply)
		local cmd = ORIGINE.CommandeJob(ply:Team())
		local m = p and p.modeles and cmd and p.modeles[cmd]
		if m and ORIGINE.ModeleDuJob(ply:Team(), m) then ply:SetModel(m) end
	end)
end)

---------------------------------------------------------------------------
-- Avertissements au démarrage : DarkRP absent ou module faim désactivé
---------------------------------------------------------------------------
hook.Add("InitPostEntity", "origine_verif_darkrp", function()
	local rouge, blanc = Color(230, 60, 50), Color(255, 255, 255)
	if not DarkRP or not RPExtraTeams then
		MsgC(rouge, "[Origine] ", blanc, "DarkRP n'est pas chargé : les jobs, les Covan et la faim ne fonctionneront pas.\n")
		MsgC(rouge, "[Origine] ", blanc, "Vérifiez que le serveur est lancé avec +gamemode darkrp.\n")
		return
	end
	local modules = DarkRP.disabledDefaults and DarkRP.disabledDefaults["modules"]
	if modules and modules["hungermod"] then
		MsgC(rouge, "[Origine] ", blanc, "Le module faim de DarkRP est désactivé : la jauge de faim est masquée.\n")
		MsgC(rouge, "[Origine] ", blanc, "Pour l'activer : darkrpmodification/lua/darkrp_config/disabled_defaults.lua -> [\"hungermod\"] = false\n")
	end
	-- Jobs de base de DarkRP encore actifs (hobo, citizen, police…)
	local restants = {}
	for _, job in pairs(RPExtraTeams) do
		if ORIGINE.DansListe({ "citizen", "cp", "mayor", "gangster", "mobboss", "gundealer", "medic", "chief", "hobo" }, job.command) then
			restants[#restants + 1] = job.command
		end
	end
	if #restants > 0 then
		MsgC(rouge, "[Origine] ", blanc, "Jobs de base de DarkRP encore actifs : " .. table.concat(restants, ", ") .. ".\n")
		MsgC(rouge, "[Origine] ", blanc, "Pour les retirer : darkrpmodification/lua/darkrp_config/disabled_defaults.lua, section [\"jobs\"] -> true\n")
	end
	if not ORIGINE.EquipeSelection then
		MsgC(rouge, "[Origine] ", blanc, "Le job caché « " .. ORIGINE.Config.JobSelection.Nom .. " » n'a pas pu être créé.\n")
	end
end)
