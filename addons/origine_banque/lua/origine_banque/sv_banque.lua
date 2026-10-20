--[[-----------------------------------------------------------------------
	Origine du monde — banque (serveur)

	Sécurité : tout est vérifié ici (montants entiers positifs, soldes
	suffisants, joueur à portée du guichet, droits du job).
	Chaque opération est écrite en UNE transaction SQL : bourse, compte,
	relevé et trésor passent ensemble ou pas du tout.
	Les soldes sont gardés en mémoire (le serveur est le seul à écrire) ;
	une opération à la fois par compte (verrou).
-------------------------------------------------------------------------]]

local B = ORIGINE.Banque
local CB = ORIGINE.ConfigBanque
local DB = ORIGINE.DB
local H = ORIGINE.Historique

util.AddNetworkString("origine_banque_ouvrir")
util.AddNetworkString("origine_banque_donnees")

ORIGINE.EnregistrerPermission("origine_banque_admin", "superadmin", "Banque : onglet Administration (Covan de tous les personnages)")

---------------------------------------------------------------------------
-- Tables
---------------------------------------------------------------------------
local function creerTables()
	local auto = DB.AutoIncrement()
	for _, r in ipairs({
		[[CREATE TABLE IF NOT EXISTS origine_banque_comptes (
			steamid64 VARCHAR(20) NOT NULL, slot INTEGER NOT NULL, solde BIGINT NOT NULL DEFAULT 0,
			PRIMARY KEY (steamid64, slot))]],
		[[CREATE TABLE IF NOT EXISTS origine_banque_operations (
			]] .. auto .. [[, date INTEGER NOT NULL, steamid64 VARCHAR(20) NOT NULL, slot INTEGER NOT NULL,
			type VARCHAR(24) NOT NULL, montant BIGINT NOT NULL, frais BIGINT NOT NULL DEFAULT 0,
			solde BIGINT NOT NULL, detail VARCHAR(255))]],
		[[CREATE TABLE IF NOT EXISTS origine_banque_tresor (id INTEGER NOT NULL PRIMARY KEY, solde BIGINT NOT NULL DEFAULT 0)]],
		[[CREATE TABLE IF NOT EXISTS origine_banque_mouvements (
			]] .. auto .. [[, date INTEGER NOT NULL, acteur_sid VARCHAR(20), acteur_nom VARCHAR(160),
			montant BIGINT NOT NULL, motif VARCHAR(255), solde BIGINT NOT NULL)]],
		[[CREATE TABLE IF NOT EXISTS origine_banque_prets (
			]] .. auto .. [[, date INTEGER NOT NULL, steamid64 VARCHAR(20) NOT NULL, slot INTEGER NOT NULL,
			nom VARCHAR(160), montant BIGINT NOT NULL, taux DOUBLE NOT NULL, jours INTEGER NOT NULL,
			total BIGINT NOT NULL, restant BIGINT NOT NULL, echeance INTEGER, etat VARCHAR(16) NOT NULL,
			banquier_sid VARCHAR(20), banquier_nom VARCHAR(160))]],
	}) do DB.Requete(r, nil, nil, true) end
	DB.CreerIndex("origine_idx_banque_ops", "origine_banque_operations", "steamid64, slot")
	DB.CreerIndex("origine_idx_banque_prets", "origine_banque_prets", "steamid64, slot")

	DB.Requete("SELECT solde FROM origine_banque_tresor WHERE id = 1", nil, function(l)
		if l and l[1] then
			B.Tresor = tonumber(l[1].solde) or 0
		else
			B.Tresor = 0
			DB.Requete("INSERT INTO origine_banque_tresor (id, solde) VALUES (1, 0)", nil, nil, true)
		end
	end, true)
	for _, t in ipairs({ "origine_banque_comptes", "origine_banque_operations", "origine_banque_tresor",
		"origine_banque_mouvements", "origine_banque_prets" }) do
		if not table.HasValue(ORIGINE.TablesSauvegarde or {}, t) then table.insert(ORIGINE.TablesSauvegarde, t) end
	end
end
if DB.Pret then creerTables() else hook.Add("origine_BaseDeDonneesPrete", "origine_banque", creerTables) end

---------------------------------------------------------------------------
-- Soldes en mémoire, verrous
---------------------------------------------------------------------------
B.Soldes = B.Soldes or {}
B.Verrous = B.Verrous or {}

