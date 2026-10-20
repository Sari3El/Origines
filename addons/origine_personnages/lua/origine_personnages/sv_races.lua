--[[-----------------------------------------------------------------------
	Origine du monde — effets des races (serveur)

	Les modificateurs s'appliquent par-dessus les valeurs du job
	(ex. job à 150 PV avec ×1,2 => 180 PV) et sont réappliqués à chaque
	spawn et changement de job.
-------------------------------------------------------------------------]]

local C = ORIGINE.Config

local function jobDe(ply)
	return RPExtraTeams and RPExtraTeams[ply:Team()] or nil
end

-- PV max de base du job (avant race)
local function basePV(ply)
	local job = jobDe(ply)
	if job and tonumber(job.origine_pvmax) then return tonumber(job.origine_pvmax) end
	-- Valeur posée par le job au spawn (PlayerSpawn du job), si on ne l'a pas déjà modifiée
	if ply.OrigineBasePVEquipe == ply:Team() and ply.OrigineBasePV then return ply.OrigineBasePV end
	return C.PVMaxDefaut
end

local function baseArmure(ply)
	local job = jobDe(ply)
	if job and tonumber(job.origine_armuremax) then return tonumber(job.origine_armuremax) end
	return C.ArmureMaxDefaut
end

local function vitessesDeBase(ply)
	local job = jobDe(ply)
	local cfg = GAMEMODE and GAMEMODE.Config or {}
	local marche = job and tonumber(job.origine_marche) or cfg.walkspeed or 160
	local course = job and tonumber(job.origine_course) or cfg.runspeed or 240
	return marche, course
end

-- Mémorise le PV max posé par le job au spawn (avant notre multiplicateur).
-- Appelé juste après chaque spawn, avant AppliquerRace.
function ORIGINE.CapturerBasePV(ply)
	local actuel = ply:GetMaxHealth()
	if actuel ~= ply.OrigineDernierPVMax then
		ply.OrigineBasePV = actuel
		ply.OrigineBasePVEquipe = ply:Team()
	end
end

-- Donne les SWEPs de la race, retire ceux des autres races
function ORIGINE.AppliquerSweps(ply)
	local m = ORIGINE.ModsJoueur(ply)
	local garder = {}
	for _, c in ipairs(m and m.Sweps or {}) do garder[c] = true end
	for _, race in ipairs(C.Races) do
		for _, c in ipairs(race.Mod and race.Mod.Sweps or {}) do
			if not garder[c] and ply:HasWeapon(c) then ply:StripWeapon(c) end
		end
	end
	if not ply:Alive() or ORIGINE.EnMenu(ply) then return end
	for c in pairs(garder) do
		if not ply:HasWeapon(c) then ply:Give(c) end
	end
end

function ORIGINE.AppliquerRace(ply)
	if not IsValid(ply) then return end
	local m = ORIGINE.ModsJoueur(ply)
	if not m or not ORIGINE.PersoActuel(ply) then return end

	-- PV max : on garde le même ratio de vie
	local ancienMax = math.max(1, ply:GetMaxHealth())
	local ratio = math.Clamp(ply:Health() / ancienMax, 0, 1)
	local maxPV = math.max(1, math.Round(basePV(ply) * (m.PV or 1)))
	ply:SetMaxHealth(maxPV)
	ply.OrigineDernierPVMax = maxPV
	if ply:Health() > maxPV or ancienMax ~= maxPV then
		ply:SetHealth(math.max(1, math.min(maxPV, math.Round(maxPV * ratio))))
	end

	local maxArmure = math.max(0, math.Round(baseArmure(ply) * (m.Armure or 1)))
	ply:SetMaxArmor(maxArmure)
	if ply:Armor() > maxArmure then ply:SetArmor(maxArmure) end

	local marche, course = vitessesDeBase(ply)
	local v = m.Vitesse or 1
	ply:SetWalkSpeed(marche * v)
	ply:SetRunSpeed(course * v)

	ORIGINE.AppliquerSweps(ply)
	hook.Run("origine_RaceAppliquee", ply, ORIGINE.RaceJoueur(ply))
end

hook.Add("OnPlayerChangedTeam", "origine_races", function(ply)
	timer.Simple(0, function()
		if IsValid(ply) and ORIGINE.PersoActuel(ply) then ORIGINE.AppliquerRace(ply) end
	end)
end)

-- Après une arrestation DarkRP remet ses vitesses : on réapplique à la libération
hook.Add("playerUnArrested", "origine_races", function(ply)
	timer.Simple(0, function()
		if IsValid(ply) and ORIGINE.PersoActuel(ply) then ORIGINE.AppliquerRace(ply) end
	end)
end)

