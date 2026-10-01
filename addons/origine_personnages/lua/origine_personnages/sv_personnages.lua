--[[-----------------------------------------------------------------------
	Origine du monde — comptes et personnages (serveur)

	Règle d'or : tout appartient au personnage (Covan, inventaire, armes,
	job, stats, nom, race). Seuls les points de reroll sont liés au compte.
-------------------------------------------------------------------------]]

local C = ORIGINE.Config
local DB = ORIGINE.DB

---------------------------------------------------------------------------
-- Réseau : réception avec limite anti-spam par joueur
---------------------------------------------------------------------------
function ORIGINE.NetRecevoir(nom, fn, parSeconde)
	util.AddNetworkString(nom)
	parSeconde = parSeconde or 4
	net.Receive(nom, function(len, ply)
		if not IsValid(ply) then return end
		if len > 65536 then return end
		ply.OrigineNet = ply.OrigineNet or {}
		local maintenant = CurTime()
		local t = ply.OrigineNet[nom]
		if not t or maintenant - t.debut >= 1 then
			t = { debut = maintenant, n = 0 }
			ply.OrigineNet[nom] = t
		end
		t.n = t.n + 1
		if t.n > parSeconde then return end
		fn(ply, len)
	end)
end

util.AddNetworkString("origine_notif")
util.AddNetworkString("origine_annonce")

-- Message privé à un joueur (type : "erreur", "info", "succes")
function ORIGINE.Notifier(ply, texte, typ)
	if not IsValid(ply) then return end
	net.Start("origine_notif")
		net.WriteString(texte)
		net.WriteString(typ or "info")
	net.Send(ply)
end

-- Annonce dans le chat de tout le serveur
function ORIGINE.Annoncer(couleur, texte)
	net.Start("origine_annonce")
		net.WriteColor(couleur)
		net.WriteString(texte)
	net.Broadcast()
end

---------------------------------------------------------------------------
-- Conversion lignes SQL <-> tables Lua
---------------------------------------------------------------------------
local function num(v, defaut)
	local n = tonumber(v)
	if n == nil then return defaut end
	return n
end

local function json(v, defaut)
	if not v or v == "" or v == "NULL" then return defaut end
	return util.JSONToTable(v) or defaut
end

local function booleen(v) return tonumber(v) == 1 end

function ORIGINE.LigneVersCompte(l)
	return {
		steamid64 = l.steamid64,
		nom_steam = l.nom_steam,
		rerolls = num(l.rerolls, 0),
		dernier_slot = num(l.dernier_slot, 1),
		reroll_gratuit = num(l.reroll_gratuit, 0),
		event_debloque = num(l.event_debloque, 0),
		event_race = (l.event_race and l.event_race ~= "NULL") and l.event_race or nil,
		vip_debloque = num(l.vip_debloque, 0),
		migration_covan = num(l.migration_covan, nil),
		migration_faite = num(l.migration_faite, 0),
		premiere_connexion = num(l.premiere_connexion, os.time()),
	}
end

function ORIGINE.LigneVersPerso(l)
	return {
		steamid64 = l.steamid64,
		slot = num(l.slot, 1),
		prenom = l.prenom,
		nom = l.nom,
		nom_cle = l.nom_cle,
		race = l.race,
		valide = booleen(l.valide),
		covan = num(l.covan, 0),
		job = (l.job and l.job ~= "NULL") and l.job or nil,
		pv = num(l.pv, nil),
		pvmax = num(l.pvmax, nil),
		armure = num(l.armure, nil),
		armuremax = num(l.armuremax, nil),
		faim = num(l.faim, nil),
		mort = booleen(l.mort),
		nouveau = booleen(l.nouveau),
		armes = json(l.armes, {}),
		munitions = json(l.munitions, {}),
		licences = json(l.licences, {}),
		arrete = num(l.arrete, 0),
		recherche = num(l.recherche, 0),
		recherche_raison = (l.recherche_raison and l.recherche_raison ~= "NULL") and l.recherche_raison or nil,
		modeles = json(l.modeles, {}),
		modele = (l.modele and l.modele ~= "NULL") and l.modele or nil,
		date_creation = num(l.date_creation, os.time()),
		derniere_connexion = num(l.derniere_connexion, nil),
		nom_a_redonner = booleen(l.nom_a_redonner),
	}
end

local function b(v) return v and 1 or 0 end

