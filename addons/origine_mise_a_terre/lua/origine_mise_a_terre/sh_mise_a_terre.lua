--[[-----------------------------------------------------------------------
	Origine du monde — mise à terre et captures (partagé)

	États (variables réseau, lues partout) :
	  origine_a_terre (bool), origine_terre_fin (CurTime de la mort)
	  origine_ligote (bool), origine_ravisseur (entité), origine_escorte (entité qui escorte)

	Restrictions appliquées dans StartCommand / SetupMove (prédites des deux
	côtés, donc sans à-coups) : à terre, aucun mouvement ni bouton ; ligoté,
	ni arme ni course ; escorté, le captif suit son ravisseur.
-------------------------------------------------------------------------]]

ORIGINE.MiseATerre = ORIGINE.MiseATerre or {}
local M = ORIGINE.MiseATerre
local CM = ORIGINE.ConfigMiseATerre

function ORIGINE.EstATerre(ply) return IsValid(ply) and ply:GetNW2Bool("origine_a_terre", false) end
function ORIGINE.EstLigote(ply) return IsValid(ply) and ply:GetNW2Bool("origine_ligote", false) end
function ORIGINE.EstImmobilise(ply) return ORIGINE.EstATerre(ply) or ORIGINE.EstLigote(ply) end

function M.Escorteur(ply)
	local e = ply:GetNW2Entity("origine_escorte")
	return IsValid(e) and e or nil
end

---------------------------------------------------------------------------
-- Commandes du joueur
---------------------------------------------------------------------------
hook.Add("StartCommand", "origine_mise_a_terre", function(ply, cmd)
	if ORIGINE.EstATerre(ply) then
		cmd:ClearMovement()
		cmd:ClearButtons()
		return
	end
	if ORIGINE.EstLigote(ply) then
		cmd:RemoveKey(IN_ATTACK)
		cmd:RemoveKey(IN_ATTACK2)
		cmd:RemoveKey(IN_RELOAD)
		cmd:RemoveKey(IN_SPEED)
		if M.Escorteur(ply) then cmd:ClearMovement() end
	end
end)

-- Captif escorté : avance vers son ravisseur
hook.Add("SetupMove", "origine_mise_a_terre", function(ply, mv)
	if not ORIGINE.EstLigote(ply) then return end
	local e = M.Escorteur(ply)
	if not e then return end
	local vers = e:GetPos() - ply:GetPos()
	vers.z = 0
	local dist = vers:Length()
	mv:SetMoveAngles(vers:Angle())
	mv:SetForwardSpeed(dist > CM.DistanceEscorte and ply:GetWalkSpeed() or 0)
	mv:SetSideSpeed(0)
end)

-- Pas de changement d'arme à terre ou ligoté
hook.Add("PlayerSwitchWeapon", "origine_mise_a_terre", function(ply)
	if ORIGINE.EstImmobilise(ply) then return true end
end)

-- Au sol
hook.Add("CalcMainActivity", "origine_mise_a_terre", function(ply)
	if not ORIGINE.EstATerre(ply) then return end
	local seq = ply:LookupSequence(CM.Sequence)
	if seq and seq > 0 then return ACT_HL2MP_ZOMBIE_SLUMP_IDLE, seq end
end)

---------------------------------------------------------------------------
-- Commandes ULX (ulx relever, ulx delier), déclarées des deux côtés
---------------------------------------------------------------------------
local function enregistrerULX()
	if M.ULXEnregistre or not (ulx and ulx.command and ULib and ULib.cmds) then return end
	M.ULXEnregistre = true

	local relever = ulx.command("Origine", "ulx relever", function(appelant, cibles)
		local faits = {}
		for _, c in ipairs(cibles) do
			if ORIGINE.EstATerre(c) then
				M.Relever(c, CM.Relever.PVGuerisseur)
				faits[#faits + 1] = c
				M.Historiser(appelant, c, "relever")
			end
		end
		if #faits > 0 then ulx.fancyLogAdmin(appelant, "#A a relevé #T", faits) end
	end, "!relever")
	relever:addParam({ type = ULib.cmds.PlayersArg })
	relever:defaultAccess(ULib.ACCESS_ADMIN)
	relever:help("Relève un joueur à terre.")

	local delier = ulx.command("Origine", "ulx delier", function(appelant, cibles)
		local faits = {}
		for _, c in ipairs(cibles) do
			if ORIGINE.EstLigote(c) then
				M.Delier(c)
				faits[#faits + 1] = c
				M.Historiser(appelant, c, "delier")
			end
		end
		if #faits > 0 then ulx.fancyLogAdmin(appelant, "#A a délié #T", faits) end
	end, "!delier")
	delier:addParam({ type = ULib.cmds.PlayersArg })
	delier:defaultAccess(ULib.ACCESS_ADMIN)
	delier:help("Délie un captif.")
end
hook.Add("Initialize", "origine_mise_a_terre_ulx", enregistrerULX)
hook.Add("InitPostEntity", "origine_mise_a_terre_ulx", enregistrerULX)
