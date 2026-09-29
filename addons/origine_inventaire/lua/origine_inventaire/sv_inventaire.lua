--[[-----------------------------------------------------------------------
	Origine du monde — inventaire par personnage (serveur)

	Anti-duplication : un objet quitte l'inventaire avant d'apparaître dans
	le monde, et une entité quitte le monde avant d'entrer dans l'inventaire.
-------------------------------------------------------------------------]]

local I = ORIGINE.Inv
local CI = ORIGINE.ConfigInv
local DB = ORIGINE.DB

util.AddNetworkString("origine_inv")
util.AddNetworkString("origine_inv_ouvrir")

---------------------------------------------------------------------------
-- Base de données
---------------------------------------------------------------------------
function I.Lire(sid, slot, callback)
	DB.Requete("SELECT donnees FROM origine_inventaires WHERE steamid64 = ? AND slot = ?", { sid, slot }, function(lignes)
		local l = lignes and lignes[1]
		callback(l and util.JSONToTable(l.donnees or "") or {})
	end)
end

function I.EcrireBase(sid, slot, cases, synchrone)
	DB.Requete("REPLACE INTO origine_inventaires (steamid64, slot, donnees) VALUES (?, ?, ?)",
		{ sid, slot, util.TableToJSON(cases or {}) }, nil, synchrone)
end

---------------------------------------------------------------------------
-- Inventaire du personnage joué
---------------------------------------------------------------------------
function I.DuJoueur(ply)
	if not ORIGINE.PersoActuel(ply) or ply.OrigineInvSlot ~= ply.OrigineSlot then return nil end
	return ply.OrigineInv
end

function I.Envoyer(ply)
	if not IsValid(ply) then return end
	net.Start("origine_inv")
		net.WriteTable(ply.OrigineInv or {})
		net.WriteUInt(I.Capacite(ply), 8)
	net.Send(ply)
end

-- Sauvegarde regroupée : une écriture X secondes après la dernière modification
function I.Modifie(ply)
	I.Envoyer(ply)
	local sid, slot = ply:SteamID64(), ply.OrigineInvSlot
	if not slot then return end
	local cases = ply.OrigineInv
	timer.Create("origine_inv_" .. sid, CI.DelaiEcriture, 1, function()
		I.EcrireBase(sid, slot, cases)
	end)
end

function I.SauvegarderMaintenant(ply, synchrone)
	if not ply.OrigineInvSlot or not ply.OrigineInv then return end
	timer.Remove("origine_inv_" .. ply:SteamID64())
	I.EcrireBase(ply:SteamID64(), ply.OrigineInvSlot, ply.OrigineInv, synchrone)
end

hook.Add("origine_PersonnageCharge", "origine_inventaire", function(ply, p)
	ply.OrigineInv, ply.OrigineInvSlot = {}, nil
	I.Lire(p.steamid64, p.slot, function(cases)
		if not IsValid(ply) or ply.OrigineSlot ~= p.slot then return end
		ply.OrigineInv, ply.OrigineInvSlot = cases, p.slot
		I.Envoyer(ply)
	end)
	I.DonnerSacoche(ply)
end)

hook.Add("origine_PersonnageDecharge", "origine_inventaire", function(ply, _, options)
	I.SauvegarderMaintenant(ply, options and options.deconnexion)
	ply.OrigineInv, ply.OrigineInvSlot = nil, nil
	if IsValid(ply) and not (options and options.deconnexion) then I.Envoyer(ply) end
end)

hook.Add("origine_SauvegardeGenerale", "origine_inventaire", function(synchrone)
	for _, ply in ipairs(player.GetAll()) do I.SauvegarderMaintenant(ply, synchrone) end
end)

---------------------------------------------------------------------------
-- Accès pour le staff (personnage connecté ou non)
---------------------------------------------------------------------------
local function joueurSurSlot(sid, slot)
	local ply = ORIGINE.JoueurParSid(sid)
	if ply and ply.OrigineSlot == slot and ply.OrigineInvSlot == slot then return ply end
	return nil
end

function I.LireStaff(sid, slot, callback)
	local ply = joueurSurSlot(sid, slot)
	if ply then return callback(table.Copy(ply.OrigineInv)) end
	I.Lire(sid, slot, callback)
end

-- Modifie l'inventaire d'un personnage via une fonction fn(cases) ; callback(cases)
function I.ModifierStaff(sid, slot, fn, callback)
	local ply = joueurSurSlot(sid, slot)
	if ply then
		fn(ply.OrigineInv)
		I.Modifie(ply)
		if callback then callback(ply.OrigineInv) end
		return
	end
	I.Lire(sid, slot, function(cases)
		fn(cases)
		I.EcrireBase(sid, slot, cases)
		if callback then callback(cases) end
	end)
end

function I.Vider(sid, slot)
	I.ModifierStaff(sid, slot, function(cases)
		for k in pairs(cases) do cases[k] = nil end
	end)
end

---------------------------------------------------------------------------
-- Faire apparaître un objet dans le monde
---------------------------------------------------------------------------
function I.FaireApparaitre(objet, pos, ang, proprietaire)
	local ent
	if objet.arme then
		if scripted_ents.GetStored("spawned_weapon") then
			ent = ents.Create("spawned_weapon")
			if not IsValid(ent) then return nil end
			local w = weapons.GetStored(objet.arme)
			ent:SetModel(objet.modele or (w and w.WorldModel) or "models/weapons/w_pistol.mdl")
			if ent.SetWeaponClass then ent:SetWeaponClass(objet.arme) end
			if ent.Setamount then ent:Setamount(1) end
		else
			ent = ents.Create(objet.arme)
		end
	else
		ent = ents.Create(objet.classe)
		if IsValid(ent) and objet.modele and objet.modele ~= "" then ent:SetModel(objet.modele) end
	end
	if not IsValid(ent) then return nil end
	ent:SetPos(pos)
	ent:SetAngles(ang or Angle(0, 0, 0))
	ent:Spawn()
	ent:Activate()
	if IsValid(proprietaire) then
		ORIGINE.MarquerEntite(ent, proprietaire)
		if ent.CPPISetOwner then ent:CPPISetOwner(proprietaire) end
		if ent.Setowning_ent and not objet.arme then ent:Setowning_ent(proprietaire) end
	end
	return ent