function ORIGINE.EcrireCompte(c, synchrone)
	DB.Requete([[REPLACE INTO origine_comptes
		(steamid64, nom_steam, rerolls, dernier_slot, reroll_gratuit, event_debloque, event_race,
		 vip_debloque, migration_covan, migration_faite, premiere_connexion)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
		c.steamid64, c.nom_steam, c.rerolls, c.dernier_slot, c.reroll_gratuit, c.event_debloque,
		c.event_race, c.vip_debloque or 0, c.migration_covan, c.migration_faite, c.premiere_connexion,
	}, nil, synchrone)
end

local COLONNES_PERSO = [[(steamid64, slot, prenom, nom, nom_cle, race, valide, covan, job, pv, pvmax,
	armure, armuremax, faim, mort, nouveau, armes, munitions, licences, arrete, recherche,
	recherche_raison, modeles, modele, date_creation, derniere_connexion, nom_a_redonner)]]

local function paramsPerso(p)
	return {
		p.steamid64, p.slot, p.prenom, p.nom, ORIGINE.CleNom(p.prenom, p.nom), p.race, b(p.valide),
		math.floor(p.covan or 0), p.job, p.pv, p.pvmax, p.armure, p.armuremax, p.faim, b(p.mort),
		b(p.nouveau), util.TableToJSON(p.armes or {}), util.TableToJSON(p.munitions or {}),
		util.TableToJSON(p.licences or {}), math.floor(p.arrete or 0), math.floor(p.recherche or 0),
		p.recherche_raison, util.TableToJSON(p.modeles or {}), p.modele, p.date_creation,
		p.derniere_connexion, b(p.nom_a_redonner),
	}
end

function ORIGINE.RequetePerso(p)
	return "REPLACE INTO origine_personnages " .. COLONNES_PERSO ..
		" VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", paramsPerso(p)
end

-- Dernière version écrite de chaque personnage : on n'écrit que ce qui a changé
local derniereEcriture = setmetatable({}, { __mode = "k" })

local function empreinte(params)
	local t = {}
	for i = 1, 27 do t[i] = tostring(params[i]) end
	return table.concat(t, "\31")
end

-- Retourne la requête seulement si le personnage a changé depuis la dernière écriture
function ORIGINE.RequetePersoSiModifie(p)
	local requete, params = ORIGINE.RequetePerso(p)
	local e = empreinte(params)
	if derniereEcriture[p] == e then return nil end
	derniereEcriture[p] = e
	return requete, params
end

function ORIGINE.EcrirePerso(p, synchrone, callback)
	local requete, params = ORIGINE.RequetePersoSiModifie(p)
	if not requete then
		if callback then callback({}) end
		return
	end
	DB.Requete(requete, params, callback, synchrone)
end

function ORIGINE.SupprimerPerso(sid, slot)
	DB.Requete("DELETE FROM origine_personnages WHERE steamid64 = ? AND slot = ?", { sid, slot })
end

---------------------------------------------------------------------------
-- Lecture
---------------------------------------------------------------------------
function ORIGINE.LireCompte(sid, callback)
	DB.Requete("SELECT * FROM origine_comptes WHERE steamid64 = ?", { sid }, function(lignes)
		callback(lignes and lignes[1] and ORIGINE.LigneVersCompte(lignes[1]) or nil)
	end)
end

function ORIGINE.LirePersos(sid, callback)
	DB.Requete("SELECT * FROM origine_personnages WHERE steamid64 = ?", { sid }, function(lignes)
		local persos = {}
		for _, l in ipairs(lignes or {}) do
			local p = ORIGINE.LigneVersPerso(l)
			persos[p.slot] = p
		end
		callback(persos)
	end)
end

-- Nom déjà utilisé par un autre personnage (connecté ou non) ?
function ORIGINE.NomDisponible(prenom, nom, sid, slot, callback)
	DB.Requete("SELECT steamid64, slot FROM origine_personnages WHERE nom_cle = ?",
		{ ORIGINE.CleNom(prenom, nom) }, function(lignes)
		for _, l in ipairs(lignes or {}) do
			if not (l.steamid64 == sid and tonumber(l.slot) == slot) then
				return callback(false)
			end
		end
		callback(true)
	end)
end

-- Covan du joueur dans DarkRP avant la mise en place (transfert sur le slot 1)
local function lireAncienPorteMonnaie(ply, callback)
	local sid, uid = ply:SteamID64(), ply:UniqueID()
	local requete = "SELECT wallet FROM darkrp_player WHERE uid = " .. sid .. " OR uid = " .. uid
	local function fini(lignes)
		local l = istable(lignes) and lignes[1]
		local ancien = l and tonumber(l.wallet) or nil
		-- Un nouveau joueur a juste le montant de départ DarkRP : rien à transférer
		local depart = GAMEMODE and GAMEMODE.Config and GAMEMODE.Config.startingmoney
		if ancien and depart and ancien == depart then ancien = nil end
		callback(ancien)
	end
	if MySQLite and MySQLite.query then
		MySQLite.query(requete, fini, function() callback(nil) end)
	elseif sql.TableExists("darkrp_player") then
		fini(sql.Query(requete))
	else
		callback(nil)
	end
end

-- Charge (ou crée) le compte et les personnages d'un joueur connecté
function ORIGINE.ChargerDonneesJoueur(ply, callback)
	local sid = ply:SteamID64()
	ORIGINE.LireCompte(sid, function(compte)
		if not IsValid(ply) then return end
		local function suite(c)
			c.nom_steam = ORIGINE.NomSteam(ply)
			ply.OrigineCompte = c
			ORIGINE.LirePersos(sid, function(persos)
				if not IsValid(ply) then return end
				ply.OriginePersos = persos
				ply.OrigineDonneesChargees = true
				if callback then callback() end
			end)
		end
		if compte then
			compte.nom_steam = ply:Nick()
			ORIGINE.EcrireCompte(compte)
			return suite(compte)
		end
		-- Première connexion : point de reroll gratuit, reprise des anciens Covan
		local c = {
			steamid64 = sid, nom_steam = ply:Nick(), rerolls = C.RerollsPremiereConnexion,
			dernier_slot = 1, reroll_gratuit = 1, event_debloque = 0, migration_faite = 0,
			premiere_connexion = os.time(),
		}
		lireAncienPorteMonnaie(ply, function(ancien)
			if not IsValid(ply) then return end
			c.migration_covan = ancien
			ORIGINE.EcrireCompte(c)
			suite(c)
		end)
	end)
end

---------------------------------------------------------------------------
-- Accès rapides
---------------------------------------------------------------------------
function ORIGINE.PersoActuel(ply)
	if not IsValid(ply) or not ply.OrigineSlot or not ply.OriginePersos then return nil end
	return ply.OriginePersos[ply.OrigineSlot]
end

-- Clé unique du personnage joué : « steamid64:slot » (pour les autres addons)
function ORIGINE.CleDePersonnage(ply)
	if not IsValid(ply) or not ply.OrigineSlot then return nil end
	return ply:SteamID64() .. ":" .. ply.OrigineSlot
end

function ORIGINE.JoueurParSid(sid)
	local ply = player.GetBySteamID64(sid)
	if IsValid(ply) then return ply end
	return nil
end

function ORIGINE.MontantDepart()
	if C.MontantDepart then return C.MontantDepart end
	local gm = GAMEMODE or GM
	return gm and gm.Config and gm.Config.startingmoney or 0
end

---------------------------------------------------------------------------
-- Armes : ce qui n'est jamais sauvegardé ni mis dans le sac de mort
---------------------------------------------------------------------------
function ORIGINE.ArmesExcluesPour(ply)
	local set = {}
	for _, c in ipairs(C.ArmesExclues) do set[c] = true end
	local job = RPExtraTeams and RPExtraTeams[ply:Team()]
	if job and istable(job.weapons) then
		for _, c in ipairs(job.weapons) do set[c] = true end
	end
	local gm = GAMEMODE
	if gm and gm.Config then
		for _, c in ipairs(gm.Config.DefaultWeapons or {}) do set[c] = true end
		for _, c in ipairs(gm.Config.AdminWeapons or {}) do set[c] = true end
	end
	for _, race in ipairs(C.Races) do
		for _, c in ipairs(race.Mod and race.Mod.Sweps or {}) do set[c] = true end
	end
	hook.Run("origine_ArmesExclues", ply, set)
	return set
end

function ORIGINE.CapturerArmes(ply)
	local exclues = ORIGINE.ArmesExcluesPour(ply)
	local armes = {}
	for _, w in ipairs(ply:GetWeapons()) do
		local c = w:GetClass()
		if not exclues[c] then
			armes[#armes + 1] = { classe = c, clip1 = w:Clip1(), clip2 = w:Clip2() }
		end
	end
	local munitions = {}
	for id, nom in pairs(game.GetAmmoTypes()) do
		local n = ply:GetAmmoCount(id)
		if n > 0 then munitions[nom] = n end
	end
	return armes, munitions
end

---------------------------------------------------------------------------
-- Capture de l'état du personnage joué (sans écrire en base)
---------------------------------------------------------------------------
function ORIGINE.CapturerEtat(ply)
	local p = ORIGINE.PersoActuel(ply)
	if not p or ply.OrigineRestaurationEnCours then return p end

	if ply.getDarkRPVar then
		p.covan = ply:getDarkRPVar("money") or p.covan
		local faim = ply:getDarkRPVar("Energy")
		if faim then p.faim = faim end
		p.licences = { arme = ply:getDarkRPVar("HasGunlicense") and true or false }
	end
	p.job = ORIGINE.CommandeJob(ply:Team()) or p.job

	p.mort = not ply:Alive()
	if ply:Alive() then
		p.pv = ply:Health()
		p.armure = ply:Armor()
		p.armes, p.munitions = ORIGINE.CapturerArmes(ply)
	else
		p.armes, p.munitions = {}, {}
	end
	p.pvmax = ply:GetMaxHealth()
	p.armuremax = ply:GetMaxArmor()

	p.arrete = 0
	if ply.isArrested and ply:isArrested() and ply.OrigineFinArrestation then
		p.arrete = math.max(0, math.ceil(ply.OrigineFinArrestation - CurTime()))
	end
	p.recherche, p.recherche_raison = 0, nil
	if ply.isWanted and ply:isWanted() then
		p.recherche = math.max(1, math.ceil((ply.OrigineFinRecherche or (CurTime() + 120)) - CurTime()))
		p.recherche_raison = ply.getWantedReason and ply:getWantedReason() or nil
	end

	p.modele = ply:GetModel()
	p.nouveau = false
	return p
end

function ORIGINE.SauvegarderJoueur(ply, synchrone)
	local p = ORIGINE.CapturerEtat(ply)
	if p then
		p.derniere_connexion = os.time()
		ORIGINE.EcrirePerso(p, synchrone)
	end
	hook.Run("origine_SauvegardeJoueur", ply, p, synchrone)
end

---------------------------------------------------------------------------
-- Nettoyage du monde (changement de personnage, CK, RPK)
---------------------------------------------------------------------------
function ORIGINE.MarquerEntite(ent, ply)
	if IsValid(ent) and IsValid(ply) then ent.OrigineProprietaire = ply:SteamID64() end
end

local function appartientA(ent, ply, sid)
	if ent.OrigineProprietaire == sid then return true end
	if ent.CPPIGetOwner then
		local ok, o = pcall(ent.CPPIGetOwner, ent)
		if ok and o == ply then return true end
	end
	if ent.Getowning_ent then
		local ok, o = pcall(ent.Getowning_ent, ent)
		if ok and o == ply then return true end
	end
	if ent.SID and ply.SID and ent.SID == ply.SID then return true end
	return false
end

function ORIGINE.NettoyerMonde(ply)
	if not IsValid(ply) then return end
	local sid = ply:SteamID64()
	if ply.keysUnOwnAll then ply:keysUnOwnAll() end
	for _, ent in ipairs(ents.GetAll()) do
		if IsValid(ent) and not ent:IsPlayer() and not ent.OrigineNePasNettoyer
			and not ent:CreatedByMap() and not (ent.isDoor and ent:isDoor())
			and not (ent:IsWeapon() and IsValid(ent:GetOwner()))
			and appartientA(ent, ply, sid) then
			SafeRemoveEntity(ent)
		end
	end
	hook.Run("origine_NettoyageMonde", ply)
end

-- Marque tout ce que le joueur fait apparaître ou jette, pour le nettoyage
local function marqueur(ply, a, b)
	local ent = IsEntity(b) and b or a
	if IsEntity(ent) then ORIGINE.MarquerEntite(ent, ply) end
end
hook.Add("PlayerSpawnedProp", "origine_marque", function(ply, _, ent) ORIGINE.MarquerEntite(ent, ply) end)
hook.Add("PlayerSpawnedSENT", "origine_marque", function(ply, ent) ORIGINE.MarquerEntite(ent, ply) end)
hook.Add("PlayerSpawnedVehicle", "origine_marque", function(ply, ent) ORIGINE.MarquerEntite(ent, ply) end)
hook.Add("PlayerSpawnedNPC", "origine_marque", function(ply, ent) ORIGINE.MarquerEntite(ent, ply) end)
hook.Add("PlayerSpawnedRagdoll", "origine_marque", function(ply, _, ent) ORIGINE.MarquerEntite(ent, ply) end)
hook.Add("PlayerSpawnedEffect", "origine_marque", function(ply, _, ent) ORIGINE.MarquerEntite(ent, ply) end)
hook.Add("playerDroppedMoney", "origine_marque", function(ply, _, ent) ORIGINE.MarquerEntite(ent, ply) end)
hook.Add("onDarkRPWeaponDropped", "origine_marque", function(ply, ent) ORIGINE.MarquerEntite(ent, ply) end)
hook.Add("playerBoughtCustomEntity", "origine_marque", function(ply, _, ent) ORIGINE.MarquerEntite(ent, ply) end)
hook.Add("playerBoughtShipment", "origine_marque", function(ply, _, ent) ORIGINE.MarquerEntite(ent, ply) end)
hook.Add("playerBoughtPistol", "origine_marque", function(ply, _, ent) ORIGINE.MarquerEntite(ent, ply) end)
hook.Add("playerBoughtFood", "origine_marque", function(ply, _, ent) marqueur(ply, nil, ent) end)
hook.Add("playerBoughtVehicle", "origine_marque", function(ply, _, ent) ORIGINE.MarquerEntite(ent, ply) end)

---------------------------------------------------------------------------
-- Chargement d'un personnage
---------------------------------------------------------------------------
function ORIGINE.AppliquerIdentite(ply, p)
	ply:SetNW2Int("origine_slot", p.slot)
	ply:SetNW2String("origine_prenom", p.prenom)
	ply:SetNW2String("origine_nom", p.nom)
	ply:SetNW2String("origine_race", p.race)
	if ply.setDarkRPVar then ply:setDarkRPVar("rpname", p.prenom .. " " .. p.nom) end
end

function ORIGINE.EffacerIdentite(ply)
	ply:SetNW2Int("origine_slot", 0)
	ply:SetNW2String("origine_prenom", "")
	ply:SetNW2String("origine_nom", "")
	ply:SetNW2String("origine_race", "")
	if ply.setDarkRPVar then ply:setDarkRPVar("rpname", ply:Nick()) end
end

function ORIGINE.ChargerPerso(ply, slot)
	local p = ply.OriginePersos and ply.OriginePersos[slot]
	if not p or not p.valide then return false end

	ORIGINE.SortirMenu(ply)
	ply.OrigineSlot = slot
	ply.OrigineRestaurationEnCours = true
	ply.OrigineRestaurer = p

	ORIGINE.AppliquerIdentite(ply, p)
	if ply.setDarkRPVar then ply:setDarkRPVar("money", math.floor(p.covan or 0)) end

	local compte = ply.OrigineCompte
	compte.dernier_slot = slot
	ORIGINE.EcrireCompte(compte)

	local equipe = ORIGINE.EquipePourPerso(ply, p)
	p.job = ORIGINE.CommandeJob(equipe) or p.job
	if equipe and ply:Team() ~= equipe and ply.changeTeam then
		ply:changeTeam(equipe, true, true)
	end
	ply:Spawn() -- toujours au point de spawn, jamais à la dernière position
	return true
end

-- Appelé juste après le spawn qui suit ChargerPerso
function ORIGINE.Restaurer(ply, p)
	ORIGINE.AppliquerRace(ply)

	if p.nouveau or p.mort then
		ply:SetHealth(ply:GetMaxHealth())
		if ply.setSelfDarkRPVar and ply:getDarkRPVar("Energy") then ply:setSelfDarkRPVar("Energy", 100) end
	else
		local max = ply:GetMaxHealth()
		ply:SetHealth(math.Clamp(math.floor(p.pv or max), 1, max))
		ply:SetArmor(math.Clamp(math.floor(p.armure or 0), 0, ply:GetMaxArmor()))
		if ply.setSelfDarkRPVar and p.faim and ply:getDarkRPVar("Energy") then
			ply:setSelfDarkRPVar("Energy", math.Clamp(p.faim, 0, 100))
		end

		for _, a in ipairs(p.armes or {}) do
			if isstring(a.classe) and not ply:HasWeapon(a.classe) then
				local w = ply:Give(a.classe, true)
				if IsValid(w) then
					if a.clip1 and a.clip1 >= 0 then w:SetClip1(a.clip1) end
					if a.clip2 and a.clip2 >= 0 then w:SetClip2(a.clip2) end
				end
			end
		end
		if next(p.munitions or {}) then
			ply:RemoveAllAmmo()
			for nom, n in pairs(p.munitions) do ply:SetAmmo(n, nom) end
		end

		if ply.setDarkRPVar then
			ply:setDarkRPVar("HasGunlicense", (p.licences and p.licences.arme) and true or nil)
		end
		if (p.arrete or 0) > 0 and ply.arrest then
			ply:arrest(p.arrete)
		end
		if (p.recherche or 0) > 0 and ply.wanted then
			ply:wanted(nil, p.recherche_raison or "", p.recherche)
			ply.OrigineFinRecherche = CurTime() + p.recherche
		end
	end

	p.nouveau, p.mort = false, false
	p.derniere_connexion = os.time()
	ply.OrigineRestaurationEnCours = nil
	ORIGINE.EcrirePerso(p)
	hook.Run("origine_PersonnageCharge", ply, p)
end

hook.Add("PlayerSpawn", "origine_restauration", function(ply)
	timer.Simple(0, function()
		if not IsValid(ply) then return end
		if ORIGINE.EnMenu(ply) then
			ORIGINE.AppliquerEtatMenu(ply)
			return
		end
		ORIGINE.CapturerBasePV(ply)
		local p = ply.OrigineRestaurer
		if p then
			ply.OrigineRestaurer = nil
			ORIGINE.Restaurer(ply, p)
		elseif ORIGINE.PersoActuel(ply) then
			ORIGINE.AppliquerRace(ply)
		end
		-- Mains vides à l'apparition
		local arme = ORIGINE.Config.ArmeAuSpawn
		if arme and arme ~= "" and ply:HasWeapon(arme) then ply:SelectWeapon(arme) end
	end)
end)

---------------------------------------------------------------------------
-- Quitter le personnage : sauvegarde, nettoyage, retour au menu
---------------------------------------------------------------------------
function ORIGINE.QuitterPerso(ply, options)
	options = options or {}
	local p = ORIGINE.PersoActuel(ply)
	if p then
		if not options.sansSauvegarde then
			ORIGINE.CapturerEtat(ply)
			p.derniere_connexion = os.time()
			ORIGINE.EcrirePerso(p)
		end
		hook.Run("origine_PersonnageDecharge", ply, p, options)
		ORIGINE.NettoyerMonde(ply)
	end
	ply.OrigineSlot = nil
	ply.OrigineRestaurer = nil
	ply.OrigineRestaurationEnCours = nil
	ORIGINE.EntrerMenu(ply, options.slot, options.message)
end

---------------------------------------------------------------------------
-- Rerolls (API publique pour boutique, events…)
---------------------------------------------------------------------------
-- ORIGINE.AjouterRerolls("7656119…", 2)   (nombre négatif pour retirer)
function ORIGINE.AjouterRerolls(steamid64, nombre, callback)
	nombre = math.floor(tonumber(nombre) or 0)
	steamid64 = tostring(steamid64)
	local ply = ORIGINE.JoueurParSid(steamid64)
	if ply and ply.OrigineCompte then
		local c = ply.OrigineCompte
		c.rerolls = math.max(0, c.rerolls + nombre)
		ORIGINE.EcrireCompte(c)
		if ORIGINE.EnMenu(ply) then ORIGINE.EnvoyerMenu(ply) end
		if callback then callback(c.rerolls) end
		return
	end
	ORIGINE.LireCompte(steamid64, function(c)
		if not c then
			c = {
				steamid64 = steamid64, rerolls = 0, dernier_slot = 1, reroll_gratuit = 0,
				event_debloque = 0, migration_faite = 0, premiere_connexion = os.time(),
			}
		end
		c.rerolls = math.max(0, c.rerolls + nombre)
		ORIGINE.EcrireCompte(c)
		if callback then callback(c.rerolls) end
	end)
end

---------------------------------------------------------------------------
-- Connexion / déconnexion
---------------------------------------------------------------------------
hook.Add("PlayerInitialSpawn", "origine_connexion", function(ply)
	ply:SetNW2Bool("origine_enmenu", true)
	timer.Simple(0, function()
		if not IsValid(ply) then return end
		ORIGINE.ChargerDonneesJoueur(ply, function()
			if IsValid(ply) then ORIGINE.EntrerMenu(ply) end
		end)
	end)
end)

hook.Add("PlayerDisconnected", "origine_deconnexion", function(ply)
	if ORIGINE.PersoActuel(ply) then
		ORIGINE.SauvegarderJoueur(ply, true)
		hook.Run("origine_PersonnageDecharge", ply, ORIGINE.PersoActuel(ply), { deconnexion = true })
	end
end)