local function cle(sid, slot) return sid .. ":" .. slot end

function B.LireSolde(sid, slot, callback)
	local k = cle(sid, slot)
	if B.Soldes[k] then return callback(B.Soldes[k]) end
	DB.Requete("SELECT solde FROM origine_banque_comptes WHERE steamid64 = ? AND slot = ?", { sid, slot }, function(l)
		if B.Soldes[k] == nil then B.Soldes[k] = tonumber(l and l[1] and l[1].solde) or 0 end
		callback(B.Soldes[k])
	end)
end

-- Une seule opération à la fois par compte : fn(liberer)
local function verrouiller(cles, fn, surRefus)
	for _, k in ipairs(cles) do
		if B.Verrous[k] then return surRefus and surRefus() end
	end
	for _, k in ipairs(cles) do B.Verrous[k] = true end
	local libere = false
	fn(function()
		if libere then return end
		libere = true
		for _, k in ipairs(cles) do B.Verrous[k] = nil end
	end)
end

-- Requêtes élémentaires (écrites dans une transaction)
local function rSolde(sid, slot, solde)
	return { "REPLACE INTO origine_banque_comptes (steamid64, slot, solde) VALUES (?, ?, ?)", { sid, slot, solde } }
end
local function rOperation(sid, slot, typ, montant, frais, solde, detail)
	return { [[INSERT INTO origine_banque_operations (date, steamid64, slot, type, montant, frais, solde, detail)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?)]], { os.time(), sid, slot, typ, montant, frais or 0, solde, detail } }
end
-- Trésor : écrit en relatif (solde = solde + delta), donc sûr même si deux opérations
-- se croisent ; la mémoire est modifiée tout de suite (réservation) et rendue en cas d'échec.
local function rTresor(delta)
	return { "UPDATE origine_banque_tresor SET solde = solde + ? WHERE id = 1", { delta } }
end
local function reserverTresor(delta)
	B.Tresor = B.Tresor + delta
	return B.Tresor
end
local function rMouvement(acteurSid, acteurNom, montant, motif, solde)
	return { [[INSERT INTO origine_banque_mouvements (date, acteur_sid, acteur_nom, montant, motif, solde)
		VALUES (?, ?, ?, ?, ?, ?)]], { os.time(), acteurSid, acteurNom, montant, motif, solde } }
end
local function rBourse(sid, slot, covan)
	return { "UPDATE origine_personnages SET covan = ? WHERE steamid64 = ? AND slot = ?", { covan, sid, slot } }
end
-- Pour sv_admin.lua
B.RequeteSolde = rSolde
B.RequeteOperation = rOperation
B.RequeteTresor = rTresor
B.ReserverTresor = reserverTresor
B.RequeteMouvement = rMouvement
B.RequeteBourse = rBourse
B.Verrouiller = verrouiller

local function nomPerso(ply) return ORIGINE.NomComplet(ply) end

---------------------------------------------------------------------------
-- Bourse du personnage joué
---------------------------------------------------------------------------
local function bourse(ply) return ply.getDarkRPVar and math.floor(ply:getDarkRPVar("money") or 0) or 0 end

-- Change la bourse du personnage joué (mémoire) ; la base est écrite dans la transaction
local function changerBourse(ply, delta)
	if ply.addMoney then ply:addMoney(delta) end
	local p = ORIGINE.PersoActuel(ply)
	if p then p.covan = bourse(ply) end
	return p and p.covan or bourse(ply)
end

local function erreur(ply, texte) ORIGINE.Notifier(ply, texte, "erreur") return false end

---------------------------------------------------------------------------
-- Guichet : portée
---------------------------------------------------------------------------
function B.APortee(ply, guichet)
	return IsValid(guichet) and guichet:GetClass() == "origine_guichet" and IsValid(ply) and ply:Alive()
		and ply:GetPos():Distance(guichet:GetPos()) <= CB.Portee
end

