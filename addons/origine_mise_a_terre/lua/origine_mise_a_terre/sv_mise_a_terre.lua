--[[-----------------------------------------------------------------------
	Origine du monde — mise à terre et captures (serveur)

	Le serveur vérifie tout : état des joueurs, distance pendant toute la
	durée d'une action, droit de relever (guérisseurs), ravisseur pour escorter.
-------------------------------------------------------------------------]]

local M = ORIGINE.MiseATerre
local CM = ORIGINE.ConfigMiseATerre
local I = ORIGINE.Inv

util.AddNetworkString("origine_mat_progression")

local EXCLUS = 0
for _, t in ipairs(CM.DegatsExclus) do EXCLUS = bit.bor(EXCLUS, t) end

function M.Historiser(staff, cible, action)
	if not ORIGINE.Historique then return end
	ORIGINE.Historique.Ajouter({
		type = "mise_a_terre", staff = staff, cible_sid = cible:SteamID64(), cible_slot = cible.OrigineSlot,
		cible_nom = ORIGINE.NomComplet(cible), apres = { action = action },
	})
end

---------------------------------------------------------------------------
-- États
---------------------------------------------------------------------------
local function vueNormale(ply)
	if ply.OrigineVueAvant then
		ply:SetViewOffset(ply.OrigineVueAvant[1])
		ply:SetViewOffsetDucked(ply.OrigineVueAvant[2])
		ply.OrigineVueAvant = nil
	end
end

local function mainsVides(ply)
	if ply:HasWeapon("origine_mains") then ply:SelectWeapon("origine_mains") end
end

function M.MettreATerre(ply)
	if ORIGINE.EstATerre(ply) then return end
	-- Libère un captif qui escortait / était escorté
	M.LacherTout(ply)
	if ORIGINE.EstLigote(ply) then M.Delier(ply, true) end
	mainsVides(ply)
	ply:SetNW2Bool("origine_a_terre", true)
	ply:SetNW2Float("origine_terre_fin", CurTime() + CM.Duree)
	ply.OrigineVueAvant = ply.OrigineVueAvant or { ply:GetViewOffset(), ply:GetViewOffsetDucked() }
	ply:SetViewOffset(Vector(0, 0, CM.HauteurVue))
	ply:SetViewOffsetDucked(Vector(0, 0, CM.HauteurVue))
	hook.Run("origine_MisATerre", ply)
end

local function finATerre(ply)
	ply:SetNW2Bool("origine_a_terre", false)
	ply:SetNW2Float("origine_terre_fin", 0)
	vueNormale(ply)
end

function M.Relever(ply, pv)
	if not ORIGINE.EstATerre(ply) then return end
	finATerre(ply)
	ply:SetHealth(math.min(ply:GetMaxHealth(), math.max(ply:Health(), pv or 1)))
	hook.Run("origine_Releve", ply)
end

-- Le captif se relève avec ses PV actuels, mains liées
function M.Ligoter(ply, ravisseur)
	finATerre(ply)
	mainsVides(ply)
	ply:SetNW2Bool("origine_ligote", true)
	ply:SetNW2Entity("origine_ravisseur", ravisseur)
	ply.OrigineCourseAvant = ply.OrigineCourseAvant or ply:GetRunSpeed()
	ply:SetRunSpeed(ply:GetWalkSpeed())
	hook.Run("origine_Ligote", ply, ravisseur)
end

function M.Delier(ply, silencieux)
	if not ORIGINE.EstLigote(ply) then return end
	ply:SetNW2Bool("origine_ligote", false)
	ply:SetNW2Entity("origine_ravisseur", NULL)
	ply:SetNW2Entity("origine_escorte", NULL)
	if ply.OrigineCourseAvant then
		ply:SetRunSpeed(ply.OrigineCourseAvant)
		ply.OrigineCourseAvant = nil
	end
	if not silencieux then hook.Run("origine_Delie", ply) end
end

-- Arrête toute escorte faite par ce joueur
function M.LacherTout(ply)
	for _, c in ipairs(player.GetAll()) do
		if c:GetNW2Entity("origine_escorte") == ply then c:SetNW2Entity("origine_escorte", NULL) end
	end
end

local function effacer(ply)
	finATerre(ply)
	M.Delier(ply, true)
	M.LacherTout(ply)
	ply.OrigineActionMAT = nil
end

