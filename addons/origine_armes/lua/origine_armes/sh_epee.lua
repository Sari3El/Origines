--[[-----------------------------------------------------------------------
	Origine du monde — les armes wOS se comportent comme des épées (partagé)

	Les armes Origine sont des sabres wOS ALCS. Ce fichier retire ce qui
	reste du sabre laser, sans modifier les fichiers (chiffrés) de wOS :
	  1. les sons de sabre laser (allumage, bourdonnement, balancement,
	     impacts, chocs entre lames) : coupés ;
	  2. les traces de brûlure et les étincelles quand la lame touche un mur :
	     retirées ;
	  3. les dégâts au simple contact de la lame (quelqu'un qui marche dans
	     la lame immobile, ou la lame qui le traverse quand on se tourne) :
	     seuls les vrais coups font des dégâts.
	Les sons des pouvoirs (saut de Force, éclairs du Mage...) sont gardés.
-------------------------------------------------------------------------]]

ORIGINE = ORIGINE or {}
ORIGINE.Armes = ORIGINE.Armes or {}
local A = ORIGINE.Armes

A.Epee = A.Epee or {}
local E = A.Epee

-- Sons coupés : chemins qui commencent par l'un de ces préfixes (en minuscules)
E.SonsCoupes = {
	"lightsaber/saber",      -- saber_on, saber_off, saber_loop, saber_swing, saber_hit, saber_hit_laser...
	"lightsaber/darksaber",
	"lightsaber/clash",
	"lightsaber/block",
}
-- Effets d'impact de lame retirés (étincelles) et décalcomanies (brûlures)
E.EffetsCoupes = { stunstickimpact = true, manhacksparks = true, sparks = true, rb655_saber_underwater = true }
E.DecalsCoupes = { fadingscorch = true, lsscorch = true, scorch = true }
-- Distance autour d'un porteur d'arme Origine dans laquelle un son ou un effet
-- de sabre est considéré comme venant de son arme (lame de 42 + le bras)
E.Portee = 110
-- Durée pendant laquelle la lame fait des dégâts après un clic d'attaque (secondes)
E.DureeCoup = 0.9

---------------------------------------------------------------------------
-- Outils
---------------------------------------------------------------------------
function A.EstArme(w)
	return IsValid(w) and w.GetClass ~= nil and A.Classes[w:GetClass()] ~= nil
end

function A.PorteArme(ply)
	return IsValid(ply) and ply.IsPlayer ~= nil and ply:IsPlayer() and A.EstArme(ply:GetActiveWeapon())
end

-- Un porteur d'arme Origine est-il près de cette position ?
function A.ArmeProche(pos)
	if not pos then return false end
	local portee2 = E.Portee * E.Portee
	for _, ply in ipairs(player.GetAll()) do
		if A.PorteArme(ply) and ply:GetPos():DistToSqr(pos) <= portee2 then return true end
	end
	return false
end

local function nettoyer(nom)
	if not isstring(nom) then return nil end
	-- Les sons peuvent commencer par des caractères spéciaux du moteur (^ ) * # @ < > ! ?)
	nom = string.lower(string.gsub(nom, "\\", "/"))
	nom = string.gsub(nom, "^[%^%)%(%*#@<>!%?]+", "")
	return (string.gsub(nom, "^sound/", ""))
end

