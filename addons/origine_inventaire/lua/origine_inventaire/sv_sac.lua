--[[-----------------------------------------------------------------------
	Origine du monde — sac de mort (serveur)

	À la mort, l'inventaire et les armes portées (hors armes de job et de
	race) tombent dans un sac que tout le monde peut fouiller.
-------------------------------------------------------------------------]]

local I = ORIGINE.Inv
local CI = ORIGINE.ConfigInv

util.AddNetworkString("origine_sac")
util.AddNetworkString("origine_sac_ferme")

-- DarkRP ne jette rien à la mort : c'est géré ici (sac de mort, Covan perdus)
local function reglerMortDarkRP()
	local gm = GAMEMODE or GM
	if gm and gm.Config then
		gm.Config.dropweapondeath = false
		gm.Config.dropmoneyondeath = false
	end
end
hook.Add("DarkRPFinishedLoading", "origine_sac", reglerMortDarkRP)
hook.Add("Initialize", "origine_sac", reglerMortDarkRP)

function I.CreerSac(pos, cases, nom, covan)
	local sac = ents.Create("origine_sac_mort")
	if not IsValid(sac) then return nil end
	sac.Contenu = cases or {}
	sac.Covan = covan or 0
	sac:SetPos(pos + Vector(0, 0, 16))
	sac:Spawn()
	sac:SetNW2String("origine_sac_nom", nom or "")
	sac:SetNW2Int("origine_sac_covan", sac.Covan)
	return sac
end

local function tasDeCovan(pos, montant)
	if DarkRP and DarkRP.createMoneyBag then return DarkRP.createMoneyBag(pos, montant) end
	local tas = ents.Create("spawned_money")
	if IsValid(tas) then
		tas:SetPos(pos)
		tas:Spawn()
		if tas.Setamount then tas:Setamount(montant) end
	end
end