---------------------------------------------------------------------------
-- Déclenchement : un coup d'arme non mortel qui laisse Seuil PV ou moins
---------------------------------------------------------------------------
hook.Add("EntityTakeDamage", "origine_mise_a_terre", function(cible, dmg)
	if not cible:IsPlayer() then return end
	cible.OrigineCoupArme = nil
	local attaquant = dmg:GetAttacker()
	if not IsValid(attaquant) or attaquant == cible then return end
	if not (attaquant:IsPlayer() or attaquant:IsNPC()) then return end
	if bit.band(dmg:GetDamageType(), EXCLUS) ~= 0 or dmg:IsFallDamage() then return end
	cible.OrigineCoupArme = true
end)

hook.Add("PostEntityTakeDamage", "origine_mise_a_terre", function(cible, _, subi)
	if not (subi and cible:IsPlayer() and cible.OrigineCoupArme) then return end
	cible.OrigineCoupArme = nil
	if not cible:Alive() or ORIGINE.EnMenu(cible) or not ORIGINE.PersoActuel(cible) then return end
	local pv = cible:Health()
	if pv > 0 and pv <= CM.Seuil then M.MettreATerre(cible) end
end)

-- Compte à rebours : à 0, il meurt (le sac de mort tombe via DoPlayerDeath)
timer.Create("origine_mise_a_terre", 1, 0, function()
	local maintenant = CurTime()
	for _, ply in ipairs(player.GetAll()) do
		if ORIGINE.EstATerre(ply) and ply:Alive() and maintenant >= ply:GetNW2Float("origine_terre_fin", 0) then
			ply:Kill()
		end
	end
end)

hook.Add("PlayerDeath", "origine_mise_a_terre", effacer)
hook.Add("PlayerSpawn", "origine_mise_a_terre", effacer)
hook.Add("origine_PersonnageDecharge", "origine_mise_a_terre", function(ply) if IsValid(ply) then effacer(ply) end end)

-- L'arrestation DarkRP fonctionne sur un captif : il est délié en prison
hook.Add("playerArrested", "origine_mise_a_terre", function(ply) effacer(ply) end)

---------------------------------------------------------------------------
-- Anti-abus
---------------------------------------------------------------------------
hook.Add("origine_PeutChangerPerso", "origine_mise_a_terre", function(ply)
	if ORIGINE.EstATerre(ply) then return false, "Impossible de changer de personnage à terre." end
	if ORIGINE.EstLigote(ply) then return false, "Impossible de changer de personnage en étant ligoté." end
end)

-- wOS ALCS : aucun pouvoir de Force (saut de Force compris) à terre ou ligoté
hook.Add("wOS.ALCS.CanUseForcepower", "origine_mise_a_terre", function(ply)
	if ORIGINE.EstImmobilise(ply) then return true end
end)

hook.Add("CanPlayerSuicide", "origine_mise_a_terre", function(ply)
	if ORIGINE.EstImmobilise(ply) then return false end
end)

hook.Add("origine_RegenBloquee", "origine_mise_a_terre", function(ply)
	if ORIGINE.EstATerre(ply) then return true end
end)

hook.Add("PlayerCanPickupWeapon", "origine_mise_a_terre", function(ply)
	if ORIGINE.EstImmobilise(ply) then return false end
end)

hook.Add("PlayerUse", "origine_mise_a_terre", function(ply)
	if ORIGINE.EstATerre(ply) then return false end
end)

-- Se déconnecter à terre ou ligoté compte comme une mort
hook.Add("PlayerDisconnected", "origine_mise_a_terre", function(ply)
	M.LacherTout(ply)
	if not (CM.DeconnexionEstMort and ORIGINE.EstImmobilise(ply) and ORIGINE.PersoActuel(ply)) then return end
	if I and I.LacherSacDeMort then I.LacherSacDeMort(ply) end
	effacer(ply)
	if ply:Alive() then ply:KillSilent() end
	ORIGINE.SauvegarderJoueur(ply, true)
end)

---------------------------------------------------------------------------
-- Actions avec barre de progression : relever, ligoter, délier
---------------------------------------------------------------------------
local function guerisseur(ply)
	return ORIGINE.DansListe(CM.Relever.Guerisseurs, ORIGINE.CommandeJob(ply:Team()))
end

local function guerisseurConnecte()
	for _, p in ipairs(player.GetAll()) do
		if p:Alive() and not ORIGINE.EnMenu(p) and guerisseur(p) then return true end
	end
	return false
end

local function aPortee(acteur, cible)
	return IsValid(acteur) and IsValid(cible) and acteur:Alive() and cible:Alive()
		and acteur:GetPos():Distance(cible:GetPos()) <= CM.Distance
end

