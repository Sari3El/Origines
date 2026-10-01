--[[-----------------------------------------------------------------------
	Origine du monde — menu personnage (serveur)

	Pendant le menu, le joueur est dans le job caché, figé, invisible, en
	godmode et sans collisions. Le chat OOC reste autorisé.
	Le serveur décide de tout : le client n'envoie que des demandes.
-------------------------------------------------------------------------]]

local C = ORIGINE.Config

util.AddNetworkString("origine_menu")
util.AddNetworkString("origine_menu_fermer")
util.AddNetworkString("origine_menu_tirage")
util.AddNetworkString("origine_menu_erreur")

---------------------------------------------------------------------------
-- État « menu »
---------------------------------------------------------------------------
function ORIGINE.AppliquerEtatMenu(ply)
	if not IsValid(ply) then return end
	ply:StripWeapons()
	ply:Freeze(true)
	ply:GodEnable()
	ply:SetNoDraw(true)
	ply:DrawShadow(false)
	ply:SetNotSolid(true)
	ply:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
	ply:SetAvoidPlayers(false)
	if ply:FlashlightIsOn() then ply:Flashlight(false) end
end

function ORIGINE.SortirMenu(ply)
	ply:SetNW2Bool("origine_enmenu", false)
	ply:Freeze(false)
	ply:GodDisable()
	ply:SetNoDraw(false)
	ply:DrawShadow(true)
	ply:SetNotSolid(false)
	ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
	ply:SetAvoidPlayers(true)
	net.Start("origine_menu_fermer")
	net.Send(ply)
end

function ORIGINE.EntrerMenu(ply, slotSelection, message)
	if not IsValid(ply) then return end
	ply.OrigineSlot = nil
	ply:SetNW2Bool("origine_enmenu", true)
	ORIGINE.EffacerIdentite(ply)
	if ORIGINE.EquipeSelection and ply:Team() ~= ORIGINE.EquipeSelection and ply.changeTeam then
		ply:changeTeam(ORIGINE.EquipeSelection, true, true)
	end
	if not ply:Alive() then ply:Spawn() end
	ORIGINE.AppliquerEtatMenu(ply)
	ORIGINE.EnvoyerMenu(ply, slotSelection, message)
end

---------------------------------------------------------------------------
-- Données envoyées au menu
---------------------------------------------------------------------------
local function resumePerso(p)
	return {
		prenom = p.prenom,
		nom = p.nom,
		race = p.race,
		job = p.job and ORIGINE.NomJob(p.job) or nil,
		modele = p.modele,
		derniere = p.derniere_connexion,
		valide = p.valide,
		nom_a_redonner = p.nom_a_redonner,
	}
end

function ORIGINE.EnvoyerMenu(ply, slotSelection, message)
	if not IsValid(ply) then return end
	if not ply.OrigineClientPret or not ply.OrigineDonneesChargees then
		ply.OrigineMenuEnAttente = { slotSelection, message }
		return
	end
	local compte = ply.OrigineCompte
	local d = {
		rerolls = compte.rerolls,
		selection = slotSelection or compte.dernier_slot or 1,
		message = message,
		slots = {},
	}
	for s = 1, ORIGINE.NB_SLOTS do
		local ok, raison = ORIGINE.SlotAccessible(ply, s, compte)
		local p = ply.OriginePersos[s]
		d.slots[s] = {
			acces = ok and true or false,
			raison = raison,
			event_race = (s == ORIGINE.SLOT_EVENT) and compte.event_race or nil,
			perso = p and resumePerso(p) or nil,
		}
	end
	net.Start("origine_menu")
		net.WriteTable(d)
	net.Send(ply)
end

local function erreur(ply, texte)
	net.Start("origine_menu_erreur")
		net.WriteString(texte)
	net.Send(ply)
end

-- Le client a chargé son Lua : on peut lui envoyer le menu
ORIGINE.NetRecevoir("origine_pret", function(ply)
	if ply.OrigineClientPret then return end
	ply.OrigineClientPret = true
	local attente = ply.OrigineMenuEnAttente
	ply.OrigineMenuEnAttente = nil
	if ORIGINE.EnMenu(ply) and ply.OrigineDonneesChargees then
		ORIGINE.EnvoyerMenu(ply, attente and attente[1], attente and attente[2])
	end
end, 2)

---------------------------------------------------------------------------
-- Tirage de race
---------------------------------------------------------------------------
local function annoncerTirage(p)
	local race = ORIGINE.Race(p.race)
	local rarete = ORIGINE.RareteDeRace(p.race)
	if not race or not rarete then return end
	ORIGINE.Annoncer(rarete.Couleur, p.prenom .. " " .. p.nom .. " a hérité de : " .. race.Nom .. " (" .. rarete.Nom .. ")")
