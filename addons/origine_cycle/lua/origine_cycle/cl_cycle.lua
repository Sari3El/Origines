--[[-----------------------------------------------------------------------
	Origine du monde — cycle jour/nuit (client)

	Le client reçoit l'état à chaque changement de phase et calcule l'heure
	RP lui-même. Brouillard de nuit progressif ; l'éclairage de la map est
	rechargé seulement quand le serveur change de palier.
-------------------------------------------------------------------------]]

local CY = ORIGINE.ConfigCycle
local E = ORIGINE.Cycle
local R = CY.Rendu

net.Receive("origine_cycle", function()
	E.Fixer(net.ReadFloat())
	E.pause = net.ReadBool()
	E.pleineLune = net.ReadBool()
	E.recu = true
	E.VerifierPhase()
end)

net.Receive("origine_cycle_lumiere", function()
	render.RedownloadAllLightmaps(true)
end)

hook.Add("InitPostEntity", "origine_cycle", function()
	net.Start("origine_cycle_demande")
	net.SendToServer()
end)

-- Hooks de phase côté client aussi (calcul local, une fois par seconde)
timer.Create("origine_cycle", 1, 0, function()
	if E.recu then E.VerifierPhase() end
end)

-- Texte du HUD (origine_hud) : « Nuit · 23:40 »
function ORIGINE.TexteCycle()
	if not E.recu then return nil end
	local h, m = ORIGINE.HeureRP()
	local nom = CY.NomsPhases[ORIGINE.PhaseCycle()] or ""
	if ORIGINE.EstPleineLune() and ORIGINE.PhaseCycle() == "nuit" then nom = CY.NomsPhases.pleine_lune or nom end
	return string.format("%s · %02d:%02d", nom, h, m)
end

---------------------------------------------------------------------------
-- Brouillard de nuit (pas avec StormFox 2, qui gère le sien)
---------------------------------------------------------------------------
local function densiteBrouillard()
	if not (R.Brouillard and E.recu) or StormFox2 then return 0 end
	return (1 - E.LuminositeA(E.Position())) * R.BrouillardDensite
end

local function brouillard(echelle)
	local d = densiteBrouillard()
	if d <= 0 then return end
	echelle = echelle or 1
	local c = R.BrouillardCouleur
	render.FogMode(MATERIAL_FOG_LINEAR)
	render.FogStart(R.BrouillardDebut * echelle)
	render.FogEnd(R.BrouillardFin * echelle)
	render.FogMaxDensity(d)
	render.FogColor(c.r, c.g, c.b)
	return true
end

hook.Add("SetupWorldFog", "origine_cycle", function() return brouillard(1) end)
hook.Add("SetupSkyboxFog", "origine_cycle", function(echelle) return brouillard(echelle) end)
