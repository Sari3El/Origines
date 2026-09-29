--[[-----------------------------------------------------------------------
	Origine du monde — menu staff (serveur)

	La permission ULX « origine_menu » est vérifiée côté serveur à CHAQUE
	action, pas seulement à l'ouverture du menu.
	Le joueur ciblé ne reçoit aucune notification ; tout est historisé.
-------------------------------------------------------------------------]]

ORIGINE.Staff = ORIGINE.Staff or {}
local S = ORIGINE.Staff
local CS = ORIGINE.ConfigStaff
local C = ORIGINE.Config
local I = ORIGINE.Inv
local DB = ORIGINE.DB
local H = ORIGINE.Historique

util.AddNetworkString("origine_staff_ouvrir")
util.AddNetworkString("origine_staff_resultats")
util.AddNetworkString("origine_staff_fiche")
util.AddNetworkString("origine_staff_historique")
util.AddNetworkString("origine_staff_logs")

---------------------------------------------------------------------------
-- Permission
---------------------------------------------------------------------------
local function enregistrerPermission()
	if ULib and ULib.ucl and ULib.ucl.registerAccess then
		ULib.ucl.registerAccess(CS.Permission, ULib.ACCESS_SUPERADMIN, "Ouvrir le menu staff Origine (!origine)", "Origine")
	end
end
hook.Add("Initialize", "origine_staff_permission", enregistrerPermission)
hook.Add("ULibLoaded", "origine_staff_permission", enregistrerPermission)
enregistrerPermission()

function S.APermission(ply)
	if not IsValid(ply) then return false end
	if ULib and ULib.ucl and ULib.ucl.query then
		return ULib.ucl.query(ply, CS.Permission) == true
	end
	return ply:IsSuperAdmin()
end

-- Groupe ULX d'un compte, même hors ligne
function S.GroupeDe(sid)
	local ply = ORIGINE.JoueurParSid(sid)
	if ply then return ply:GetUserGroup() end
	local steamid = util.SteamIDFrom64(sid)
	local u = ULib and ULib.ucl and ULib.ucl.users and ULib.ucl.users[steamid]
	return u and u.group or "user"
end

local function refuser(ply)
	ORIGINE.Notifier(ply, "Vous n'avez pas la permission.", "erreur")
end

---------------------------------------------------------------------------
-- Ouverture : !origine et commande console « origine »
---------------------------------------------------------------------------
function S.Ouvrir(ply)
	if not S.APermission(ply) then return refuser(ply) end
	net.Start("origine_staff_ouvrir")
	net.Send(ply)
end

concommand.Add("origine", function(ply)
	if IsValid(ply) then S.Ouvrir(ply) end
end)

hook.Add("PlayerSay", "origine_staff", function(ply, texte)
	local cmd = string.lower(string.Trim(texte))
	if cmd == "!origine" or cmd == "/origine" then
		S.Ouvrir(ply)
		return ""
	end
end)

-- Réception réseau réservée au staff
local function recevoirStaff(nom, fn, parSeconde)
	ORIGINE.NetRecevoir(nom, function(ply, len)
		if not S.APermission(ply) then return refuser(ply) end
		fn(ply, len)
	end, parSeconde)
end

---------------------------------------------------------------------------
-- Accès aux données (connecté ou non)
---------------------------------------------------------------------------
local function estSteamID64(s) return isstring(s) and s:match("^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d$") ~= nil end

local function versSid(texte)
	texte = string.Trim(texte or "")
	if estSteamID64(texte) then return texte end
	if texte:upper():match("^STEAM_%d:%d:%d+$") then return util.SteamIDTo64(texte:upper()) end
	return nil
end

-- callback(compte, persos, ply)
function S.Donnees(sid, callback)
	local ply = ORIGINE.JoueurParSid(sid)
	if ply and ply.OrigineDonneesChargees then
		ORIGINE.CapturerEtat(ply)
		return callback(ply.OrigineCompte, ply.OriginePersos, ply)
	end
	ORIGINE.LireCompte(sid, function(compte)
		ORIGINE.LirePersos(sid, function(persos)
			callback(compte, persos, nil)
		end)
	end)
end

local function nomPerso(p) return p and (p.prenom .. " " .. p.nom) or "?" end