-- À la mort : sac (Covan perdus + inventaire si Sac.Actif) et crâne.
-- Aussi appelé par origine_mise_a_terre quand un joueur se déconnecte à terre.
function I.LacherSacDeMort(ply)
	if not ORIGINE.PersoActuel(ply) then return end
	local nom = ORIGINE.NomComplet(ply)
	local pos = ply:GetPos()

	-- Covan perdus (CovanPerdusMort)
	local perdu = 0
	if ply.getDarkRPVar and ply.addMoney then
		perdu = math.floor((ply:getDarkRPVar("money") or 0) * (CI.CovanPerdusMort or 0))
		if perdu > 0 then
			ply:addMoney(-perdu)
			hook.Run("origine_CovanPerdusMort", ply, perdu)
		end
	end

	-- Inventaire et armes portées (seulement si Sac.Actif)
	local contenu = {}
	if CI.Sac.Actif then
		local cases = I.DuJoueur(ply)
		for _, c in ipairs(cases or {}) do contenu[#contenu + 1] = table.Copy(c) end
		local exclues = ORIGINE.ArmesExcluesPour(ply)
		for _, w in ipairs(ply:GetWeapons()) do
			local c = w:GetClass()
			if not exclues[c] then
				contenu[#contenu + 1] = { classe = c, arme = c, modele = w:GetWeaponWorldModel(), n = 1 }
				ply:StripWeapon(c)
			end
		end
		if cases then
			for k in pairs(cases) do cases[k] = nil end
			I.Modifie(ply)
			I.SauvegarderMaintenant(ply)
		end
	end

	local covanSac = CI.Sac.CovanDansSac and perdu or 0
	if perdu > 0 and not CI.Sac.CovanDansSac then tasDeCovan(pos + Vector(0, 0, 12), perdu) end
	if #contenu > 0 or covanSac > 0 then
		I.CreerSac(pos, contenu, nom, covanSac)
		hook.Run("origine_InvAction", ply, "sac_cree", nil, { objets = I.Compter(contenu), covan = covanSac })
	end

	-- Crâne : nourriture des créatures de la nuit
	if CI.Crane.Actif then
		local crane = ents.Create("origine_crane")
		if IsValid(crane) then
			crane:SetPos(pos + Vector(math.random(-12, 12), math.random(-12, 12), 20))
			crane:Spawn()
			crane:SetNW2String("origine_nourriture_nom", nom)
		end
	end
end

hook.Add("DoPlayerDeath", "origine_sac", function(ply) I.LacherSacDeMort(ply) end)

-- Prendre les Covan du sac (touche E)
function I.PrendreCovanSac(ply, sac)
	local montant = sac.Covan or 0
	if montant <= 0 or not ply.addMoney then return false end
	sac.Covan = 0
	sac:SetNW2Int("origine_sac_covan", 0)
	ply:addMoney(montant)
	ORIGINE.Notifier(ply, "Vous prenez " .. ORIGINE.FormaterCovan(montant) .. ".", "succes")
	ply:EmitSound("items/ammopickup.wav", 60, 110)
	hook.Run("origine_InvAction", ply, "sac_covan", nil, { covan = montant, sac = sac:GetNW2String("origine_sac_nom", "") })
	return true
end

-- Manger une nourriture (crâne, pastèque…)
function I.Manger(ply, ent)
	local cfg = CI.Nourritures[ent:GetClass()]
	if not cfg then return end
	if (cfg.PV or 0) > 0 then ply:SetHealth(math.min(ply:GetMaxHealth(), ply:Health() + cfg.PV)) end
	if (cfg.Faim or 0) > 0 and ply.setSelfDarkRPVar and ply:getDarkRPVar("Energy") then
		ply:setSelfDarkRPVar("Energy", math.min(100, ply:getDarkRPVar("Energy") + cfg.Faim))
	end
	if cfg.Son and cfg.Son ~= "" then ply:EmitSound(cfg.Son, 70, 100) end
	hook.Run("origine_Nourri", ply, ent:GetClass(), ent:GetNW2String("origine_nourriture_nom", ""))
	ply:SetNW2Entity("origine_mange", NULL)
	ent:Remove()
end

---------------------------------------------------------------------------
-- Fouille : fenêtre partagée entre tous ceux qui l'ont ouverte
---------------------------------------------------------------------------
local function peutFouiller(ply, sac)
	return IsValid(sac) and sac:GetClass() == "origine_sac_mort" and IsValid(ply) and ply:Alive()
		and ORIGINE.PersoActuel(ply) and ply:GetPos():Distance(sac:GetPos()) <= CI.Sac.Portee
end

local function envoyerSac(sac, cibles)
	net.Start("origine_sac")
		net.WriteEntity(sac)
		net.WriteTable(sac.Contenu or {})
	net.Send(cibles)
end

function I.SpectateursSac(sac)
	local liste = {}
	for ply in pairs(sac.Spectateurs or {}) do
		if IsValid(ply) then liste[#liste + 1] = ply end
	end
	return liste
end

function I.OuvrirSac(ply, sac)
	if not peutFouiller(ply, sac) then return end
	sac.Spectateurs = sac.Spectateurs or {}
	if not sac.Spectateurs[ply] then
		hook.Run("origine_InvAction", ply, "sac_ouvert", nil, { sac = sac:GetNW2String("origine_sac_nom", "") })
	end
	sac.Spectateurs[ply] = true
	envoyerSac(sac, ply)
end

function I.FermerSac(ply, sac)
	if not IsValid(sac) or not sac.Spectateurs then return end
	sac.Spectateurs[ply] = nil
	if IsValid(ply) then
		net.Start("origine_sac_ferme")
			net.WriteEntity(sac)
		net.Send(ply)
	end
end

function I.MajSac(sac)
	if #(sac.Contenu or {}) == 0 then
		sac:Remove() -- vide : il disparaît (OnRemove ferme les fenêtres)
		return
	end
	local liste = I.SpectateursSac(sac)
	if #liste > 0 then envoyerSac(sac, liste) end
end

function I.FermerSacPourTous(sac)
	local liste = I.SpectateursSac(sac)
	if #liste == 0 then return end
	net.Start("origine_sac_ferme")
		net.WriteEntity(sac)
	net.Send(liste)
end

local function positionAuSol(sac, i)
	return sac:GetPos() + Vector(math.cos(i) * 30, math.sin(i) * 30, 20)
end

ORIGINE.NetRecevoir("origine_sac_action", function(ply)
	local sac = net.ReadEntity()
	local action = net.ReadString()
	local index = net.ReadUInt(8)
	if not peutFouiller(ply, sac) or not (sac.Spectateurs and sac.Spectateurs[ply]) then return end
	local c = sac.Contenu[index]
	if not c then return end

	if action == "equiper" then
		if not c.arme then return end
		if ply:HasWeapon(c.arme) then return ORIGINE.Notifier(ply, "Vous avez déjà cette arme.", "erreur") end
		local objet = I.RetirerDe(sac.Contenu, index)
		local w = ply:Give(objet.arme)
		if not IsValid(w) then
			I.AjouterDans(sac.Contenu, objet, math.huge)
			return ORIGINE.Notifier(ply, "Impossible d'équiper cette arme.", "erreur")
		end
		hook.Run("origine_InvAction", ply, "sac_equiper", objet)
	elseif action == "deposer" then
		local objet = I.RetirerDe(sac.Contenu, index)
		if not IsValid(I.FaireApparaitre(objet, positionAuSol(sac, index), nil, ply)) then
			I.AjouterDans(sac.Contenu, objet, math.huge)
			return
		end
		hook.Run("origine_InvAction", ply, "sac_deposer", objet)
	elseif action == "detruire" then
		hook.Run("origine_InvAction", ply, "sac_detruire", I.RetirerDe(sac.Contenu, index))
	else
		return
	end
	I.MajSac(sac)
end, 8)

-- « Tout transférer » : vers l'inventaire (capacité et piles respectées), le reste au sol
ORIGINE.NetRecevoir("origine_sac_tout", function(ply)
	local sac = net.ReadEntity()
	if not peutFouiller(ply, sac) or not (sac.Spectateurs and sac.Spectateurs[ply]) then return end
	local cases = I.DuJoueur(ply)
	if not cases then return end

	-- Le contenu quitte le sac d'abord (aucune duplication possible)
	local contenu = sac.Contenu
	sac.Contenu = {}
	local capacite, auSol = I.Capacite(ply), 0
	for _, c in ipairs(contenu) do
		for _ = 1, (c.n or 1) do
			local objet = I.Copier(c)
			if not I.AjouterDans(cases, objet, capacite) then
				auSol = auSol + 1
				I.FaireApparaitre(objet, positionAuSol(sac, auSol), nil, ply)
			end
		end
	end
	I.Modifie(ply)
	hook.Run("origine_InvAction", ply, "sac_tout", nil, { objets = I.Compter(contenu), au_sol = auSol })
	if auSol > 0 then
		ORIGINE.Notifier(ply, auSol .. " objet(s) ne rentrai(en)t pas : posé(s) au sol.", "info")
	end
	I.MajSac(sac)
end, 3)

ORIGINE.NetRecevoir("origine_sac_fermer", function(ply)
	I.FermerSac(ply, net.ReadEntity())
end, 6)
