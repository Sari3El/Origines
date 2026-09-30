--[[-----------------------------------------------------------------------
	Origine du monde — banque : onglet Administration (serveur)

	Permission ULX origine_banque_admin, vérifiée à chaque demande.
	Chaque correction (qui, quoi, avant, après, raison) est enregistrée
	dans l'historique de !origine.
-------------------------------------------------------------------------]]

local B = ORIGINE.Banque
local C = ORIGINE.Config
local DB = ORIGINE.DB
local H = ORIGINE.Historique

util.AddNetworkString("origine_banque_admin_resultats")
util.AddNetworkString("origine_banque_admin_fiche")

local PERM = "origine_banque_admin"

local function estSid(s) return isstring(s) and s:match("^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d$") ~= nil end

local function versSid(texte)
	texte = string.Trim(texte or "")
	if estSid(texte) then return texte end
	if texte:upper():match("^STEAM_%d:%d:%d+$") then return util.SteamIDTo64(texte:upper()) end
	return nil
end

local function erreur(ply, t) ORIGINE.Notifier(ply, t, "erreur") end

---------------------------------------------------------------------------
-- Recherche : par nom de personnage ou SteamID, connecté ou hors ligne
---------------------------------------------------------------------------
local function rechercher(ply, texte)
	local sid = versSid(texte)
	local base = "SELECT p.steamid64, p.slot, p.prenom, p.nom, c.nom_steam FROM origine_personnages p " ..
		"LEFT JOIN origine_comptes c ON c.steamid64 = p.steamid64 "
	local requete, params
	if sid then
		requete, params = base .. "WHERE p.steamid64 = ?", { sid }
	elseif string.Trim(texte or "") == "" then
		requete, params = base .. "ORDER BY p.derniere_connexion DESC LIMIT 50", {}
	else
		local cle = "%" .. ORIGINE.Normaliser(texte):gsub("[%%_]", "") .. "%"
		requete, params = base .. "WHERE p.nom_cle LIKE ? LIMIT 50", { cle }
	end
	DB.Requete(requete, params, function(lignes)
		if not IsValid(ply) then return end
		local comptes, parSid = {}, {}
		for _, l in ipairs(lignes or {}) do
			local c = parSid[l.steamid64]
			if not c then
				local enLigne = ORIGINE.JoueurParSid(l.steamid64)
				c = { sid = l.steamid64, nom_steam = enLigne and ORIGINE.NomSteam(enLigne) or l.nom_steam, en_ligne = enLigne ~= nil, persos = {} }
				parSid[l.steamid64] = c
				comptes[#comptes + 1] = c
			end
			c.persos[#c.persos + 1] = { slot = tonumber(l.slot), nom = l.prenom .. " " .. l.nom }
		end
		net.Start("origine_banque_admin_resultats")
			ORIGINE.NetEcrireTable(comptes)
		net.Send(ply)
	end)
end

---------------------------------------------------------------------------
-- Fiche : les 5 slots d'un joueur (bourse, compte, prêt, total)
---------------------------------------------------------------------------
local function persosDe(sid, callback)
	local cible = ORIGINE.JoueurParSid(sid)
	if cible and cible.OrigineDonneesChargees then
		ORIGINE.CapturerEtat(cible)
		return callback(cible.OriginePersos, cible)
	end
	ORIGINE.LirePersos(sid, function(persos) callback(persos, nil) end)
end

function B.EnvoyerFicheAdmin(ply, sid)
	persosDe(sid, function(persos, cible)
		local fiche = { sid = sid, nom_steam = cible and ORIGINE.NomSteam(cible) or nil, slots = {}, tresor = B.Tresor }
		local slot = 0
		local function suivant()
			slot = slot + 1
			if slot > 5 then
				if not IsValid(ply) then return end
				net.Start("origine_banque_admin_fiche")
					ORIGINE.NetEcrireTable(fiche)
				net.Send(ply)
				return
			end
			local p = persos and persos[slot]
			local ligne = { slot = slot, type = C.Slots[slot] and C.Slots[slot].Nom or ("Slot " .. slot) }
			if slot <= 2 then ligne.type = ligne.type .. " (gratuit)" elseif slot == ORIGINE.SLOT_VIP then ligne.type = ligne.type .. " (VIP)" end
			fiche.slots[slot] = ligne
			if not p then return suivant() end
			ligne.nom = p.prenom .. " " .. p.nom
			ligne.bourse = math.floor(p.covan or 0)
			ligne.joue = cible ~= nil and cible.OrigineSlot == slot
			B.LireSolde(sid, slot, function(solde)
				ligne.compte = solde
				B.PretActuel(sid, slot, function(pret)
					ligne.pret = pret
					ligne.total = ligne.bourse + solde
					suivant()
				end)
			end)
		end
		suivant()
	end)
end

---------------------------------------------------------------------------
-- Corrections
---------------------------------------------------------------------------
local function raisonValide(r)
	r = ORIGINE.Tronquer(string.Trim(tostring(r or "")), 200)
	return r ~= "" and r or nil
end

local function entierNonNul(v)
	v = tonumber(v)
	return v ~= nil and v == math.floor(v) and v ~= 0 and math.abs(v) < 2 ^ 50 and v or nil
end

-- Bourse d'un personnage : en jeu tout de suite, sinon sa sauvegarde
local function modifierBourse(staff, sid, slot, delta, raison)
	persosDe(sid, function(persos, cible)
		local p = persos and persos[slot]
		if not p then return erreur(staff, "Aucun personnage sur ce slot.") end
		local avant = math.floor(p.covan or 0)
		local apres = avant + delta
		if apres < 0 then return erreur(staff, "La bourse ne peut pas passer sous 0.") end
		local joue = cible and cible.OrigineSlot == slot
		if joue and cible.addMoney then
			cible:addMoney(delta)
			p.covan = math.floor(cible:getDarkRPVar("money") or apres)
			apres = p.covan
		else
			p.covan = apres
		end
		DB.Transaction({ B.RequeteBourse(sid, slot, apres) }, function(ok)
			if not ok then return erreur(staff, "L'écriture a échoué.") end
			H.Ajouter({ type = "banque", staff = staff, cible_sid = sid, cible_slot = slot, cible_nom = p.prenom .. " " .. p.nom,
				avant = { bourse = avant }, apres = { bourse = apres }, raison = raison })
			ORIGINE.Notifier(staff, "Bourse corrigée.", "succes")
			B.EnvoyerFicheAdmin(staff, sid)
		end)
	end)
end

local function modifierCompte(staff, sid, slot, delta, raison)
	persosDe(sid, function(persos)
		local p = persos and persos[slot]
		if not p then return erreur(staff, "Aucun personnage sur ce slot.") end
		local k = sid .. ":" .. slot
		B.Verrouiller({ k }, function(liberer)
			B.LireSolde(sid, slot, function(avant)
				local apres = avant + delta
				if apres < 0 then liberer() return erreur(staff, "Le compte ne peut pas passer sous 0.") end
				DB.Transaction({
					B.RequeteSolde(sid, slot, apres),
					B.RequeteOperation(sid, slot, "correction", delta, 0, apres, raison),
				}, function(ok)
					if ok then
						B.Soldes[k] = apres
						H.Ajouter({ type = "banque", staff = staff, cible_sid = sid, cible_slot = slot, cible_nom = p.prenom .. " " .. p.nom,
							avant = { compte = avant }, apres = { compte = apres }, raison = raison })
						ORIGINE.Notifier(staff, "Compte corrigé.", "succes")
					else
						erreur(staff, "L'écriture a échoué.")
					end
					liberer()
					B.EnvoyerFicheAdmin(staff, sid)
				end)
			end)
		end, function() erreur(staff, "Une opération est en cours sur ce compte, réessayez.") end)
	end)
end

local function modifierTresor(staff, delta, raison, sid)
	local avant = B.Tresor
	if avant + delta < 0 then return erreur(staff, "Le trésor ne peut pas passer sous 0.") end
	local apres = B.ReserverTresor(delta)
	DB.Transaction({
		B.RequeteTresor(delta),
		B.RequeteMouvement(staff:SteamID64(), "Staff : " .. staff:Nick(), delta, "Correction : " .. raison, apres),
	}, function(ok)
		if not ok then
			B.ReserverTresor(-delta)
			return erreur(staff, "L'écriture a échoué.")
		end
		H.Ajouter({ type = "banque", staff = staff, cible_nom = "Trésor de la banque",
			avant = { tresor = avant }, apres = { tresor = apres }, raison = raison })
		ORIGINE.Notifier(staff, "Trésor corrigé.", "succes")
		if sid then B.EnvoyerFicheAdmin(staff, sid) end
	end)
end

local function annulerPret(staff, id, raison, sid)
	DB.Requete("SELECT * FROM origine_banque_prets WHERE id = ?", { id }, function(l)
		local pret = l and l[1]
		if not pret or (pret.etat ~= "propose" and pret.etat ~= "en_cours") then return erreur(staff, "Prêt introuvable ou déjà terminé.") end
		DB.Requete("UPDATE origine_banque_prets SET etat = 'annule' WHERE id = ?", { id }, function()
			H.Ajouter({ type = "banque", staff = staff, cible_sid = pret.steamid64, cible_slot = tonumber(pret.slot), cible_nom = pret.nom,
				avant = { pret = id, etat = pret.etat, restant = tonumber(pret.restant) }, apres = { pret = id, etat = "annule" }, raison = raison })
			ORIGINE.Notifier(staff, "Prêt annulé.", "succes")
			if sid then B.EnvoyerFicheAdmin(staff, sid) end
		end)
	end)
end

---------------------------------------------------------------------------
-- Réseau
---------------------------------------------------------------------------
ORIGINE.NetRecevoir("origine_banque_admin", function(ply)
	local guichet = net.ReadEntity()
	local action = net.ReadString()
	local a = ORIGINE.NetLireTable()
	if not ORIGINE.APermission(ply, PERM) then return erreur(ply, "Vous n'avez pas la permission.") end
	if not B.APortee(ply, guichet) then return erreur(ply, "Vous êtes trop loin du guichet.") end
	if not istable(a) then return end

	if action == "recherche" then return rechercher(ply, tostring(a.texte or "")) end
	if action == "fiche" then
		if estSid(a.sid) then B.EnvoyerFicheAdmin(ply, a.sid) end
		return
	end

	local raison = raisonValide(a.raison)
	if not raison then return erreur(ply, "La raison est obligatoire.") end
	if action == "tresor" then
		local delta = entierNonNul(a.montant)
		if not delta then return erreur(ply, "Montant invalide.") end
		return modifierTresor(ply, delta, raison, estSid(a.sid) and a.sid or nil)
	end
	if action == "annuler_pret" then
		local id = tonumber(a.id)
		if id then annulerPret(ply, id, raison, estSid(a.sid) and a.sid or nil) end
		return
	end

	local sid, slot = a.sid, tonumber(a.slot)
	if not estSid(sid) or not slot or slot < 1 or slot > 5 then return end
	local delta = entierNonNul(a.montant)
	if not delta then return erreur(ply, "Montant invalide (entier, positif pour ajouter, négatif pour retirer).") end
	if action == "bourse" then modifierBourse(ply, sid, slot, delta, raison)
	elseif action == "compte" then modifierCompte(ply, sid, slot, delta, raison) end
end, 4)
