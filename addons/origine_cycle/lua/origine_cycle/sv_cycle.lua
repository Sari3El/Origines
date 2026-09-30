--[[-----------------------------------------------------------------------
	Origine du monde — cycle jour/nuit (serveur)

	Un message réseau par changement de phase (et par commande staff).
	L'éclairage de la map change par paliers pendant l'aube et le crépuscule.
	La position dans le cycle est sauvegardée : après un redémarrage, le
	cycle reprend là où il en était.
-------------------------------------------------------------------------]]

local CY = ORIGINE.ConfigCycle
local E = ORIGINE.Cycle
local R = CY.Rendu

util.AddNetworkString("origine_cycle")
util.AddNetworkString("origine_cycle_lumiere")

ORIGINE.EnregistrerPermission("origine_cycle_admin", "admin", "Cycle jour/nuit : changer la phase, l'heure, la pause et la pleine lune")

E.nuits = E.nuits or 0
E.forceLune = E.forceLune -- nil = automatique, true / false = forcé par le staff

local function stormFox()
	return StormFox2 and StormFox2.Time and StormFox2.Time.Set
end

---------------------------------------------------------------------------
-- Sauvegarde
---------------------------------------------------------------------------
local function sauvegarder()
	file.CreateDir("origine")
	file.Write(CY.Fichier, util.TableToJSON({
		position = E.Position(), pause = E.pause, pleineLune = E.pleineLune,
		nuits = E.nuits, forceLune = E.forceLune,
	}))
end

local function charger()
	local brut = file.Exists(CY.Fichier, "DATA") and file.Read(CY.Fichier, "DATA")
	local d = brut and util.JSONToTable(brut) or {}
	E.Fixer(tonumber(d.position) or CY.DureeJour * 0.3)
	E.pause = d.pause == true
	E.pleineLune = d.pleineLune == true
	E.nuits = tonumber(d.nuits) or 0
	E.forceLune = d.forceLune
	E.phase = nil
end

---------------------------------------------------------------------------
-- Réseau : l'état complet, les clients calculent le reste
---------------------------------------------------------------------------
local function ecrireEtat()
	net.WriteFloat(E.Position())
	net.WriteBool(E.pause)
	net.WriteBool(E.pleineLune)
end

function E.Diffuser(cible)
	net.Start("origine_cycle")
		ecrireEtat()
	if cible then net.Send(cible) else net.Broadcast() end
end

ORIGINE.NetRecevoir("origine_cycle_demande", function(ply)
	if ply.OrigineCycleEnvoye then return end
	ply.OrigineCycleEnvoye = true
	E.Diffuser(ply)
	if E.lettre and not stormFox() then
		net.Start("origine_cycle_lumiere") net.Send(ply)
	end
end, 1)

---------------------------------------------------------------------------
-- Rendu : éclairage par paliers, ciel peint, StormFox 2
---------------------------------------------------------------------------
local function lettrePour(lum)
	local nuit, jour = string.byte(R.LumiereNuit), string.byte(R.LumiereJour)
	local palier = math.Round(lum * R.Paliers) / R.Paliers
	return string.char(math.Round(nuit + (jour - nuit) * palier)), palier
end

local function appliquerCiel(palier)
	if not R.Ciel then return end
	local ciel = ents.FindByClass("env_skypaint")[1]
	if not IsValid(ciel) then return end
	local j, n = R.CielJour, R.CielNuit
	if ciel.SetTopColor then ciel:SetTopColor(LerpVector(palier, n.Haut, j.Haut)) end
	if ciel.SetBottomColor then ciel:SetBottomColor(LerpVector(palier, n.Bas, j.Bas)) end
	if ciel.SetStarFade then ciel:SetStarFade(Lerp(palier, n.Etoiles, j.Etoiles)) end
end

local function appliquerRendu()
	local pos = E.Position()
	if stormFox() then
		-- StormFox 2 fait le rendu : on lui donne l'heure RP (en minutes depuis minuit)
		pcall(StormFox2.Time.Set, E.MinutesA(pos))
		return
	end
	if not R.Eclairage then return end
	local lettre, palier = lettrePour(E.LuminositeA(pos))
	if lettre == E.lettre then return end
	E.lettre = lettre
	engine.LightStyle(0, lettre)
	appliquerCiel(palier)
	net.Start("origine_cycle_lumiere") net.Broadcast()
end