end

function I.PositionDevant(ply)
	local tr = util.TraceLine({
		start = ply:EyePos(),
		endpos = ply:EyePos() + ply:GetAimVector() * 60,
		filter = ply,
	})
	return tr.HitPos + tr.HitNormal * 12, Angle(0, ply:EyeAngles().y, 0)
end

---------------------------------------------------------------------------
-- Ranger une entité (sacoche, clic gauche)
---------------------------------------------------------------------------
local function objetDepuisEntite(ent)
	local classe = ent:GetClass()
	if classe == "spawned_weapon" and ent.GetWeaponClass then
		local arme = ent:GetWeaponClass()
		return { classe = arme, arme = arme, modele = ent:GetModel() }
	end
	if ent:IsWeapon() then
		return { classe = classe, arme = classe, modele = ent:GetModel() }
	end
	return { classe = classe, modele = ent:GetModel() }
end

function I.Ranger(ply, ent)
	local cases = I.DuJoueur(ply)
	if not cases or not ply:Alive() then return end
	if not IsValid(ent) or ent:IsPlayer() or ent:IsNPC() or ent.OrigineRamasse or ent:CreatedByMap() then return end
	if ent:IsWeapon() and IsValid(ent:GetOwner()) then return end
	if I.Interdites[ent:GetClass()] then
		return ORIGINE.Notifier(ply, "Cet objet ne peut pas être rangé.", "erreur")
	end
	if ply:GetShootPos():Distance(ent:NearestPoint(ply:GetShootPos())) > CI.Portee + 10 then return end

	local objet = objetDepuisEntite(ent)
	if not I.EstAutorisee(objet.classe) then
		return ORIGINE.Notifier(ply, "Cet objet ne peut pas être rangé.", "erreur")
	end

	-- Vérifie la place AVANT de toucher à l'entité
	local essai = table.Copy(cases)
	if not I.AjouterDans(essai, objet, I.Capacite(ply)) then
		return ORIGINE.Notifier(ply, "Votre sacoche est pleine.", "erreur")
	end

	-- L'entité quitte le monde, puis entre dans l'inventaire
	local quantite = ent.Getamount and ent:GetClass() == "spawned_weapon" and ent:Getamount() or 1
	if quantite > 1 then
		ent:Setamount(quantite - 1)
	else
		ent.OrigineRamasse = true
		ent:Remove()
	end
	I.AjouterDans(cases, objet, I.Capacite(ply))
	ply:EmitSound("items/ammocrate_open.wav", 60, 120)
	I.Modifie(ply)
end

---------------------------------------------------------------------------
-- Actions sur un objet : Équiper, Déposer, Détruire
---------------------------------------------------------------------------
function I.Action(ply, action, index)
	local cases = I.DuJoueur(ply)
	if not cases or not ply:Alive() then return end
	local c = cases[index]
	if not c then return end

	if action == "equiper" then
		if not c.arme then return end
		if ply:HasWeapon(c.arme) then return ORIGINE.Notifier(ply, "Vous avez déjà cette arme.", "erreur") end
		local objet = I.RetirerDe(cases, index)
		local w = ply:Give(objet.arme)
		if not IsValid(w) then
			I.AjouterDans(cases, objet, math.huge)
			return ORIGINE.Notifier(ply, "Impossible d'équiper cette arme.", "erreur")
		end
		ply:SelectWeapon(objet.arme)
	elseif action == "deposer" then
		local objet = I.RetirerDe(cases, index)
		local pos, ang = I.PositionDevant(ply)
		if not IsValid(I.FaireApparaitre(objet, pos, ang, ply)) then
			I.AjouterDans(cases, objet, math.huge)
			return ORIGINE.Notifier(ply, "Impossible de déposer cet objet.", "erreur")
		end
	elseif action == "detruire" then
		I.RetirerDe(cases, index)
	else
		return
	end
	I.Modifie(ply)
end

ORIGINE.NetRecevoir("origine_inv_action", function(ply)
	local action = net.ReadString()
	local index = net.ReadUInt(8)
	I.Action(ply, action, index)
end, 8)

---------------------------------------------------------------------------
-- Sacoche : donnée à tous les personnages, ni jetée ni vendue
---------------------------------------------------------------------------
function I.DonnerSacoche(ply)
	if IsValid(ply) and ply:Alive() and ORIGINE.PersoActuel(ply) and not ORIGINE.EnMenu(ply)
		and not ply:HasWeapon("origine_sacoche") then
		ply:Give("origine_sacoche")
	end
end

hook.Add("PlayerLoadout", "origine_sacoche", function(ply)
	timer.Simple(0.1, function() I.DonnerSacoche(ply) end)
end)

hook.Add("OnPlayerChangedTeam", "origine_sacoche", function(ply)
	timer.Simple(0.1, function() I.DonnerSacoche(ply) end)
end)

hook.Add("canDropWeapon", "origine_sacoche", function(_, arme)
	if IsValid(arme) and arme:GetClass() == "origine_sacoche" then return false end
end)

hook.Add("PlayerCanPickupWeapon", "origine_sacoche", function(ply, arme)
	if IsValid(arme) and arme:GetClass() == "origine_sacoche" and ply:HasWeapon("origine_sacoche") then return false end
end)