end

-- Le tirage est décidé et enregistré AVANT l'animation
local function tirer(ply, p, estReroll)
	local ancienne = p.race
	p.race = ORIGINE.TirerRace()
	ORIGINE.EcrirePerso(p)
	ORIGINE.Historique.Ajouter({
		type = estReroll and "reroll" or "tirage",
		cible_sid = p.steamid64, cible_slot = p.slot, cible_nom = p.prenom .. " " .. p.nom,
		avant = ancienne and { race = ancienne } or nil, apres = { race = p.race },
	})
	net.Start("origine_menu_tirage")
		net.WriteUInt(p.slot, 4)
		net.WriteString(p.race)
		net.WriteBool(estReroll)
	net.Send(ply)
	local copie = { prenom = p.prenom, nom = p.nom, race = p.race }
	timer.Simple(C.DureeAnimationTirage, function() annoncerTirage(copie) end)
	hook.Run("origine_Tirage", ply, p, estReroll, ancienne)
end

---------------------------------------------------------------------------
-- Demandes du menu
---------------------------------------------------------------------------
local function enMenuPret(ply)
	return ORIGINE.EnMenu(ply) and ply.OrigineDonneesChargees and not ply.OrigineOperation
end

local function slotValide(slot)
	return slot >= 1 and slot <= ORIGINE.NB_SLOTS
end

local function nouveauPerso(ply, slot, prenom, nom, race)
	return {
		steamid64 = ply:SteamID64(), slot = slot, prenom = prenom, nom = nom, race = race,
		valide = false, covan = 0, job = nil, mort = false, nouveau = true,
		armes = {}, munitions = {}, licences = {}, arrete = 0, recherche = 0, modeles = {},
		date_creation = os.time(), derniere_connexion = os.time(), nom_a_redonner = false,
	}
end

-- Finalise un personnage : montant de départ, job par défaut, PV max, faim 100 %
local function finaliser(ply, p)
	local compte = ply.OrigineCompte
	p.valide = true
	p.nouveau = true
	p.covan = ORIGINE.MontantDepart()
	if p.slot == 1 and tonumber(compte.migration_faite) ~= 1 then
		-- Mise en place : les anciens Covan DarkRP sont transférés sur le slot 1
		if compte.migration_covan then p.covan = compte.migration_covan end
		compte.migration_faite = 1
		ORIGINE.EcrireCompte(compte)
	end
	p.job = ORIGINE.CommandeJob(ORIGINE.EquipeParDefaut())
	p.pv, p.armure, p.faim = nil, nil, 100
	ORIGINE.EcrirePerso(p)
end

-- Création : prénom + nom, puis tirage (ou race fixée / choisie)
ORIGINE.NetRecevoir("origine_menu_creer", function(ply)
	local slot = net.ReadUInt(4)
	local prenom = string.Trim(net.ReadString())
	local nom = string.Trim(net.ReadString())
	local raceChoisie = net.ReadString()
	if not enMenuPret(ply) or not slotValide(slot) then return end

	local compte = ply.OrigineCompte
	local ok, raison = ORIGINE.SlotAccessible(ply, slot, compte)
	if not ok then return erreur(ply, raison or "Slot verrouillé.") end
	if ply.OriginePersos[slot] then return erreur(ply, "Ce slot contient déjà un personnage.") end

	local valide, err = ORIGINE.ValiderNom(prenom, nom)
	if not valide then return erreur(ply, err) end
	prenom, nom = ORIGINE.Capitaliser(prenom), ORIGINE.Capitaliser(nom)

	local race
	if slot == ORIGINE.SLOT_EVENT then
		race = compte.event_race
		if not ORIGINE.Race(race) then return erreur(ply, "Le staff n'a pas encore fixé la race de ce slot.") end
	elseif slot == ORIGINE.SLOT_STAFF then
		race = raceChoisie
		if not ORIGINE.Race(race) then return erreur(ply, "Choisissez une race.") end
	end

	ply.OrigineOperation = true
	ORIGINE.NomDisponible(prenom, nom, ply:SteamID64(), slot, function(libre)
		if not IsValid(ply) then return end
		ply.OrigineOperation = nil
		if not libre then return erreur(ply, "Ce nom est déjà pris.") end
		if ply.OriginePersos[slot] then return end

		local p = nouveauPerso(ply, slot, prenom, nom, race)
		ply.OriginePersos[slot] = p
		hook.Run("origine_PersonnageCree", ply, p)
		if race then
			-- Slots EVENT et Staff : pas de tirage, le personnage est prêt
			finaliser(ply, p)
			ORIGINE.ChargerPerso(ply, slot)
		else
			tirer(ply, p, false)
			ORIGINE.EnvoyerMenu(ply, slot)
		end
	end)
end, 2)

