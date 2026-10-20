--[[-----------------------------------------------------------------------
	Origine du monde — menu TAB (serveur)

	Les joueurs ne voient que le nom Steam, le SteamID et le ping.
	Le serveur n'envoie les infos staff (badge, slot, PV, Covan) qu'aux
	joueurs ayant la permission origine_tab_staff.
	Les actions staff passent par les commandes ULX, lancées par le client :
	ULX vérifie lui-même les permissions et l'immunité côté serveur.
	Seul le changement de job (sans équivalent ULX) passe par ce fichier.
-------------------------------------------------------------------------]]

ORIGINE = ORIGINE or {}
ORIGINE.Tab = ORIGINE.Tab or {}
local T = ORIGINE.Tab
-- Normalement déjà chargé par DarkRP (sh_ avant sv_/cl_) ; sécurité si l'ordre change
if not T.Config then include("sh_config.lua") end

util.AddNetworkString("origine_tab_demande")
util.AddNetworkString("origine_tab_donnees")
util.AddNetworkString("origine_tab_job")

---------------------------------------------------------------------------
-- Permissions ULX (attribuables dans XGUI)
---------------------------------------------------------------------------
local PERMISSIONS = {
	{ "origine_tab_staff", "Menu TAB : voir les infos staff (Steam, SteamID, slot, PV, Covan)" },
	{ "origine_tab_job", "Menu TAB : changer le job d'un joueur" },
}

local function enregistrerPermissions()
	if not (ULib and ULib.ucl and ULib.ucl.registerAccess) then return end
	for _, p in ipairs(PERMISSIONS) do
		ULib.ucl.registerAccess(p[1], ULib.ACCESS_ADMIN, p[2], "Origine TAB")
	end
end
hook.Add("Initialize", "origine_tab_permissions", enregistrerPermissions)
hook.Add("ULibLoaded", "origine_tab_permissions", enregistrerPermissions)
enregistrerPermissions()

function T.APermission(ply, permission)
	if not IsValid(ply) then return false end
	if ULib and ULib.ucl and ULib.ucl.query then
		return ULib.ucl.query(ply, permission) == true
	end
	return ply:IsAdmin()
end

---------------------------------------------------------------------------
-- Anti-spam : N messages par seconde et par joueur
---------------------------------------------------------------------------
local function recevoir(nom, parSeconde, fn)
	net.Receive(nom, function(len, ply)
		if not IsValid(ply) or len > 2048 then return end
		ply.OrigineTabNet = ply.OrigineTabNet or {}
		local maintenant = CurTime()
		local t = ply.OrigineTabNet[nom]
		if not t or maintenant - t.debut >= 1 then
			t = { debut = maintenant, n = 0 }
			ply.OrigineTabNet[nom] = t
		end
		t.n = t.n + 1
		if t.n > parSeconde then return end
		fn(ply)
	end)
end

---------------------------------------------------------------------------
-- Données envoyées au TAB (à l'ouverture puis toutes les 2 s)
---------------------------------------------------------------------------
local function slotJoue(ply)
	if ORIGINE.SlotJoueur then return ORIGINE.SlotJoueur(ply) end
	return 0
end

-- Badge (staff seulement) : slot Staff ou slot EVENT, rien sur les slots RP
local function badge(ply)
	local s = slotJoue(ply)
	if ORIGINE.SLOT_STAFF and s == ORIGINE.SLOT_STAFF then return 2 end
	if ORIGINE.SLOT_EVENT and s == ORIGINE.SLOT_EVENT then return 1 end
	return 0
end

recevoir("origine_tab_demande", 3, function(ply)
	local staff = T.APermission(ply, "origine_tab_staff")
	local joueurs = player.GetAll()
	net.Start("origine_tab_donnees")
		net.WriteBool(staff)
		net.WriteUInt(#joueurs, 8)
		for _, p in ipairs(joueurs) do
			net.WriteEntity(p)
			if staff then
				net.WriteUInt(badge(p), 2)
				net.WriteUInt(slotJoue(p), 4)
				net.WriteInt(math.Clamp(p:Health(), -32768, 32767), 16)
				net.WriteDouble(p.getDarkRPVar and tonumber(p:getDarkRPVar("money")) or 0)
			end
		end
	net.Send(ply)
end)

---------------------------------------------------------------------------
-- Changer le job (permission origine_tab_job)
---------------------------------------------------------------------------
recevoir("origine_tab_job", 2, function(ply)
	local cible = net.ReadEntity()
	local commande = net.ReadString()
	if not T.APermission(ply, "origine_tab_job") then return end
	if not (IsValid(cible) and cible:IsPlayer() and cible.changeTeam) then return end

	local equipe, job
	for i, j in pairs(RPExtraTeams or {}) do
		if j.command == commande then equipe, job = i, j break end
	end
	if not equipe or job.origine_cache then return end

	-- Avec origine_staff : même chemin que !origine (job sauvegardé sur le slot, historique)
	local S = ORIGINE.Staff
	if S and S.ChangerJob and cible.OrigineSlot then
		S.ChangerJob(ply, cible:SteamID64(), cible.OrigineSlot, commande)
		return
	end
	cible:changeTeam(equipe, true, true)
	if DarkRP and DarkRP.notify then
		DarkRP.notify(ply, 0, 4, cible:Nick() .. " : job changé en " .. job.name .. ".")
	end
end)
