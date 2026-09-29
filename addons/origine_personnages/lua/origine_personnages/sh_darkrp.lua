--[[-----------------------------------------------------------------------
	Origine du monde — intégration DarkRP (partagé)

	Aucune modification des fichiers de DarkRP : tout passe par les hooks.
	  - Covan déclaré comme monnaie (F4, chat)
	  - /rpname et /name désactivés (allowrpnames = false)
	  - poche DarkRP désactivée (remplacée par la sacoche)
	  - job caché « Sélection du personnage »
-------------------------------------------------------------------------]]

local C = ORIGINE.Config

local function reglerDarkRP()
	local gm = GAMEMODE or GM
	if not gm or not gm.Config then return end
	local cfg = gm.Config

	-- Monnaie
	cfg.currency = " " .. C.Monnaie.Nom
	cfg.currencyLeft = false
	if C.Monnaie.RemplacerFormatDarkRP and DarkRP then
		DarkRP.formatMoney = function(n) return ORIGINE.FormaterCovan(n) end
	end

	-- Noms : uniquement via la création de personnage
	cfg.allowrpnames = false

	-- Poche DarkRP remplacée par la sacoche
	if istable(cfg.DefaultWeapons) then
		for i = #cfg.DefaultWeapons, 1, -1 do
			if cfg.DefaultWeapons[i] == "pocket" then table.remove(cfg.DefaultWeapons, i) end
		end
	end
end

local function creerJobSelection()
	if ORIGINE.EquipeSelection or not DarkRP or not DarkRP.createJob then return end
	local j = C.JobSelection
	if DarkRP.createCategory then
		DarkRP.createCategory({
			name = "Origine",
			categorises = "jobs",
			startExpanded = false,
			color = j.Couleur,
			canSee = function() return false end,
			sortOrder = 9999,
		})
	end
	ORIGINE.EquipeSelection = DarkRP.createJob(j.Nom, {
		color = j.Couleur,
		model = { j.Modele },
		description = "Choix du personnage en cours.",
		weapons = {},
		command = j.Commande,
		max = 0,
		salary = 0,
		admin = 0,
		vote = false,
		hasLicense = false,
		candemote = false,
		category = "Origine",
		customCheck = function() return false end,
		CustomCheckFailMsg = "Ce job est réservé au menu personnage.",
		origine_cache = true,
	})
end

hook.Add("loadCustomDarkRPItems", "origine_darkrp", function()
	creerJobSelection()
	reglerDarkRP()
end)

hook.Add("DarkRPFinishedLoading", "origine_darkrp", function()
	creerJobSelection()
	reglerDarkRP()
end)

hook.Add("Initialize", "origine_darkrp", reglerDarkRP)

---------------------------------------------------------------------------
-- Jobs : commande <-> numéro d'équipe
---------------------------------------------------------------------------
function ORIGINE.CommandeJob(t)
	local job = RPExtraTeams and RPExtraTeams[t]
	return job and job.command or nil
end

function ORIGINE.EquipeDeCommande(commande)
	if not commande or not RPExtraTeams then return nil end
	for t, job in pairs(RPExtraTeams) do
		if job.command == commande then return t end
	end
	return nil
end

function ORIGINE.NomJob(commande)
	local t = ORIGINE.EquipeDeCommande(commande)
	if t then return team.GetName(t) end
	return commande or "Sans métier"
end

-- Le modèle fait-il partie des modèles du job ?
function ORIGINE.ModeleDuJob(t, modele)
	local job = RPExtraTeams and RPExtraTeams[t]
	if not job or not isstring(modele) then return false end
	modele = string.lower(modele)
	if isstring(job.model) then return string.lower(job.model) == modele end
	for _, m in ipairs(job.model or {}) do
		if string.lower(m) == modele then return true end
	end
	return false
end

---------------------------------------------------------------------------
-- Modèle choisi dans le F4 : mémorisé par personnage
---------------------------------------------------------------------------
if CLIENT then
	local function envelopper()
		if not DarkRP or not DarkRP.setPreferredJobModel or DarkRP.OrigineModeleEnveloppe then return end
		DarkRP.OrigineModeleEnveloppe = true
		local ancien = DarkRP.setPreferredJobModel
		DarkRP.setPreferredJobModel = function(teamNr, modele, ...)
			ancien(teamNr, modele, ...)
			if isnumber(teamNr) and isstring(modele) then
				net.Start("origine_modele_f4")
					net.WriteUInt(teamNr, 16)
					net.WriteString(modele)
				net.SendToServer()
			end
		end
	end
	hook.Add("DarkRPFinishedLoading", "origine_modele_f4", envelopper)
	hook.Add("InitPostEntity", "origine_modele_f4", envelopper)
end

---------------------------------------------------------------------------
-- Menu F4 désactivé (C.DesactiverF4)
---------------------------------------------------------------------------
if SERVER then
	hook.Add("ShowSpare2", "origine_f4", function()
		if C.DesactiverF4 then return true end
	end)
else
	local function neutraliserF4()
		if not C.DesactiverF4 or not DarkRP then return end
		local rien = function() end
		DarkRP.openF4Menu = rien
		DarkRP.toggleF4Menu = rien
	end
	hook.Add("DarkRPFinishedLoading", "origine_f4", neutraliserF4)
	hook.Add("InitPostEntity", "origine_f4", neutraliserF4)

	hook.Add("PlayerBindPress", "origine_f4", function(_, bind, appuye)
		if C.DesactiverF4 and appuye and string.find(string.lower(bind), "gm_showspare2", 1, true) then return true end
	end)
end
