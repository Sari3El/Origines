--[[-----------------------------------------------------------------------
	Origine du monde — armes wOS de base (partagé)

	Les 4 armes sont des copies de sabres wOS ALCS (lua/weapons/) : un manche
	simple, une lame invisible qui garde sa portée, aucun effet de sabre laser.
	Ce fichier leur ajoute ce qui est commun :
	  - le type de lame « Invisible » (enregistré ici, voir LISEZMOI.txt) ;
	  - les listes de la Lame du Mage, construites depuis wOS (pouvoirs absents ignorés) ;
	  - SWEP:OrigineCooldowns() pour le sélecteur d'armes (cooldown du pouvoir choisi) ;
	  - les liens avec les autres addons Origine (races, inventaire).
	Les réglages de chaque arme sont dans son fichier lua/weapons/weapon_origine_*.lua.
-------------------------------------------------------------------------]]

ORIGINE = ORIGINE or {}
ORIGINE.Armes = ORIGINE.Armes or {}
local A = ORIGINE.Armes

-- Les 4 armes (classe -> faction)
A.Classes = {
	weapon_origine_nuit = "Créatures de la nuit",
	weapon_origine_empire = "Empire",
	weapon_origine_consortium = "Consortium",
	weapon_origine_mage = "Mage",
}

-- Armes dont les pouvoirs offensifs comptent comme de la magie (résistance du Runiste)
A.Magiques = { weapon_origine_mage = true }

-- Ordre d'affichage des pouvoirs du Mage : pouvoirs de base, puis Dark Ascension, puis Icefuse.
-- Tout autre pouvoir présent sur le serveur est ajouté à la fin (ordre alphabétique).
A.OrdrePouvoirs = {
	-- ALCS
	"Force Leap", "Charge", "Force Absorb", "Saber Throw", "Force Heal", "Group Heal", "Cloak",
	"Force Reflect", "Rage", "Shadow Strike", "Force Pull", "Force Push", "Lightning Strike",
	"Advanced Cloak", "Force Lightning", "Force Combust", "Force Repulse", "Storm",
	"Meditate", "Channel Hatred",
	-- Dark Ascension
	"Overdrive Beam", "Lightning Stream", "Burn Out", "Vitriolic Discharge", "Crippling Slam",
	"Blood Sacrifice", "Energetic Shell", "Diamond Storm", "Attract",
	-- Icefuse
	"Force Blind", "Adrenaline", "Force Slow", "Force Stasis", "Group Pull", "Group Push",
	"Group Lightning", "Electric Judgement", "Force Whirlwind", "Force Breach", "Teleport",
	"Destruction", "Force Choke", "Group Choke", "Saber Barrier",
}
A.OrdreUltimes = { "Kyber Slam", "Sonic Discharge", "Lightning Coil" }