---------------------------------------------------------------------------
-- Dégâts : bonus par catégorie d'arme, esquive, résistances, réduction
---------------------------------------------------------------------------
local function classeArme(dmg, attaquant)
	local infl = dmg:GetInflictor()
	if IsValid(infl) and infl:IsWeapon() then return infl:GetClass() end
	if IsValid(infl) and infl ~= attaquant and not infl:IsPlayer() then return infl:GetClass() end
	if IsValid(attaquant) and attaquant:IsPlayer() then
		local w = attaquant:GetActiveWeapon()
		if IsValid(w) then return w:GetClass() end
	end
	return nil
end

hook.Add("EntityTakeDamage", "origine_races", function(cible, dmg)
	local attaquant = dmg:GetAttacker()
	local attaquantJoueur = IsValid(attaquant) and attaquant:IsPlayer()
	local categorie = attaquantJoueur and ORIGINE.CategorieArme(classeArme(dmg, attaquant)) or nil
	-- Autres addons : return "magie", "melee"… pour remplacer la catégorie (ex. pouvoirs du Mage, origine_armes)
	if attaquantJoueur then
		local autre = hook.Run("origine_CategorieDegats", dmg, attaquant, categorie)
		if isstring(autre) then categorie = autre end
	end

	-- Bonus/malus de l'attaquant
	if attaquantJoueur and categorie then
		local ma = ORIGINE.ModsJoueur(attaquant)
		local bonus = ma and ma.Degats and ma.Degats[categorie]
		if bonus and bonus ~= 0 then dmg:ScaleDamage(math.max(0, 1 + bonus / 100)) end
	end

	if not cible:IsPlayer() then return end
	if ORIGINE.EnMenu(cible) then return true end
	local m = ORIGINE.ModsJoueur(cible)
	if not m then return end

	-- Esquive : uniquement un coup d'arme porté par un joueur (pas chute, feu, noyade)
	if attaquantJoueur and attaquant ~= cible and (m.Esquive or 0) > 0
		and not dmg:IsFallDamage() and not dmg:IsDamageType(DMG_BURN) and not dmg:IsDamageType(DMG_DROWN)
		and math.random() * 100 < m.Esquive then
		hook.Run("origine_Esquive", cible, attaquant)
		return true
	end

	if (m.Feu or 0) ~= 0 and dmg:IsDamageType(DMG_BURN) then
		dmg:ScaleDamage(math.max(0, 1 - m.Feu / 100))
	end
	if (m.Magie or 0) ~= 0 and categorie == "magie" then
		dmg:ScaleDamage(math.max(0, 1 - m.Magie / 100))
	end
	if (m.Reduction or 0) ~= 0 then
		dmg:ScaleDamage(math.max(0, 1 - m.Reduction / 100))
	end
end)

-- Dernier coup reçu (régénération hors combat, blocage de !perso)
hook.Add("PostEntityTakeDamage", "origine_dernier_coup", function(ent, dmg, subi)
	if subi and ent:IsPlayer() and dmg:GetDamage() > 0 then ent.OrigineDernierCoup = CurTime() end
end)

---------------------------------------------------------------------------
-- Régénération hors combat
---------------------------------------------------------------------------
timer.Create("origine_regeneration", 1, 0, function()
	local maintenant = CurTime()
	for _, ply in ipairs(player.GetAll()) do
		-- origine_RegenBloquee : true pour suspendre (joueur à terre…)
		local m = ply:Alive() and not ORIGINE.EnMenu(ply) and hook.Run("origine_RegenBloquee", ply) ~= true
			and ORIGINE.ModsJoueur(ply)
		local r = m and m.Regen
		if r and (r.PV or 0) > 0 and ply:Health() < ply:GetMaxHealth() then
			local horsCombat = maintenant - (ply.OrigineDernierCoup or 0) >= (r.Delai or 10)
			if horsCombat and maintenant >= (ply.OrigineProchaineRegen or 0) then
				ply.OrigineProchaineRegen = maintenant + (r.Intervalle or 5)
				ply:SetHealth(math.min(ply:GetMaxHealth(), ply:Health() + r.PV))
			end
		end
	end
end)

---------------------------------------------------------------------------
-- SWEPs de race : ni jetés, ni vendus, ni rangés
---------------------------------------------------------------------------
hook.Add("canDropWeapon", "origine_sweps_race", function(ply, arme)
	if IsValid(arme) and ORIGINE.EstSwepDeRace(arme:GetClass()) then return false end
end)

hook.Add("PlayerCanPickupWeapon", "origine_sweps_race", function(ply, arme)
	if ORIGINE.EnMenu(ply) then return false end
	-- Un SWEP de race au sol n'est ramassable que par la race qui l'a
	if IsValid(arme) and ORIGINE.EstSwepDeRace(arme:GetClass()) then
		local m = ORIGINE.ModsJoueur(ply)
		if not (m and ORIGINE.DansListe(m.Sweps, arme:GetClass())) then return false end
	end
end)