local function resumePerso(p)
	return {
		race = p.race, prenom = p.prenom, nom = p.nom, covan = p.covan, job = p.job,
		pv = p.pv, armure = p.armure, faim = p.faim, nom_a_redonner = p.nom_a_redonner,
	}
end

---------------------------------------------------------------------------
-- Recherche (connectés et hors ligne, par nom de personnage ou SteamID)
---------------------------------------------------------------------------
recevoirStaff("origine_staff_recherche", function(ply)
	local texte = string.Trim(net.ReadString())
	local sid = versSid(texte)
	local cle = "%" .. ORIGINE.Normaliser(texte):gsub("[%%_]", "") .. "%"
	local requete, params
	if sid then
		requete, params = "SELECT steamid64, slot, prenom, nom, race FROM origine_personnages WHERE steamid64 = ?", { sid }
	elseif texte == "" then
		requete, params = "SELECT steamid64, slot, prenom, nom, race FROM origine_personnages ORDER BY derniere_connexion DESC LIMIT " .. CS.LimiteRecherche, {}
	else
		requete, params = "SELECT steamid64, slot, prenom, nom, race FROM origine_personnages WHERE nom_cle LIKE ? LIMIT " .. CS.LimiteRecherche, { cle }
	end

	DB.Requete(requete, params, function(lignes)
		if not IsValid(ply) then return end
		local resultats, vus = {}, {}
		for _, l in ipairs(lignes or {}) do
			local s = l.steamid64
			resultats[#resultats + 1] = {
				sid = s, slot = tonumber(l.slot), nom = l.prenom .. " " .. l.nom, race = l.race,
				en_ligne = ORIGINE.JoueurParSid(s) ~= nil,
			}
			vus[s] = true
		end
		-- Joueurs connectés trouvés par leur pseudo Steam (même sans personnage)
		local bas = string.lower(texte)
		for _, p in ipairs(player.GetAll()) do
			local s = p:SteamID64()
			if not vus[s] and (sid == s or (bas ~= "" and string.find(string.lower(p:Nick()), bas, 1, true)) or texte == "") then
				resultats[#resultats + 1] = { sid = s, nom = p:Nick() .. " (Steam)", en_ligne = true }
			end
		end
		net.Start("origine_staff_resultats")
			ORIGINE.NetEcrireTable(resultats)
		net.Send(ply)
	end)
end, 3)

---------------------------------------------------------------------------
-- Fiche : compte + personnages + inventaires + copies
---------------------------------------------------------------------------
function S.EnvoyerFiche(staff, sid)
	S.Donnees(sid, function(compte, persos, cible)
		if not IsValid(staff) then return end
		local fiche = {
			sid = sid,
			en_ligne = cible ~= nil,
			slot_actuel = cible and cible.OrigineSlot or nil,
			nom_steam = cible and cible:Nick() or (compte and compte.nom_steam) or "?",
			groupe = S.GroupeDe(sid),
			compte = compte and {
				rerolls = compte.rerolls, event_debloque = compte.event_debloque,
				event_race = compte.event_race, dernier_slot = compte.dernier_slot,
				vip_debloque = compte.vip_debloque or 0,
			} or nil,
			slots = {},
			copies = {},
		}
		local groupe = fiche.groupe
		for s = 1, ORIGINE.NB_SLOTS do
			local acces
			if s <= 2 then acces = true
			elseif s == ORIGINE.SLOT_VIP then
				acces = ORIGINE.DansListe(C.GroupesVIP, groupe) or (compte and compte.vip_debloque == 1) or false
			elseif s == ORIGINE.SLOT_EVENT then acces = compte and compte.event_debloque == 1 or false
			else acces = ORIGINE.DansListe(C.GroupesStaff, groupe) end
			local p = persos and persos[s]
			fiche.slots[s] = {
				acces = acces,
				perso = p and {
					prenom = p.prenom, nom = p.nom, race = p.race, covan = p.covan,
					job = p.job and ORIGINE.NomJob(p.job) or nil, pv = p.pv, pvmax = p.pvmax,
					armure = p.armure, armuremax = p.armuremax, faim = p.faim,
					derniere = p.derniere_connexion, valide = p.valide, nom_a_redonner = p.nom_a_redonner,
				} or nil,
			}
		end

		local restants = ORIGINE.NB_SLOTS + 1
		local function fini()
			restants = restants - 1
			if restants > 0 or not IsValid(staff) then return end
			net.Start("origine_staff_fiche")
				ORIGINE.NetEcrireTable(fiche)
			net.Send(staff)
		end
		for s = 1, ORIGINE.NB_SLOTS do
			if fiche.slots[s].perso then
				I.LireStaff(sid, s, function(cases)
					fiche.slots[s].inventaire = cases
					fini()
				end)
			else
				fini()
			end
		end
		DB.Requete("SELECT id, date, type, slot, raison, restauree FROM origine_copies WHERE steamid64 = ? ORDER BY id DESC LIMIT 20", { sid }, function(lignes)
			for _, l in ipairs(lignes or {}) do
				fiche.copies[#fiche.copies + 1] = {
					id = tonumber(l.id), date = tonumber(l.date), type = l.type, slot = tonumber(l.slot),
					raison = l.raison, restauree = tonumber(l.restauree) == 1,
				}
			end
			fini()
		end)
	end)
end

recevoirStaff("origine_staff_fiche", function(ply)
	local sid = net.ReadString()
	if estSteamID64(sid) then S.EnvoyerFiche(ply, sid) end
end, 4)

---------------------------------------------------------------------------
-- Application immédiate si le joueur est connecté
---------------------------------------------------------------------------
local function rafraichirJoueur(cible, slot)
	if not IsValid(cible) then return end
	if cible.OrigineSlot == slot then
		local p = cible.OriginePersos[slot]
		ORIGINE.AppliquerIdentite(cible, p)
		ORIGINE.AppliquerRace(cible)
	elseif ORIGINE.EnMenu(cible) then
		ORIGINE.EnvoyerMenu(cible, cible.OrigineCompte and cible.OrigineCompte.dernier_slot)
	end
end

local function succes(staff, sid, texte)
	ORIGINE.Notifier(staff, texte or "Action effectuée.", "succes")
	S.EnvoyerFiche(staff, sid)
end

---------------------------------------------------------------------------
-- CK / RPK
---------------------------------------------------------------------------
function S.CK(staff, sid, slot, raison, typ)
	S.Donnees(sid, function(compte, persos, cible)
		local p = persos and persos[slot]
		if not p then return ORIGINE.Notifier(staff, "Aucun personnage sur ce slot.", "erreur") end
		I.LireStaff(sid, slot, function(inventaire)
			-- Copie complète juste avant, pour pouvoir annuler
			local copie = { perso = table.Copy(p), inventaire = inventaire }
			DB.Requete([[INSERT INTO origine_copies (date, type, steamid64, slot, staff_sid, raison, donnees, restauree)
				VALUES (?, ?, ?, ?, ?, ?, ?, 0)]], {
				os.time(), typ, sid, slot, IsValid(staff) and staff:SteamID64() or nil, raison, util.TableToJSON(copie),
			})
			local avant = resumePerso(p)

			local surSlot = cible and cible.OrigineSlot == slot
			I.Vider(sid, slot)
			p.covan = ORIGINE.MontantDepart()
			p.armes, p.munitions, p.licences = {}, {}, {}
			p.pv, p.armure, p.faim = nil, nil, 100
			p.nouveau, p.mort = true, false
			p.arrete, p.recherche, p.recherche_raison = 0, 0, nil
			p.nom_a_redonner = true
			if typ == "rpk" then p.job = ORIGINE.CommandeJob(ORIGINE.EquipeParDefaut()) end

			if surSlot then
				-- Portes libérées, props supprimés, retour au menu pour le nouveau nom
				ORIGINE.QuitterPerso(cible, { sansSauvegarde = true, slot = slot })
			end
			ORIGINE.EcrirePerso(p)
			if cible and not surSlot and ORIGINE.EnMenu(cible) then ORIGINE.EnvoyerMenu(cible) end

			H.Ajouter({
				type = typ, staff = staff, cible_sid = sid, cible_slot = slot, cible_nom = nomPerso(p),
				avant = avant, apres = resumePerso(p), raison = raison,
			})
			succes(staff, sid, (typ == "ck" and "CK" or "RPK") .. " effectué.")
		end)
	end)
end

function S.Annuler(staff, id)
	DB.Requete("SELECT * FROM origine_copies WHERE id = ?", { id }, function(lignes)
		local l = lignes and lignes[1]
		if not l then return ORIGINE.Notifier(staff, "Copie introuvable.", "erreur") end
		if tonumber(l.restauree) == 1 then return ORIGINE.Notifier(staff, "Cette copie a déjà été restaurée.", "erreur") end
		local copie = util.JSONToTable(l.donnees or "")
		if not copie or not copie.perso then return ORIGINE.Notifier(staff, "Copie illisible.", "erreur") end
		local sid, slot = l.steamid64, tonumber(l.slot)
		local p = copie.perso
		p.steamid64, p.slot = sid, slot

		ORIGINE.NomDisponible(p.prenom, p.nom, sid, slot, function(libre)
			local cible = ORIGINE.JoueurParSid(sid)
			local surSlot = cible and cible.OrigineSlot == slot
			if surSlot then ORIGINE.QuitterPerso(cible, { sansSauvegarde = true, slot = slot }) end

			p.nom_a_redonner = not libre
			if cible and cible.OriginePersos then cible.OriginePersos[slot] = p end
			ORIGINE.EcrirePerso(p)
			I.ModifierStaff(sid, slot, function(cases)
				for k in pairs(cases) do cases[k] = nil end
				for i, c in ipairs(copie.inventaire or {}) do cases[i] = c end
			end)
			DB.Requete("UPDATE origine_copies SET restauree = 1 WHERE id = ?", { id })

			if cible and ORIGINE.EnMenu(cible) then ORIGINE.EnvoyerMenu(cible, slot) end
			H.Ajouter({
				type = "annulation", staff = staff, cible_sid = sid, cible_slot = slot, cible_nom = nomPerso(p),
				avant = { copie = id, type = l.type }, apres = resumePerso(p),
			})
			succes(staff, sid, libre and "Personnage restauré." or "Personnage restauré (nom déjà pris : un nouveau nom sera demandé).")
		end)
	end)
end

---------------------------------------------------------------------------
-- Forcer un slot (joueur connecté)
---------------------------------------------------------------------------
function S.ForcerSlot(staff, cible, slot)
	if not ORIGINE.SlotAccessible(cible, slot, cible.OrigineCompte) then
		return ORIGINE.Notifier(staff, "Ce slot est verrouillé pour ce joueur.", "erreur")
	end
	local ancien = cible.OrigineSlot
	if ancien == slot then return ORIGINE.Notifier(staff, "Le joueur est déjà sur ce slot.", "erreur") end
	if ORIGINE.PersoActuel(cible) then
		ORIGINE.CapturerEtat(cible)
		ORIGINE.EcrirePerso(ORIGINE.PersoActuel(cible))
		hook.Run("origine_PersonnageDecharge", cible, ORIGINE.PersoActuel(cible), {})
		ORIGINE.NettoyerMonde(cible)
		cible.OrigineSlot = nil
	end
	local p = cible.OriginePersos[slot]
	if p and p.valide and not p.nom_a_redonner then
		ORIGINE.ChargerPerso(cible, slot)
	else
		ORIGINE.EntrerMenu(cible, slot)
	end
	H.Ajouter({
		type = "forcer_slot", staff = staff, cible_sid = cible:SteamID64(), cible_slot = slot,
		cible_nom = p and nomPerso(p) or cible:Nick(), avant = { slot = ancien }, apres = { slot = slot },
	})
	succes(staff, cible:SteamID64())
end

---------------------------------------------------------------------------
-- Slot EVENT : débloquer / verrouiller, fixer la race
---------------------------------------------------------------------------
function S.Event(staff, sid, debloque, race)
	S.Donnees(sid, function(compte, persos, cible)
		if not compte then return ORIGINE.Notifier(staff, "Ce joueur ne s'est jamais connecté.", "erreur") end
		if race ~= "" and not ORIGINE.Race(race) then return ORIGINE.Notifier(staff, "Race inconnue.", "erreur") end
		local avant = { debloque = compte.event_debloque, race = compte.event_race }
		compte.event_debloque = debloque and 1 or 0
		if race ~= "" then compte.event_race = race end
		ORIGINE.EcrireCompte(compte)

		local p = persos and persos[ORIGINE.SLOT_EVENT]
		if p and race ~= "" and p.race ~= race then
			p.race = race
			ORIGINE.EcrirePerso(p)
		end
		if cible then
			if cible.OrigineSlot == ORIGINE.SLOT_EVENT and not debloque then
				ORIGINE.QuitterPerso(cible)
			else
				rafraichirJoueur(cible, ORIGINE.SLOT_EVENT)
			end
		end
		H.Ajouter({
			type = "event", staff = staff, cible_sid = sid, cible_slot = ORIGINE.SLOT_EVENT,
			cible_nom = p and nomPerso(p) or compte.nom_steam, avant = avant,
			apres = { debloque = compte.event_debloque, race = compte.event_race },
		})
		succes(staff, sid)
	end)
end

---------------------------------------------------------------------------
-- Slot 3 : débloqué pour un joueur (en plus des groupes VIP)
---------------------------------------------------------------------------
function S.SlotVIP(staff, sid, debloque)
	S.Donnees(sid, function(compte, persos, cible)
		if not compte then return ORIGINE.Notifier(staff, "Ce joueur ne s'est jamais connecté.", "erreur") end
		local avant = compte.vip_debloque or 0
		compte.vip_debloque = debloque and 1 or 0
		ORIGINE.EcrireCompte(compte)
		if cible then
			if cible.OrigineSlot == ORIGINE.SLOT_VIP and not ORIGINE.SlotAccessible(cible, ORIGINE.SLOT_VIP, compte) then
				ORIGINE.QuitterPerso(cible, { message = "Le slot 3 est maintenant verrouillé." })
			elseif ORIGINE.EnMenu(cible) then
				ORIGINE.EnvoyerMenu(cible)
			end
		end
		local p = persos and persos[ORIGINE.SLOT_VIP]
		H.Ajouter({
			type = "vip_slot", staff = staff, cible_sid = sid, cible_slot = ORIGINE.SLOT_VIP,
			cible_nom = p and nomPerso(p) or compte.nom_steam, avant = { debloque = avant },
			apres = { debloque = compte.vip_debloque },
		})
		succes(staff, sid)
	end)
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------
local ACTIONS = {}

ACTIONS.vip_slot = function(staff, sid, _, etat)
	S.SlotVIP(staff, sid, etat == "1")
end

-- Modifier la race d'un slot (sans tirage)
ACTIONS.race = function(staff, sid, slot, race)
	if not ORIGINE.Race(race) then return ORIGINE.Notifier(staff, "Race inconnue.", "erreur") end
	S.Donnees(sid, function(_, persos, cible)
		local p = persos and persos[slot]
		if not p then return ORIGINE.Notifier(staff, "Aucun personnage sur ce slot.", "erreur") end
		local avant = p.race
		p.race = race
		ORIGINE.EcrirePerso(p)
		rafraichirJoueur(cible, slot)
		H.Ajouter({ type = "race", staff = staff, cible_sid = sid, cible_slot = slot, cible_nom = nomPerso(p),
			avant = { race = avant }, apres = { race = race } })
		succes(staff, sid)
	end)
end

-- Points de reroll : ajouter ou retirer
ACTIONS.rerolls = function(staff, sid, _, _, _, nombre)
	if nombre == 0 then return end
	ORIGINE.LireCompte(sid, function(compte)
		local avant = compte and compte.rerolls or 0
		ORIGINE.AjouterRerolls(sid, nombre, function(total)
			H.Ajouter({ type = "rerolls", staff = staff, cible_sid = sid, cible_nom = compte and compte.nom_steam,
				avant = { rerolls = avant }, apres = { rerolls = total } })
			succes(staff, sid)
		end)
	end)
end

-- Donner des points à tous les joueurs connectés (event)
ACTIONS.rerolls_tous = function(staff, sid, _, _, _, nombre)
	if nombre == 0 then return end
	local n = 0
	for _, ply in ipairs(player.GetAll()) do
		if ply.OrigineCompte then
			ORIGINE.AjouterRerolls(ply:SteamID64(), nombre)
			n = n + 1
		end
	end
	H.Ajouter({ type = "rerolls_tous", staff = staff, apres = { nombre = nombre, joueurs = n } })
	ORIGINE.Notifier(staff, nombre .. " point(s) donné(s) à " .. n .. " joueur(s).", "succes")
	if estSteamID64(sid) then S.EnvoyerFiche(staff, sid) end
end

-- Changer le nom (mêmes règles qu'à la création)
ACTIONS.nom = function(staff, sid, slot, prenom, nom)
	prenom, nom = string.Trim(prenom), string.Trim(nom)
	local ok, err = ORIGINE.ValiderNom(prenom, nom)
	if not ok then return ORIGINE.Notifier(staff, err, "erreur") end
	prenom, nom = ORIGINE.Capitaliser(prenom), ORIGINE.Capitaliser(nom)
	ORIGINE.NomDisponible(prenom, nom, sid, slot, function(libre)
		if not libre then return ORIGINE.Notifier(staff, "Ce nom est déjà pris.", "erreur") end
		S.Donnees(sid, function(_, persos, cible)
			local p = persos and persos[slot]
			if not p then return ORIGINE.Notifier(staff, "Aucun personnage sur ce slot.", "erreur") end
			local avant = nomPerso(p)
			p.prenom, p.nom, p.nom_a_redonner = prenom, nom, false
			ORIGINE.EcrirePerso(p)
			rafraichirJoueur(cible, slot)
			H.Ajouter({ type = "nom", staff = staff, cible_sid = sid, cible_slot = slot, cible_nom = nomPerso(p),
				avant = { nom = avant }, apres = { nom = nomPerso(p) } })
			succes(staff, sid)
		end)
	end)
end

ACTIONS.forcer = function(staff, sid, slot)
	local cible = ORIGINE.JoueurParSid(sid)
	if not cible or not cible.OrigineDonneesChargees then
		return ORIGINE.Notifier(staff, "Le joueur doit être connecté.", "erreur")
	end
	S.ForcerSlot(staff, cible, slot)
end

ACTIONS.event = function(staff, sid, _, etat, race)
	S.Event(staff, sid, etat == "1", race or "")
end

ACTIONS.inv_ajouter = function(staff, sid, slot, classe)
	if not I.EstAutorisee(classe) then
		return ORIGINE.Notifier(staff, "Cette entité n'est pas dans la liste autorisée.", "erreur")
	end
	local w = weapons.GetStored(classe)
	local objet
	if w then
		objet = { classe = classe, arme = classe, modele = w.WorldModel }
	else
		local e = scripted_ents.GetStored(classe)
		objet = { classe = classe, modele = e and e.t and e.t.Model or "models/props_junk/cardboard_box004a.mdl" }
	end
	S.Donnees(sid, function(_, persos)
		if not (persos and persos[slot]) then return ORIGINE.Notifier(staff, "Aucun personnage sur ce slot.", "erreur") end
		I.ModifierStaff(sid, slot, function(cases)
			I.AjouterDans(cases, objet, math.huge)
		end, function()
			H.Ajouter({ type = "inventaire", staff = staff, cible_sid = sid, cible_slot = slot,
				cible_nom = nomPerso(persos[slot]), apres = { ajout = classe } })
			succes(staff, sid)
		end)
	end)
end

ACTIONS.inv_retirer = function(staff, sid, slot, _, _, index)
	S.Donnees(sid, function(_, persos)
		local retire
		I.ModifierStaff(sid, slot, function(cases)
			retire = I.RetirerDe(cases, index)
		end, function()
			if not retire then return ORIGINE.Notifier(staff, "Objet introuvable.", "erreur") end
			H.Ajouter({ type = "inventaire", staff = staff, cible_sid = sid, cible_slot = slot,
				cible_nom = nomPerso(persos and persos[slot]), avant = { retrait = retire.classe } })
			succes(staff, sid)
		end)
	end)
end

ACTIONS.ck = function(staff, sid, slot, raison)
	raison = string.Trim(raison or "")
	if raison == "" then return ORIGINE.Notifier(staff, "La raison est obligatoire.", "erreur") end
	S.CK(staff, sid, slot, raison, "ck")
end

ACTIONS.rpk = function(staff, sid, slot, raison)
	raison = string.Trim(raison or "")
	if raison == "" then return ORIGINE.Notifier(staff, "La raison est obligatoire.", "erreur") end
	S.CK(staff, sid, slot, raison, "rpk")
end

ACTIONS.annuler = function(staff, _, _, _, _, id)
	S.Annuler(staff, id)
end

-- Message : action, sid, slot, texte a, texte b, nombre
recevoirStaff("origine_staff_action", function(ply)
	local action = net.ReadString()
	local sid = net.ReadString()
	local slot = net.ReadUInt(4)
	local a = net.ReadString()
	local b = net.ReadString()
	local n = net.ReadInt(32)
	local fn = ACTIONS[action]
	if not fn then return end
	local sansCible = action == "annuler" or action == "rerolls_tous"
	if not sansCible and not estSteamID64(sid) then return end
	local sansSlot = action == "rerolls" or action == "event" or action == "vip_slot"
	if not sansCible and not sansSlot and (slot < 1 or slot > ORIGINE.NB_SLOTS) then return end
	fn(ply, sid, slot, a, b, n)
end, 5)

---------------------------------------------------------------------------
-- Historique : filtres par joueur, par membre du staff, par type
---------------------------------------------------------------------------
recevoirStaff("origine_staff_historique", function(ply)
	local joueur = string.Trim(net.ReadString())
	local staff = string.Trim(net.ReadString())
	local typ = net.ReadString()

	local conditions, params = {}, {}
	if joueur ~= "" then
		local sid = versSid(joueur)
		if sid then
			conditions[#conditions + 1] = "cible_sid = ?"
			params[#params + 1] = sid
		else
			conditions[#conditions + 1] = "cible_nom LIKE ?"
			params[#params + 1] = "%" .. joueur:gsub("[%%_]", "") .. "%"
		end
	end
	if staff ~= "" then
		local sid = versSid(staff)
		if sid then
			conditions[#conditions + 1] = "staff_sid = ?"
			params[#params + 1] = sid
		else
			conditions[#conditions + 1] = "staff_nom LIKE ?"
			params[#params + 1] = "%" .. staff:gsub("[%%_]", "") .. "%"
		end
	end
	if typ ~= "" then
		conditions[#conditions + 1] = "type = ?"
		params[#params + 1] = typ
	end
	local requete = "SELECT * FROM origine_historique" ..
		(#conditions > 0 and (" WHERE " .. table.concat(conditions, " AND ")) or "") ..
		" ORDER BY id DESC LIMIT " .. CS.LimiteHistorique

	DB.Requete(requete, params, function(lignes)
		if not IsValid(ply) then return end
		local res = {}
		for _, l in ipairs(lignes or {}) do
			res[#res + 1] = {
				id = tonumber(l.id), date = tonumber(l.date), type = l.type,
				staff_nom = l.staff_nom, staff_sid = l.staff_sid,
				cible_nom = l.cible_nom, cible_sid = l.cible_sid, cible_slot = tonumber(l.cible_slot),
				avant = l.avant, apres = l.apres, raison = l.raison,
			}
		end
		net.Start("origine_staff_historique")
			ORIGINE.NetEcrireTable(res)
		net.Send(ply)
	end)
end, 3)

---------------------------------------------------------------------------
-- Logs : catégorie, joueur, texte, période, page
---------------------------------------------------------------------------
recevoirStaff("origine_staff_logs", function(ply)
	local filtres = {
		categorie = net.ReadString(),
		joueur = ORIGINE.Tronquer(net.ReadString(), 64),
		texte = ORIGINE.Tronquer(net.ReadString(), 64),
		periode = net.ReadUInt(32),
		page = net.ReadUInt(16),
	}
	ORIGINE.Logs.Rechercher(filtres, function(lignes, suite, page)
		if not IsValid(ply) then return end
		net.Start("origine_staff_logs")
			net.WriteString(filtres.categorie)
			net.WriteUInt(page, 16)
			net.WriteBool(suite)
			ORIGINE.NetEcrireTable(lignes)
		net.Send(ply)
	end)
end, 4)