local function envoyerProgression(ply, duree, texte)
	net.Start("origine_mat_progression")
		net.WriteFloat(duree)
		net.WriteString(texte or "")
	net.Send(ply)
end

local function annuler(acteur, raison)
	if not acteur.OrigineActionMAT then return end
	acteur.OrigineActionMAT = nil
	envoyerProgression(acteur, 0, "")
	if raison then ORIGINE.Notifier(acteur, raison, "erreur") end
end

-- Vérifie que l'action est encore possible (au début et pendant toute la durée)
local function actionPossible(action, cible)
	if action == "relever" or action == "ligoter" then return ORIGINE.EstATerre(cible) end
	if action == "delier" or action == "escorter" or action == "lacher" then return ORIGINE.EstLigote(cible) end
	return false
end

local function terminer(acteur, a)
	local cible = a.cible
	if a.action == "relever" then
		M.Relever(cible, a.pv)
		ORIGINE.Notifier(acteur, ORIGINE.NomComplet(cible) .. " est relevé.", "succes")
	elseif a.action == "ligoter" then
		M.Ligoter(cible, acteur)
		ORIGINE.Notifier(cible, "Vous êtes ligoté.", "info")
	elseif a.action == "delier" then
		M.Delier(cible)
		ORIGINE.Notifier(cible, "Vous êtes délié.", "succes")
	end
end

ORIGINE.NetRecevoir("origine_mat_action", function(acteur)
	local cible = net.ReadEntity()
	local action = net.ReadString()
	if not (IsValid(cible) and cible:IsPlayer() and cible ~= acteur) then return end
	if ORIGINE.EstImmobilise(acteur) or ORIGINE.EnMenu(acteur) or not ORIGINE.PersoActuel(acteur) then return end
	if not aPortee(acteur, cible) then return ORIGINE.Notifier(acteur, "Vous êtes trop loin.", "erreur") end
	if not actionPossible(action, cible) then return end

	-- Escorter / lâcher : immédiat, réservé au ravisseur
	if action == "escorter" or action == "lacher" then
		if cible:GetNW2Entity("origine_ravisseur") ~= acteur then
			return ORIGINE.Notifier(acteur, "Seul son ravisseur peut l'escorter.", "erreur")
		end
		cible:SetNW2Entity("origine_escorte", action == "escorter" and acteur or NULL)
		ORIGINE.Notifier(acteur, action == "escorter" and "Vous escortez le captif." or "Vous lâchez le captif.", "info")
		return
	end

	local duree, pv
	if action == "relever" then
		if guerisseur(acteur) then
			duree, pv = CM.Relever.DureeGuerisseur, CM.Relever.PVGuerisseur
		elseif guerisseurConnecte() then
			return ORIGINE.Notifier(acteur, "Un guérisseur est présent : lui seul peut le relever.", "erreur")
		else
			duree, pv = CM.Relever.DureeTous, CM.Relever.PVTous
		end
	elseif action == "ligoter" then
		duree = CM.Ligoter.Duree
	elseif action == "delier" then
		duree = CM.Delier.Duree
	else
		return
	end

	local libelles = { relever = "Relever", ligoter = "Ligoter", delier = "Délier" }
	acteur.OrigineActionMAT = { cible = cible, action = action, fin = CurTime() + duree, pv = pv }
	envoyerProgression(acteur, duree, libelles[action] .. " " .. ORIGINE.NomComplet(cible))
end, 4)

-- Suivi des actions en cours (distance vérifiée pendant toute la durée)
timer.Create("origine_mat_actions", 0.2, 0, function()
	local maintenant = CurTime()
	for _, acteur in ipairs(player.GetAll()) do
		local a = acteur.OrigineActionMAT
		if a then
			if not aPortee(acteur, a.cible) or ORIGINE.EstImmobilise(acteur) then
				annuler(acteur, "Action interrompue : restez près de lui.")
			elseif not actionPossible(a.action, a.cible) then
				annuler(acteur)
			elseif maintenant >= a.fin then
				acteur.OrigineActionMAT = nil
				envoyerProgression(acteur, 0, "")
				terminer(acteur, a)
			end
		end
	end
end)

-- L'escorte s'arrête si le ravisseur est trop loin (téléportation, mort…)
timer.Create("origine_mat_escortes", 1, 0, function()
	for _, c in ipairs(player.GetAll()) do
		local e = M.Escorteur(c)
		if e and (not e:Alive() or ORIGINE.EstImmobilise(e) or e:GetPos():Distance(c:GetPos()) > 600) then
			c:SetNW2Entity("origine_escorte", NULL)
		end
	end
end)