---------------------------------------------------------------------------
-- Dépôt / retrait
---------------------------------------------------------------------------
function B.Deposer(ply, montant, fini)
	local p = ORIGINE.PersoActuel(ply)
	if not p then return erreur(ply, "Aucun personnage chargé.") end
	if not B.MontantValide(montant) then return erreur(ply, "Montant invalide.") end
	if montant > bourse(ply) then return erreur(ply, "Vous n'avez pas autant de Covan sur vous.") end
	local sid, slot = p.steamid64, p.slot
	verrouiller({ cle(sid, slot) }, function(liberer)
		B.LireSolde(sid, slot, function(solde)
			if not IsValid(ply) or ORIGINE.PersoActuel(ply) ~= p then return liberer() end
			if montant > bourse(ply) then liberer() return erreur(ply, "Vous n'avez pas autant de Covan sur vous.") end
			local frais = B.Frais("Depot", montant)
			local nouveau = solde + montant - frais
			local covan = changerBourse(ply, -montant)
			local tresor = reserverTresor(frais)
			local reqs = { rBourse(sid, slot, covan), rSolde(sid, slot, nouveau),
				rOperation(sid, slot, "depot", montant, frais, nouveau) }
			if frais > 0 then
				reqs[#reqs + 1] = rTresor(frais)
				reqs[#reqs + 1] = rMouvement(sid, nomPerso(ply), frais, "Frais de dépôt", tresor)
			end
			DB.Transaction(reqs, function(ok)
				if ok then
					B.Soldes[cle(sid, slot)] = nouveau
					ORIGINE.Notifier(ply, "Dépôt de " .. ORIGINE.FormaterCovan(montant) .. " effectué.", "succes")
				else
					changerBourse(ply, montant)
					reserverTresor(-frais)
					erreur(ply, "L'opération a échoué, rien n'a été débité.")
				end
				liberer()
				if fini then fini() end
			end)
		end)
	end, function() erreur(ply, "Une opération est déjà en cours.") end)
	return true
end

function B.Retirer(ply, montant, fini)
	local p = ORIGINE.PersoActuel(ply)
	if not p then return erreur(ply, "Aucun personnage chargé.") end
	if not B.MontantValide(montant) then return erreur(ply, "Montant invalide.") end
	local sid, slot = p.steamid64, p.slot
	verrouiller({ cle(sid, slot) }, function(liberer)
		B.LireSolde(sid, slot, function(solde)
			if not IsValid(ply) or ORIGINE.PersoActuel(ply) ~= p then return liberer() end
			if montant > solde then liberer() return erreur(ply, "Votre compte ne contient pas autant.") end
			local frais = B.Frais("Retrait", montant)
			local nouveau = solde - montant
			local covan = changerBourse(ply, montant - frais)
			local tresor = reserverTresor(frais)
			local reqs = { rBourse(sid, slot, covan), rSolde(sid, slot, nouveau),
				rOperation(sid, slot, "retrait", -montant, frais, nouveau) }
			if frais > 0 then
				reqs[#reqs + 1] = rTresor(frais)
				reqs[#reqs + 1] = rMouvement(sid, nomPerso(ply), frais, "Frais de retrait", tresor)
			end
			DB.Transaction(reqs, function(ok)
				if ok then
					B.Soldes[cle(sid, slot)] = nouveau
					ORIGINE.Notifier(ply, "Retrait de " .. ORIGINE.FormaterCovan(montant) ..
						(frais > 0 and (" (frais : " .. ORIGINE.FormaterCovan(frais) .. ")") or "") .. " effectué.", "succes")
				else
					changerBourse(ply, -(montant - frais))
					reserverTresor(-frais)
					erreur(ply, "L'opération a échoué, rien n'a été retiré.")
				end
				liberer()
				if fini then fini() end
			end)
		end)
	end, function() erreur(ply, "Une opération est déjà en cours.") end)
	return true
end

---------------------------------------------------------------------------
-- Virement vers le personnage d'un autre joueur (connecté ou non), par son nom
---------------------------------------------------------------------------
function B.TrouverPerso(nomComplet, callback)
	local prenom, nom = string.match(string.Trim(nomComplet or ""), "^(%S+)%s+(.+)$")
	if not prenom then return callback(nil) end
	DB.Requete("SELECT steamid64, slot, prenom, nom FROM origine_personnages WHERE nom_cle = ? AND valide = 1",
		{ ORIGINE.CleNom(prenom, nom) }, function(l)
		local r = l and l[1]
		callback(r and { sid = r.steamid64, slot = tonumber(r.slot), nom = r.prenom .. " " .. r.nom } or nil)
	end)
end

function B.Virement(ply, nomCible, montant, fini)
	local p = ORIGINE.PersoActuel(ply)
	if not p then return erreur(ply, "Aucun personnage chargé.") end
	if not B.MontantValide(montant) then return erreur(ply, "Montant invalide.") end
	B.TrouverPerso(nomCible, function(cible)
		if not IsValid(ply) then return end
		if not cible then return erreur(ply, "Aucun personnage ne porte ce nom.") end
		-- Rien n'est partagé entre les personnages d'un même joueur
		if cible.sid == p.steamid64 then return erreur(ply, "Impossible de virer des Covan à un de vos propres personnages.") end
		local sid, slot = p.steamid64, p.slot
		verrouiller({ cle(sid, slot), cle(cible.sid, cible.slot) }, function(liberer)
			B.LireSolde(sid, slot, function(solde) B.LireSolde(cible.sid, cible.slot, function(soldeCible)
				if not IsValid(ply) or ORIGINE.PersoActuel(ply) ~= p then return liberer() end
				if montant > solde then liberer() return erreur(ply, "Votre compte ne contient pas autant.") end
				local frais = B.Frais("Virement", montant)
				local nouveau, nouveauCible = solde - montant, soldeCible + montant - frais
				local tresor = reserverTresor(frais)
				local reqs = {
					rSolde(sid, slot, nouveau), rOperation(sid, slot, "virement_envoye", -montant, frais, nouveau, cible.nom),
					rSolde(cible.sid, cible.slot, nouveauCible),
					rOperation(cible.sid, cible.slot, "virement_recu", montant - frais, 0, nouveauCible, nomPerso(ply)),
				}
				if frais > 0 then
					reqs[#reqs + 1] = rTresor(frais)
					reqs[#reqs + 1] = rMouvement(sid, nomPerso(ply), frais, "Frais de virement", tresor)
				end
				DB.Transaction(reqs, function(ok)
					if ok then
						B.Soldes[cle(sid, slot)] = nouveau
						B.Soldes[cle(cible.sid, cible.slot)] = nouveauCible
						ORIGINE.Notifier(ply, "Virement de " .. ORIGINE.FormaterCovan(montant) .. " envoyé à " .. cible.nom .. ".", "succes")
						local dest = ORIGINE.JoueurParSid(cible.sid)
						if dest and dest.OrigineSlot == cible.slot then
							ORIGINE.Notifier(dest, "Virement reçu de " .. nomPerso(ply) .. " : " .. ORIGINE.FormaterCovan(montant - frais) .. ".", "succes")
						end
					else
						reserverTresor(-frais)
						erreur(ply, "Le virement a échoué, rien n'a été débité.")
					end
					liberer()
					if fini then fini() end
				end)
			end) end)
		end, function() erreur(ply, "Une opération est déjà en cours sur l'un des comptes.") end)
	end)
	return true
end

---------------------------------------------------------------------------
-- Prêts
---------------------------------------------------------------------------
-- Prêt proposé ou en cours d'un personnage : callback(pret ou nil)
function B.PretActuel(sid, slot, callback)
	DB.Requete([[SELECT * FROM origine_banque_prets WHERE steamid64 = ? AND slot = ?
		AND (etat = 'propose' OR etat = 'en_cours') ORDER BY id DESC LIMIT 1]], { sid, slot }, function(l)
		local r = l and l[1]
		if not r then return callback(nil) end
		for _, c in ipairs({ "id", "date", "slot", "montant", "taux", "jours", "total", "restant", "echeance" }) do
			r[c] = tonumber(r[c])
		end
		r.en_retard = r.etat == "en_cours" and r.echeance ~= nil and r.echeance < os.time()
		callback(r)
	end)
end

function B.Proposer(banquier, nomCible, montant, taux, jours, fini)
	if not B.ADroit(banquier, "Preter") then return erreur(banquier, "Votre métier ne permet pas d'accorder des prêts.") end
	if not B.MontantValide(montant) or montant > CB.Pret.MontantMax then
		return erreur(banquier, "Montant invalide (maximum " .. ORIGINE.FormaterCovan(CB.Pret.MontantMax) .. ").")
	end
	taux, jours = tonumber(taux), tonumber(jours)
	if not taux or taux < 0 or taux > CB.Pret.TauxMax then return erreur(banquier, "Taux invalide (maximum " .. CB.Pret.TauxMax .. " %).") end
	if not jours or jours ~= math.floor(jours) or jours < 1 or jours > CB.Pret.EcheanceMaxJours then
		return erreur(banquier, "Échéance invalide (1 à " .. CB.Pret.EcheanceMaxJours .. " jours).")
	end
	if montant > B.Tresor then return erreur(banquier, "Le trésor ne contient pas assez de Covan.") end
	B.TrouverPerso(nomCible, function(cible)
		if not IsValid(banquier) then return end
		if not cible then return erreur(banquier, "Aucun personnage ne porte ce nom.") end
		if cible.sid == banquier:SteamID64() then return erreur(banquier, "Impossible de vous prêter à vous-même.") end
		verrouiller({ cle(cible.sid, cible.slot) }, function(liberer)
		B.PretActuel(cible.sid, cible.slot, function(pret)
			if pret then liberer() return erreur(banquier, cible.nom .. " a déjà un prêt en cours ou proposé.") end
			DB.Requete([[INSERT INTO origine_banque_prets (date, steamid64, slot, nom, montant, taux, jours, total, restant,
				echeance, etat, banquier_sid, banquier_nom) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, 'propose', ?, ?)]], {
				os.time(), cible.sid, cible.slot, cible.nom, montant, taux, jours, B.TotalDu(montant, taux),
				B.TotalDu(montant, taux), banquier:SteamID64(), nomPerso(banquier),
			}, function(res)
				liberer()
				if not IsValid(banquier) then return end
				if not res then return erreur(banquier, "La proposition a échoué.") end
				ORIGINE.Notifier(banquier, "Prêt proposé à " .. cible.nom .. ".", "succes")
				local dest = ORIGINE.JoueurParSid(cible.sid)
				if dest and dest.OrigineSlot == cible.slot then
					ORIGINE.Notifier(dest, "La banque vous propose un prêt : répondez au guichet.", "info")
				end
				if fini then fini() end
			end)
		end)
		end, function() erreur(banquier, "Une opération est déjà en cours sur ce compte.") end)
	end)
	return true
end

function B.Repondre(ply, accepte, fini)
	local p = ORIGINE.PersoActuel(ply)
	if not p then return erreur(ply, "Aucun personnage chargé.") end
	local sid, slot = p.steamid64, p.slot
	-- Le prêt est relu APRÈS le verrou : deux clics ne peuvent pas l'accepter deux fois
	verrouiller({ cle(sid, slot) }, function(liberer)
		B.PretActuel(sid, slot, function(pret)
			if not IsValid(ply) then return liberer() end
			if not pret or pret.etat ~= "propose" then liberer() return erreur(ply, "Aucun prêt proposé.") end
			if not accepte then
				DB.Requete("UPDATE origine_banque_prets SET etat = 'refuse' WHERE id = ?", { pret.id }, function()
					ORIGINE.Notifier(ply, "Prêt refusé.", "info")
					liberer()
					if fini then fini() end
				end)
				return
			end
			B.LireSolde(sid, slot, function(solde)
				if pret.montant > B.Tresor then liberer() return erreur(ply, "Le trésor ne peut plus financer ce prêt.") end
				local nouveau = solde + pret.montant
				local tresor = reserverTresor(-pret.montant)
				local echeance = os.time() + pret.jours * 86400
				DB.Transaction({
					{ "UPDATE origine_banque_prets SET etat = 'en_cours', echeance = ?, restant = ? WHERE id = ?",
						{ echeance, pret.total, pret.id } },
					rSolde(sid, slot, nouveau), rOperation(sid, slot, "pret", pret.montant, 0, nouveau, "Prêt n°" .. pret.id),
					rTresor(-pret.montant), rMouvement(pret.banquier_sid, pret.banquier_nom, -pret.montant,
						"Prêt n°" .. pret.id .. " à " .. (pret.nom or "?"), tresor),
				}, function(ok)
					if ok then
						B.Soldes[cle(sid, slot)] = nouveau
						ORIGINE.Notifier(ply, "Prêt accepté : " .. ORIGINE.FormaterCovan(pret.montant) .. " versés sur votre compte.", "succes")
					else
						reserverTresor(pret.montant)
						erreur(ply, "L'opération a échoué.")
					end
					liberer()
					if fini then fini() end
				end)
			end)
		end)
	end, function() erreur(ply, "Une opération est déjà en cours.") end)
	return true
end

-- Remboursement depuis le compte, en une ou plusieurs fois
function B.Rembourser(ply, montant, fini)
	local p = ORIGINE.PersoActuel(ply)
	if not p then return erreur(ply, "Aucun personnage chargé.") end
	if not B.MontantValide(montant) then return erreur(ply, "Montant invalide.") end
	local sid, slot = p.steamid64, p.slot
	verrouiller({ cle(sid, slot) }, function(liberer)
		B.PretActuel(sid, slot, function(pret)
			if not IsValid(ply) then return liberer() end
			if not pret or pret.etat ~= "en_cours" then liberer() return erreur(ply, "Aucun prêt en cours.") end
			local m = math.min(montant, pret.restant)
			B.LireSolde(sid, slot, function(solde)
				if m > solde then liberer() return erreur(ply, "Votre compte ne contient pas autant.") end
				local nouveau = solde - m
				local restant = pret.restant - m
				local tresor = reserverTresor(m)
				DB.Transaction({
					{ "UPDATE origine_banque_prets SET restant = ?, etat = ? WHERE id = ?",
						{ restant, restant <= 0 and "rembourse" or "en_cours", pret.id } },
					rSolde(sid, slot, nouveau), rOperation(sid, slot, "remboursement", -m, 0, nouveau, "Prêt n°" .. pret.id),
					rTresor(m), rMouvement(sid, nomPerso(ply), m, "Remboursement du prêt n°" .. pret.id, tresor),
				}, function(ok)
					if ok then
						B.Soldes[cle(sid, slot)] = nouveau
						ORIGINE.Notifier(ply, restant <= 0 and "Prêt entièrement remboursé." or
							("Remboursement effectué, reste " .. ORIGINE.FormaterCovan(restant) .. "."), "succes")
					else
						reserverTresor(-m)
						erreur(ply, "L'opération a échoué.")
					end
					liberer()
					if fini then fini() end
				end)
			end)
		end)
	end, function() erreur(ply, "Une opération est déjà en cours.") end)
	return true
end

---------------------------------------------------------------------------
-- Trésor : retrait vers la bourse (dirigeant)
---------------------------------------------------------------------------
function B.RetirerTresor(ply, montant, motif, fini)
	if not B.ADroit(ply, "Retirer") then return erreur(ply, "Votre métier ne permet pas de retirer du trésor.") end
	local p = ORIGINE.PersoActuel(ply)
	if not p then return erreur(ply, "Aucun personnage chargé.") end
	if not B.MontantValide(montant) then return erreur(ply, "Montant invalide.") end
	motif = ORIGINE.Tronquer(string.Trim(motif or ""), 120)
	if motif == "" then return erreur(ply, "Indiquez un motif.") end
	verrouiller({ cle(p.steamid64, p.slot) }, function(liberer)
		if montant > B.Tresor then liberer() return erreur(ply, "Le trésor ne contient pas autant.") end
		local tresor = reserverTresor(-montant)
		local covan = changerBourse(ply, montant)
		DB.Transaction({
			rBourse(p.steamid64, p.slot, covan), rTresor(-montant),
			rMouvement(p.steamid64, nomPerso(ply), -montant, "Retrait : " .. motif, tresor),
		}, function(ok)
			if ok then
				ORIGINE.Notifier(ply, ORIGINE.FormaterCovan(montant) .. " retirés du trésor.", "succes")
			else
				changerBourse(ply, -montant)
				reserverTresor(montant)
				erreur(ply, "L'opération a échoué.")
			end
			liberer()
			if fini then fini() end
		end)
	end, function() erreur(ply, "Une opération est déjà en cours.") end)
	return true
end

---------------------------------------------------------------------------
-- Données du menu (envoyées à l'ouverture et après chaque opération)
---------------------------------------------------------------------------
local function lignes(l) return l or {} end

function B.EnvoyerDonnees(ply, guichet)
	local p = ORIGINE.PersoActuel(ply)
	if not p then return end
	local sid, slot = p.steamid64, p.slot
	local d = {
		guichet = guichet:EntIndex(),
		bourse = bourse(ply),
		frais = CB.Frais,
		pretMax = CB.Pret,
		droits = { consulter = B.ADroit(ply, "Consulter"), preter = B.ADroit(ply, "Preter"), retirer = B.ADroit(ply, "Retirer") },
		admin = ORIGINE.APermission(ply, "origine_banque_admin"),
		types = B.TypesOperation,
	}
	B.LireSolde(sid, slot, function(solde)
		d.solde = solde
		DB.Requete("SELECT date, type, montant, frais, solde, detail FROM origine_banque_operations WHERE steamid64 = ? AND slot = ? ORDER BY id DESC LIMIT " .. CB.Releve,
			{ sid, slot }, function(releve)
			d.releve = lignes(releve)
			B.PretActuel(sid, slot, function(pret)
				d.pret = pret
				local function envoyer()
					if not IsValid(ply) then return end
					net.Start("origine_banque_donnees")
						ORIGINE.NetEcrireTable(d)
					net.Send(ply)
				end
				if not (d.droits.consulter or d.droits.preter) then return envoyer() end
				d.tresor = B.Tresor
				DB.Requete("SELECT date, acteur_nom, montant, motif, solde FROM origine_banque_mouvements ORDER BY id DESC LIMIT " .. CB.MouvementsAffiches,
					nil, function(mvts)
					d.mouvements = d.droits.consulter and lignes(mvts) or nil
					-- Débiteurs : prêts en cours dont l'échéance est passée
					DB.Requete("SELECT id, nom, restant, echeance, banquier_nom FROM origine_banque_prets WHERE etat = 'en_cours' AND echeance < ? ORDER BY echeance",
						{ os.time() }, function(deb)
						d.debiteurs = d.droits.preter and lignes(deb) or nil
						envoyer()
					end)
				end)
			end)
		end)
	end)
end

---------------------------------------------------------------------------
-- Réseau : une action = { guichet, action, arguments }
---------------------------------------------------------------------------
local ACTIONS = {
	deposer = function(ply, a, fini) return B.Deposer(ply, tonumber(a.montant), fini) end,
	retirer = function(ply, a, fini) return B.Retirer(ply, tonumber(a.montant), fini) end,
	virement = function(ply, a, fini) return B.Virement(ply, tostring(a.nom or ""), tonumber(a.montant), fini) end,
	accepter = function(ply, _, fini) return B.Repondre(ply, true, fini) end,
	refuser = function(ply, _, fini) return B.Repondre(ply, false, fini) end,
	rembourser = function(ply, a, fini) return B.Rembourser(ply, tonumber(a.montant), fini) end,
	proposer = function(ply, a, fini) return B.Proposer(ply, tostring(a.nom or ""), tonumber(a.montant), a.taux, a.jours, fini) end,
	retirer_tresor = function(ply, a, fini) return B.RetirerTresor(ply, tonumber(a.montant), tostring(a.motif or ""), fini) end,
}
B.Actions = ACTIONS

ORIGINE.NetRecevoir("origine_banque_action", function(ply)
	local guichet = net.ReadEntity()
	local action = net.ReadString()
	local args = ORIGINE.NetLireTable()
	if not B.APortee(ply, guichet) then return erreur(ply, "Vous êtes trop loin du guichet.") end
	if not ORIGINE.PersoActuel(ply) or ORIGINE.EnMenu(ply) then return end
	local fn = ACTIONS[action]
	if not fn or not istable(args) then return end
	local lance = fn(ply, args, function()
		if IsValid(ply) and B.APortee(ply, guichet) then B.EnvoyerDonnees(ply, guichet) end
	end)
	if lance == false then B.EnvoyerDonnees(ply, guichet) end
end, 4)

function B.Ouvrir(ply, guichet)
	if not ORIGINE.PersoActuel(ply) or ORIGINE.EnMenu(ply) then return end
	if not B.APortee(ply, guichet) then return end
	net.Start("origine_banque_ouvrir")
		net.WriteEntity(guichet)
	net.Send(ply)
	B.EnvoyerDonnees(ply, guichet)
end

---------------------------------------------------------------------------
-- CK / RPK : compte à 0 et prêt annulé (la dette disparaît) ; copie incluse
---------------------------------------------------------------------------
ORIGINE.Staff.AjouterExtensionCK({
	nom = "banque",
	lire = function(sid, slot, callback)
		B.LireSolde(sid, slot, function(solde)
			B.PretActuel(sid, slot, function(pret)
				callback({ solde = solde, pret = pret and pret.id or nil, pret_etat = pret and pret.etat or nil })
			end)
		end)
	end,
	vider = function(sid, slot)
		B.LireSolde(sid, slot, function(solde)
			B.Soldes[cle(sid, slot)] = 0
			DB.Transaction({
				rSolde(sid, slot, 0), rOperation(sid, slot, "ck", -solde, 0, 0),
				{ "UPDATE origine_banque_prets SET etat = 'annule' WHERE steamid64 = ? AND slot = ? AND (etat = 'propose' OR etat = 'en_cours')", { sid, slot } },
			})
		end)
	end,
	restaurer = function(sid, slot, d)
		local solde = math.max(0, math.floor(tonumber(d.solde) or 0))
		B.Soldes[cle(sid, slot)] = solde
		local reqs = { rSolde(sid, slot, solde), rOperation(sid, slot, "restauration", solde, 0, solde) }
		if d.pret and d.pret_etat then
			reqs[#reqs + 1] = { "UPDATE origine_banque_prets SET etat = ? WHERE id = ?", { d.pret_etat, d.pret } }
		end
		DB.Transaction(reqs)
	end,
})

-- Le changement de slot vide le cache des comptes du joueur (il sera relu)
hook.Add("PlayerDisconnected", "origine_banque", function(ply)
	local sid = ply:SteamID64()
	for slot = 1, 5 do
		local k = cle(sid, slot)
		if not B.Verrous[k] then B.Soldes[k] = nil end
	end
end)

---------------------------------------------------------------------------
-- Guichets : gardés au redémarrage (data/origine/guichets/<map>.json)
---------------------------------------------------------------------------
local function fichierGuichets() return "origine/guichets/" .. game.GetMap() .. ".json" end

function B.SauvegarderGuichets()
	local liste = {}
	for _, g in ipairs(ents.FindByClass("origine_guichet")) do
		local pos, ang = g:GetPos(), g:GetAngles()
		liste[#liste + 1] = { x = pos.x, y = pos.y, z = pos.z, p = ang.p, ya = ang.y, r = ang.r }
	end
	file.CreateDir("origine/guichets")
	file.Write(fichierGuichets(), util.TableToJSON(liste))
end

local function planifierSauvegarde()
	timer.Create("origine_guichets", 1, 1, B.SauvegarderGuichets)
end

hook.Add("InitPostEntity", "origine_guichets", function()
	local brut = file.Read(fichierGuichets(), "DATA")
	for _, g in ipairs(brut and util.JSONToTable(brut) or {}) do
		local e = ents.Create("origine_guichet")
		if IsValid(e) then
			e:SetPos(Vector(g.x, g.y, g.z))
			e:SetAngles(Angle(g.p, g.ya, g.r))
			e.OrigineCharge = true
			e:Spawn()
		end
	end
	B.GuichetsCharges = true
end)

hook.Add("PlayerSpawnedSENT", "origine_guichets", function(_, ent)
	if IsValid(ent) and ent:GetClass() == "origine_guichet" then planifierSauvegarde() end
end)
hook.Add("PhysgunDrop", "origine_guichets", function(_, ent)
	if IsValid(ent) and ent:GetClass() == "origine_guichet" then planifierSauvegarde() end
end)
hook.Add("EntityRemoved", "origine_guichets", function(ent)
	if B.GuichetsCharges and not B.Arret and IsValid(ent) and ent:GetClass() == "origine_guichet" then planifierSauvegarde() end
end)
hook.Add("ShutDown", "origine_guichets", function() B.Arret = true end)

-- Seuls les admins de la banque déplacent les guichets
hook.Add("PhysgunPickup", "origine_guichets", function(ply, ent)
	if IsValid(ent) and ent:GetClass() == "origine_guichet" and not ORIGINE.APermission(ply, "origine_banque_admin") then return false end
end)
hook.Add("CanTool", "origine_guichets", function(ply, tr)
	local ent = tr and tr.Entity
	if IsValid(ent) and ent:GetClass() == "origine_guichet" and not ORIGINE.APermission(ply, "origine_banque_admin") then return false end
end)
hook.Add("PlayerSpawnSENT", "origine_guichets", function(ply, classe)
	if classe == "origine_guichet" and not ORIGINE.APermission(ply, "origine_banque_admin") then return false end
end)