function A.SonDeSabre(nom)
	nom = nettoyer(nom)
	if not nom then return false end
	for _, prefixe in ipairs(E.SonsCoupes) do
		if string.sub(nom, 1, #prefixe) == prefixe then return true end
	end
	return false
end

-- L'entité appartient-elle à un porteur d'arme Origine (l'arme, le joueur, ou à côté) ?
local function venantDUneArme(ent, pos)
	if A.EstArme(ent) or A.PorteArme(ent) then return true end
	if not pos and IsValid(ent) and ent.GetPos then pos = ent:GetPos() end
	return A.ArmeProche(pos)
end

---------------------------------------------------------------------------
-- 1. Sons
---------------------------------------------------------------------------
-- Entity:EmitSound (impacts, chocs, sons joués par le serveur)
hook.Add("EntityEmitSound", "origine_armes_sons", function(data)
	if not A.SonDeSabre(data.SoundName) then return end
	if venantDUneArme(data.Entity, data.Pos) then return false end
end)

-- CreateSound (bourdonnement, balancement, contact avec un mur) et sound.Play (impacts au sol) :
-- remplacés par des versions qui coupent les sons de sabre des armes Origine.
-- origine_armes est chargé avant wOS (ordre alphabétique des autorun) : wOS utilise ces versions.
E.CreateSoundOrigine = E.CreateSoundOrigine or CreateSound
function CreateSound(ent, nom, ...)
	if A.SonDeSabre(nom) and venantDUneArme(ent) then
		return E.CreateSoundOrigine(ent, "common/null.wav", ...)
	end
	return E.CreateSoundOrigine(ent, nom, ...)
end

if sound and sound.Play then
	E.SoundPlayOrigine = E.SoundPlayOrigine or sound.Play
	function sound.Play(nom, pos, ...)
		if A.SonDeSabre(nom) and A.ArmeProche(pos) then return end
		return E.SoundPlayOrigine(nom, pos, ...)
	end
end

---------------------------------------------------------------------------
-- 2. Traces de brûlure et étincelles sur les murs
---------------------------------------------------------------------------
E.DecalOrigine = E.DecalOrigine or util.Decal
function util.Decal(nom, debut, ...)
	if isstring(nom) and E.DecalsCoupes[string.lower(nom)] and A.ArmeProche(debut) then return end
	return E.DecalOrigine(nom, debut, ...)
end

E.EffetOrigine = E.EffetOrigine or util.Effect
function util.Effect(nom, donnees, ...)
	if isstring(nom) and E.EffetsCoupes[string.lower(nom)] and donnees and donnees.GetOrigin
		and A.ArmeProche(donnees:GetOrigin()) then
		return
	end
	return E.EffetOrigine(nom, donnees, ...)
end

-- Client : la fonction d'impact de wOS (étincelles + brûlure), définie après le chargement de wOS
function E.RemplacerImpactWOS()
	if not CLIENT or not isfunction(rb655_DrawHit_wos) or rb655_DrawHit_wos == E.ImpactOrigine then return end
	local avant = rb655_DrawHit_wos
	E.ImpactOrigine = function(pos, dir, ...)
		if A.ArmeProche(pos) then return end
		return avant(pos, dir, ...)
	end
	rb655_DrawHit_wos = E.ImpactOrigine
end

---------------------------------------------------------------------------
-- 3. Dégâts : seulement pendant un vrai coup
---------------------------------------------------------------------------
-- Trace de wOS « seulement pendant les coups » (MINIMALINTERP) : précise, sans brûlure au contact
-- ni marque de brûlure. Réglée ici quand wOS est chargé (voir aussi LISEZMOI.txt).
function E.ReglerTrace()
	if not (wOS and wOS.ALCS and wOS.ALCS.Config and WOS_ALCS and WOS_ALCS.TRACE) then return end
	if WOS_ALCS.TRACE.MINIMALINTERP then
		wOS.ALCS.Config.LightsaberTrace = WOS_ALCS.TRACE.MINIMALINTERP
	end
end

-- Le joueur est-il en train de frapper ? (clic gauche / droit tenu ou appuyé il y a moins de
-- E.DureeCoup secondes, ou attaque spéciale de wOS en cours)
function A.EnTrainDeFrapper(ply)
	if not IsValid(ply) then return false end
	if ply:KeyDown(IN_ATTACK) or ply:KeyDown(IN_ATTACK2) then return true end
	if (ply.OrigineDernierCoup or 0) + E.DureeCoup > CurTime() then return true end
	local w = ply:GetActiveWeapon()
	if IsValid(w) and w.GetAttackDelay and (tonumber(w:GetAttackDelay()) or 0) >= CurTime() then return true end
	return false
end

-- Client : wOS bloque les touches et le déplacement pendant les attaques spéciales (coup lourd,
-- ultime : AttackDelay). Les armes Origine peuvent toujours bouger en frappant
-- (avec SWEP.CanMoveWhileAttacking = true pour les coups normaux).
function E.RemplacerBlocageWOS()
	if not CLIENT then return end
	local t = hook.GetTable().CreateMove
	local avant = t and t["rb655_lightsaber_no_fall_damage_wos"]
	if not avant or avant == E.BlocageOrigine then return end
	E.BlocageOrigine = function(cmd, ...)
		local lp = LocalPlayer()
		if IsValid(lp) and A.PorteArme(lp) then return end
		return avant(cmd, ...)
	end
	hook.Add("CreateMove", "rb655_lightsaber_no_fall_damage_wos", E.BlocageOrigine)
end

local function apresWOS()
	E.ReglerTrace()
	E.RemplacerImpactWOS()
	E.RemplacerBlocageWOS()
end
hook.Add("wOS.ALCS.OnLoaded", "origine_armes_epee", apresWOS)
hook.Add("wOS.ALCS.PostLoaded", "origine_armes_epee", apresWOS)
hook.Add("InitPostEntity", "origine_armes_epee", apresWOS)
hook.Add("Initialize", "origine_armes_epee", apresWOS)

if SERVER then
	hook.Add("KeyPress", "origine_armes_coup", function(ply, touche)
		if (touche == IN_ATTACK or touche == IN_ATTACK2) and A.PorteArme(ply) then
			ply.OrigineDernierCoup = CurTime()
		end
	end)

	-- Dégâts de la lame alors que son porteur ne frappe pas : annulés
	hook.Add("EntityTakeDamage", "origine_armes_contact", function(cible, dmg)
		local att = dmg:GetAttacker()
		if not A.PorteArme(att) then return end
		local w = att:GetActiveWeapon()
		local infl = dmg:GetInflictor()
		if infl ~= w and infl ~= att then return end -- autre chose (objet lancé, entité...)
		-- Pouvoir utilisé à l'instant : dégâts de pouvoir, gardés
		if (att.OrigineDernierPouvoir or 0) + 0.6 > CurTime() then return end
		if A.EnTrainDeFrapper(att) then return end
		return true
	end)
end
