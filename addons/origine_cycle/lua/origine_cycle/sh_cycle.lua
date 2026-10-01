--[[-----------------------------------------------------------------------
	Origine du monde — cycle jour/nuit (partagé)

	Le serveur envoie l'état du cycle à chaque changement de phase (et aux
	commandes staff) ; les clients calculent l'heure RP eux-mêmes.

	API pour les bonus et malus à venir (serveur et client) :
	  ORIGINE.EstNuit()       true de 18 h à 6 h (crépuscule compris)
	  ORIGINE.HeureRP()       heures, minutes (ex. 23, 40)
	  ORIGINE.EstPleineLune() true pendant une nuit de pleine lune
	  ORIGINE.PhaseCycle()    "aube", "jour", "crepuscule" ou "nuit"
	Hooks : OrigineDebutJour(), OrigineDebutNuit(pleineLune),
	        OrigineChangementPhase(nouvelle, ancienne)
-------------------------------------------------------------------------]]

local CY = ORIGINE.ConfigCycle
ORIGINE.Cycle = ORIGINE.Cycle or { position = 0, reference = 0, pause = false, pleineLune = false }
local E = ORIGINE.Cycle

function E.Duree() return CY.DureeJour + CY.DureeNuit end

-- Position dans le cycle (secondes depuis le début de l'aube)
function E.Position()
	if E.pause then return E.position % E.Duree() end
	return (E.position + (CurTime() - E.reference)) % E.Duree()
end

function E.Fixer(position)
	E.position = position % E.Duree()
	E.reference = CurTime()
end

function E.PhaseA(pos)
	if pos < CY.Transition then return "aube" end
	if pos < CY.DureeJour then return "jour" end
	if pos < CY.DureeJour + CY.Transition then return "crepuscule" end
	return "nuit"
end

-- Minutes RP depuis minuit (0 à 1439)
function E.MinutesA(pos)
	local m
	if pos < CY.DureeJour then
		m = 360 + pos / CY.DureeJour * 720
	else
		m = 1080 + (pos - CY.DureeJour) / CY.DureeNuit * 720
	end
	return math.floor(m) % 1440
end

-- Position correspondant à une heure RP
function E.PositionPourHeure(h, m)
	local minutes = ((h * 60 + (m or 0)) % 1440)
	if minutes >= 360 and minutes < 1080 then
		return (minutes - 360) / 720 * CY.DureeJour
	end
	local depuis18 = (minutes - 1080) % 1440
	return CY.DureeJour + depuis18 / 720 * CY.DureeNuit
end

-- Luminosité de 0 (nuit) à 1 (jour), progressive pendant l'aube et le crépuscule
function E.LuminositeA(pos)
	if pos < CY.Transition then return pos / CY.Transition end
	if pos < CY.DureeJour then return 1 end
	if pos < CY.DureeJour + CY.Transition then return 1 - (pos - CY.DureeJour) / CY.Transition end
	return 0
end

function ORIGINE.PhaseCycle() return E.PhaseA(E.Position()) end
function ORIGINE.EstNuit() return E.Position() >= CY.DureeJour end
function ORIGINE.EstPleineLune() return ORIGINE.EstNuit() and E.pleineLune == true end
function ORIGINE.HeureRP()
	local m = E.MinutesA(E.Position())
	return math.floor(m / 60), m % 60
end

-- Suivi des changements de phase (serveur et client) : lance les hooks
function E.VerifierPhase()
	local phase = ORIGINE.PhaseCycle()
	local ancienne = E.phase
	if phase == ancienne then return false end
	E.phase = phase
	if ancienne == nil then return false end   -- premier calcul : pas d'événement
	hook.Run("OrigineChangementPhase", phase, ancienne)
	if phase == "aube" then hook.Run("OrigineDebutJour") end
	if phase == "crepuscule" then hook.Run("OrigineDebutNuit", E.pleineLune) end
	return true, phase, ancienne
end