---------------------------------------------------------------------------
-- Boucle : une vérification par seconde
---------------------------------------------------------------------------
local function tic()
	local phase = ORIGINE.PhaseCycle()
	if E.phase ~= nil and phase ~= E.phase then
		if phase == "crepuscule" then
			E.nuits = E.nuits + 1
			if E.forceLune ~= nil then
				E.pleineLune = E.forceLune
			else
				E.pleineLune = CY.PleineLuneTous > 0 and E.nuits % CY.PleineLuneTous == 0
			end
		elseif phase == "aube" then
			E.pleineLune = false
			if E.forceLune ~= nil then E.forceLune = nil end
		end
	end

	local change, nouvelle = E.VerifierPhase()
	if change then
		E.Diffuser()
		if nouvelle == "aube" then
			ORIGINE.Annoncer(CY.CouleurMessages, CY.Messages.Aube)
		elseif nouvelle == "crepuscule" then
			ORIGINE.Annoncer(CY.CouleurMessages, CY.Messages.Crepuscule)
			if E.pleineLune then ORIGINE.Annoncer(CY.CouleurMessages, CY.Messages.PleineLune) end
		end
		sauvegarder()
	end
	appliquerRendu()
end

hook.Add("InitPostEntity", "origine_cycle", function()
	charger()
	E.VerifierPhase()
	timer.Create("origine_cycle", 1, 0, tic)
	timer.Create("origine_cycle_sauvegarde", CY.IntervalleSauvegarde, 0, sauvegarder)
	appliquerRendu()
end)
hook.Add("ShutDown", "origine_cycle", sauvegarder)

---------------------------------------------------------------------------
-- Commandes staff
---------------------------------------------------------------------------
local function refaire()
	E.phase = nil
	E.VerifierPhase()
	E.lettre = nil
	E.Diffuser()
	appliquerRendu()
	sauvegarder()
end

local AIDE = "Usage : !cycle jour | nuit | heure HH:MM | pause | reprendre | lune oui|non|auto"

function E.Commande(ply, args)
	if IsValid(ply) and not ORIGINE.APermission(ply, "origine_cycle_admin") then
		return ORIGINE.Notifier(ply, "Vous n'avez pas la permission.", "erreur")
	end
	local function repondre(t, typ)
		if IsValid(ply) then ORIGINE.Notifier(ply, t, typ or "succes") else print("[Origine] " .. t) end
	end
	local action = string.lower(args[1] or "")
	local detail
	if action == "jour" then
		E.Fixer(0)
		E.phase = "crepuscule"   -- déclenche l'aube au prochain tic (messages, hooks)
		E.Diffuser()
		detail = "passage au jour"
	elseif action == "nuit" then
		E.Fixer(CY.DureeJour)
		E.phase = "jour"         -- déclenche le crépuscule au prochain tic
		E.Diffuser()
		detail = "passage à la nuit"
	elseif action == "heure" then
		local h, m = string.match(args[2] or "", "^(%d%d?)[:hH](%d%d)$")
		h, m = tonumber(h), tonumber(m)
		if not h or h > 23 or m > 59 then return repondre("Heure invalide (ex. 23:40).", "erreur") end
		E.Fixer(E.PositionPourHeure(h, m))
		refaire()
		detail = string.format("heure réglée sur %02d:%02d", h, m)
	elseif action == "pause" then
		if not E.pause then E.position, E.pause = E.Position(), true end
		refaire()
		detail = "cycle en pause"
	elseif action == "reprendre" then
		if E.pause then E.pause = false E.reference = CurTime() end
		refaire()
		detail = "cycle relancé"
	elseif action == "lune" then
		local v = string.lower(args[2] or "")
		if v == "oui" then E.forceLune = true elseif v == "non" then E.forceLune = false
		elseif v == "auto" then E.forceLune = nil else return repondre(AIDE, "erreur") end
		-- Pendant la nuit, s'applique tout de suite
		if ORIGINE.EstNuit() and E.forceLune ~= nil then E.pleineLune = E.forceLune end
		refaire()
		detail = "pleine lune : " .. v
	else
		return repondre(AIDE, "erreur")
	end
	repondre("Cycle : " .. detail .. ".")
	if ORIGINE.Historique then
		ORIGINE.Historique.Ajouter({ type = "cycle", staff = ply, apres = { action = detail } })
	end
end

concommand.Add("origine_cycle", function(ply, _, args) E.Commande(ply, args) end)

hook.Add("PlayerSay", "origine_cycle", function(ply, texte)
	local bas = string.lower(string.Trim(texte))
	if string.sub(bas, 1, 6) == "!cycle" or string.sub(bas, 1, 6) == "/cycle" then
		local args = string.Explode(" ", string.Trim(string.sub(texte, 7)))
		E.Commande(ply, args)
		return ""
	end
end)