-- Validation après le tirage
ORIGINE.NetRecevoir("origine_menu_valider", function(ply)
	local slot = net.ReadUInt(4)
	if not enMenuPret(ply) or not slotValide(slot) then return end
	local p = ply.OriginePersos[slot]
	if not p or p.valide then return end
	if not ORIGINE.SlotAccessible(ply, slot, ply.OrigineCompte) then return end
	finaliser(ply, p)
	ORIGINE.ChargerPerso(ply, slot)
end, 2)

-- Reroll (création ou personnage existant) : ne change que la race
ORIGINE.NetRecevoir("origine_menu_reroll", function(ply)
	local slot = net.ReadUInt(4)
	if not enMenuPret(ply) or not slotValide(slot) then return end
	if slot == ORIGINE.SLOT_EVENT or slot == ORIGINE.SLOT_STAFF then
		return erreur(ply, "Ce slot n'a pas de tirage.")
	end
	local compte = ply.OrigineCompte
	local p = ply.OriginePersos[slot]
	if not p then return end
	if not ORIGINE.SlotAccessible(ply, slot, compte) then return end
	if compte.rerolls <= 0 then return erreur(ply, "Vous n'avez plus de point de reroll.") end

	compte.rerolls = compte.rerolls - 1
	ORIGINE.EcrireCompte(compte)
	tirer(ply, p, true)
	ORIGINE.EnvoyerMenu(ply, slot)
end, 2)

-- Jouer un personnage existant
ORIGINE.NetRecevoir("origine_menu_jouer", function(ply)
	local slot = net.ReadUInt(4)
	if not enMenuPret(ply) or not slotValide(slot) then return end
	local p = ply.OriginePersos[slot]
	if not p or not p.valide then return end
	local ok, raison = ORIGINE.SlotAccessible(ply, slot, ply.OrigineCompte)
	if not ok then return erreur(ply, raison or "Slot verrouillé.") end
	if p.nom_a_redonner then return erreur(ply, "Ce personnage doit recevoir un nouveau nom.") end
	ORIGINE.ChargerPerso(ply, slot)
end, 2)

-- Nouveau nom après un CK ou un RPK
ORIGINE.NetRecevoir("origine_menu_renommer", function(ply)
	local slot = net.ReadUInt(4)
	local prenom = string.Trim(net.ReadString())
	local nom = string.Trim(net.ReadString())
	if not enMenuPret(ply) or not slotValide(slot) then return end
	local p = ply.OriginePersos[slot]
	if not p or not p.nom_a_redonner then return end
	local valide, err = ORIGINE.ValiderNom(prenom, nom)
	if not valide then return erreur(ply, err) end
	prenom, nom = ORIGINE.Capitaliser(prenom), ORIGINE.Capitaliser(nom)

	ply.OrigineOperation = true
	ORIGINE.NomDisponible(prenom, nom, ply:SteamID64(), slot, function(libre)
		if not IsValid(ply) then return end
		ply.OrigineOperation = nil
		if not libre then return erreur(ply, "Ce nom est déjà pris.") end
		local ancien = p.prenom .. " " .. p.nom
		p.prenom, p.nom, p.nom_a_redonner = prenom, nom, false
		ORIGINE.EcrirePerso(p)
		hook.Run("origine_PersonnageRenomme", ply, p, ancien)
		ORIGINE.EnvoyerMenu(ply, slot)
	end)
end, 2)

---------------------------------------------------------------------------
-- !perso : changer de personnage
---------------------------------------------------------------------------
local function duree(s)
	s = math.ceil(s)
	if s >= 60 then return math.floor(s / 60) .. " min " .. (s % 60) .. " s" end
	return s .. " s"
end