-- Liste ordonnée : d'abord l'ordre connu, puis ce que wOS a en plus.
-- disponibles = table wOS (nom -> données) ou nil (wOS pas encore chargé : liste connue complète,
-- wOS ignore ensuite lui-même les noms absents)
local function ordonner(ordre, disponibles)
	if not istable(disponibles) or next(disponibles) == nil then return table.Copy(ordre) end
	local liste, vus = {}, {}
	for _, nom in ipairs(ordre) do
		if disponibles[nom] then
			liste[#liste + 1] = nom
			vus[nom] = true
		end
	end
	local autres = {}
	for nom in pairs(disponibles) do
		if isstring(nom) and not vus[nom] then autres[#autres + 1] = nom end
	end
	table.sort(autres)
	for _, nom in ipairs(autres) do liste[#liste + 1] = nom end
	return liste
end

function A.TousLesPouvoirs()
	return ordonner(A.OrdrePouvoirs, wOS and wOS.AvailablePowers)
end

function A.TousLesUltimes()
	return ordonner(A.OrdreUltimes, wOS and wOS.AvailableDevestators)
end

---------------------------------------------------------------------------
-- Réglages communs appliqués à chaque arme (appelé en bas de chaque fichier d'arme)
---------------------------------------------------------------------------
function A.Preparer(SWEP)
	-- Sélecteur d'armes Origine : pas d'icône de sabre laser, seulement le nom
	SWEP.OrigineSansIcone = true

	-- Cooldown sous la carte du sélecteur : wOS garde le temps restant du pouvoir
	-- sélectionné dans GetForceCooldown() (en secondes), et sa durée dans .cooldown
	function SWEP:OrigineCooldowns()
		if not self.GetForceCooldown then return nil end
		local reste = tonumber(self:GetForceCooldown()) or 0
		if reste <= 0 then return {} end
		local duree = reste
		local ok, pouvoir = pcall(function() return self:GetActiveForcePowerType(self:GetForceType()) end)
		if ok and istable(pouvoir) and tonumber(pouvoir.cooldown) then
			duree = math.max(reste, tonumber(pouvoir.cooldown))
		end
		return { primaire = { fin = CurTime() + reste, duree = duree } }
	end
end

-- Lame du Mage : tous les pouvoirs et tous les ultimes installés sur le serveur.
-- SWEP:Initialize n'est PAS remplacé : c'est celui de wOS qui prépare la jauge de Force et les
-- pouvoirs de l'arme (le remplacer privait la Lame du Mage de Force et de choix de pouvoir).
-- Les listes de la classe sont remises à jour quand wOS a fini de charger (majMage).
function A.PreparerMage(SWEP)
	A.Preparer(SWEP)
	SWEP.ForcePowerList = A.TousLesPouvoirs()
	SWEP.DevestatorList = A.TousLesUltimes()
end

-- Quand wOS a fini de charger ses pouvoirs, la classe de la Lame du Mage est mise à jour
local function majMage()
	local w = weapons.GetStored("weapon_origine_mage")
	if not w then return end
	w.ForcePowerList = A.TousLesPouvoirs()
	w.DevestatorList = A.TousLesUltimes()
end

---------------------------------------------------------------------------
-- Type de lame « Invisible » : aucun matériau visible, ni lueur, ni particule, ni traînée.
-- La longueur (SWEP.UseLength) reste normale : la portée et les touches ne changent pas.
---------------------------------------------------------------------------
A.Lame = {
	Name = "Invisible",
	InnerMaterial = "origine_armes/lame_invisible",
	EnvelopeMaterial = "",
	UseParticle = false,
	DrawTrail = false,
	QuillonParticle = false,
	QuillonInnerMaterial = "",
	QuillonEnvelopeMaterial = "",
}

function A.EnregistrerLame()
	local base = wOS and wOS.ALCS and wOS.ALCS.LightsaberBase
	if not (base and base.AddBlade) then return false end
	if base.Blades and base.Blades[A.Lame.Name] then return true end
	base:AddBlade(table.Copy(A.Lame))
	return true
end

local function apresWOS()
	A.EnregistrerLame()
	majMage()
end
hook.Add("wOS.ALCS.OnLoaded", "origine_armes", apresWOS)
hook.Add("wOS.ALCS.PostLoaded", "origine_armes", apresWOS)
hook.Add("InitPostEntity", "origine_armes", apresWOS)
hook.Add("Initialize", "origine_armes", apresWOS)

---------------------------------------------------------------------------
-- Inventaire Origine : les 4 armes peuvent être rangées ; « Équiper » les redonne
---------------------------------------------------------------------------
if ORIGINE.Inv and ORIGINE.Inv.Autoriser then
	for classe in pairs(A.Classes) do ORIGINE.Inv.Autoriser(classe) end
end

---------------------------------------------------------------------------
-- Serveur : pouvoirs utilisés (pour les races) et catégorie « magie »
---------------------------------------------------------------------------
if SERVER then
	-- Dernier pouvoir utilisé par un joueur (ne bloque rien : renvoie nil)
	hook.Add("wOS.ALCS.CanUseForcepower", "origine_armes_suivi", function(ply)
		if IsValid(ply) then ply.OrigineDernierPouvoir = CurTime() end
	end)

	-- origine_personnages (sv_races) : les pouvoirs offensifs du Mage sont de la magie.
	-- Les pouvoirs wOS infligent leurs dégâts avec le joueur comme « inflicteur »,
	-- alors que les coups de lame passent par l'arme : c'est ce qui les distingue.
	hook.Add("origine_CategorieDegats", "origine_armes", function(dmg, attaquant)
		if not (IsValid(attaquant) and attaquant:IsPlayer()) then return end
		local w = attaquant:GetActiveWeapon()
		if not (IsValid(w) and A.Magiques[w:GetClass()]) then return end
		local infl = dmg:GetInflictor()
		local parPouvoir = infl == attaquant or (attaquant.OrigineDernierPouvoir or 0) + 0.6 > CurTime()
		if parPouvoir then return "magie" end
	end)
end