function ORIGINE.DemanderChangement(ply)
	if not IsValid(ply) then return end
	if ORIGINE.EnMenu(ply) then
		if ply.OrigineDonneesChargees then ORIGINE.EnvoyerMenu(ply) end
		return
	end
	if not ORIGINE.PersoActuel(ply) then return end
	local maintenant = CurTime()
	if ply.OrigineDernierChangement and maintenant - ply.OrigineDernierChangement < C.DelaiChangement then
		return ORIGINE.Notifier(ply, "Changement possible dans " ..
			duree(C.DelaiChangement - (maintenant - ply.OrigineDernierChangement)) .. ".", "erreur")
	end
	if ply.OrigineDernierCoup and maintenant - ply.OrigineDernierCoup < C.DelaiApresCoup then
		return ORIGINE.Notifier(ply, "Vous avez été touché récemment : attendez " ..
			duree(C.DelaiApresCoup - (maintenant - ply.OrigineDernierCoup)) .. ".", "erreur")
	end
	if not ply:Alive() then return ORIGINE.Notifier(ply, "Impossible de changer de personnage en étant mort.", "erreur") end
	if ply.isArrested and ply:isArrested() then return ORIGINE.Notifier(ply, "Impossible de changer de personnage en étant arrêté.", "erreur") end
	if ply.isWanted and ply:isWanted() then return ORIGINE.Notifier(ply, "Impossible de changer de personnage en étant recherché.", "erreur") end
	if C.EstMenotte(ply) then return ORIGINE.Notifier(ply, "Impossible de changer de personnage en étant menotté.", "erreur") end
	-- Autres addons (mise à terre, ligoté…) : return false, "raison"
	local autorise, raison = hook.Run("origine_PeutChangerPerso", ply)
	if autorise == false then return ORIGINE.Notifier(ply, raison or "Impossible de changer de personnage maintenant.", "erreur") end

	ply.OrigineDernierChangement = maintenant
	ORIGINE.QuitterPerso(ply)
end

concommand.Add("origine_perso", function(ply)
	if IsValid(ply) then ORIGINE.DemanderChangement(ply) end
end)

hook.Add("PlayerSay", "origine_menu", function(ply, texte)
	local cmd = string.lower(string.Trim(texte))
	if cmd == "!perso" or cmd == "/perso" then
		ORIGINE.DemanderChangement(ply)
		return ""
	end
	if ORIGINE.EnMenu(ply) then
		for _, prefixe in ipairs(C.ChatAutoriseMenu) do
			if string.sub(cmd, 1, #prefixe) == prefixe then return end
		end
		ORIGINE.Notifier(ply, "Pendant le menu, seul le chat OOC (//) est disponible.", "erreur")
		return ""
	end
end)

---------------------------------------------------------------------------
-- Rien n'est possible sans personnage chargé
---------------------------------------------------------------------------
local function bloque(ply) if ORIGINE.EnMenu(ply) then return false end end
for _, h in ipairs({
	"PlayerSpawnProp", "PlayerSpawnObject", "PlayerSpawnSENT", "PlayerSpawnSWEP", "PlayerGiveSWEP",
	"PlayerSpawnNPC", "PlayerSpawnVehicle", "PlayerSpawnRagdoll", "PlayerSpawnEffect",
	"PlayerNoClip", "PlayerCanPickupItem", "PlayerUse", "CanPlayerSuicide", "CanTool", "PhysgunPickup",
}) do
	hook.Add(h, "origine_menu", bloque)
end

hook.Add("PlayerShouldTakeDamage", "origine_menu", function(ply)
	if ORIGINE.EnMenu(ply) then return false end
end)

hook.Add("PlayerLoadout", "origine_menu", function(ply)
	if ORIGINE.EnMenu(ply) then return true end
end)

---------------------------------------------------------------------------
-- Slots VIP / Staff / EVENT : verrouillage si le rang est perdu
---------------------------------------------------------------------------
function ORIGINE.VerifierSlot(ply)
	if not IsValid(ply) or not ply.OrigineCompte then return end
	if ORIGINE.EnMenu(ply) then
		if ply.OrigineDonneesChargees and ply.OrigineClientPret then ORIGINE.EnvoyerMenu(ply) end
		return
	end
	local slot = ply.OrigineSlot
	if not slot then return end
	local ok, raison = ORIGINE.SlotAccessible(ply, slot, ply.OrigineCompte)
	if not ok then
		ORIGINE.QuitterPerso(ply, { message = "Ce slot est maintenant verrouillé : " .. (raison or "") .. "." })
	end
end

timer.Create("origine_verif_slots", C.VerificationGroupes, 0, function()
	for _, ply in ipairs(player.GetAll()) do
		if not ORIGINE.EnMenu(ply) then ORIGINE.VerifierSlot(ply) end
	end
end)

hook.Add("CAMI.PlayerUsergroupChanged", "origine_slots", function(ply)
	timer.Simple(0.5, function() ORIGINE.VerifierSlot(ply) end)
end)
