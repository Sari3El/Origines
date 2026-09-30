--[[-----------------------------------------------------------------------
	Origine du monde — logs du serveur (onglet « Logs » de !origine)

	Tout est mis en file d'attente puis écrit par lots (une transaction
	toutes les quelques secondes), jamais ligne par ligne. Les logs plus
	vieux que RetentionJours sont supprimés automatiquement.
-------------------------------------------------------------------------]]

ORIGINE.Logs = ORIGINE.Logs or {}
local L = ORIGINE.Logs
local CL = ORIGINE.ConfigStaff.Logs
local DB = ORIGINE.DB

L.File = L.File or {}

---------------------------------------------------------------------------
-- Table
---------------------------------------------------------------------------
local function creerTable()
	DB.Requete([[CREATE TABLE IF NOT EXISTS origine_logs (
		]] .. DB.AutoIncrement() .. [[,
		date INTEGER NOT NULL,
		categorie VARCHAR(16) NOT NULL,
		acteur_sid VARCHAR(20),
		acteur_nom VARCHAR(160),
		cible_sid VARCHAR(20),
		cible_nom VARCHAR(160),
		texte VARCHAR(255),
		details MEDIUMTEXT
	)]], nil, nil, true)
	DB.CreerIndex("origine_idx_logs_cat", "origine_logs", "categorie, id")
	DB.CreerIndex("origine_idx_logs_acteur", "origine_logs", "acteur_sid")
	DB.CreerIndex("origine_idx_logs_cible", "origine_logs", "cible_sid")
	DB.CreerIndex("origine_idx_logs_date", "origine_logs", "date")
end
if DB.Pret then creerTable() else hook.Add("origine_BaseDeDonneesPrete", "origine_logs", creerTable) end

---------------------------------------------------------------------------
-- Ajout (en file d'attente)
---------------------------------------------------------------------------
-- Retourne sid, nom lisible d'un joueur / d'une entité / d'un texte
function L.Decrire(e)
	if isstring(e) then return nil, e end
	if not IsValid(e) then
		if e == game.GetWorld() then return nil, "Monde" end
		return nil, nil
	end
	if e:IsPlayer() then
		local pseudo = e:Nick()
		local perso = ORIGINE.NomComplet(e)
		return e:SteamID64(), perso ~= pseudo and (perso .. " (" .. pseudo .. ")") or pseudo
	end
	if e:IsWorld() then return nil, "Monde" end
	return nil, e:GetClass()
end

-- categorie, acteur (joueur/entité/texte), cible (idem), texte, détails (table)
function L.Ajouter(categorie, acteur, cible, texte, details, acteurSid, acteurNom)
	if CL.Desactivees[categorie] then return end
	local asid, anom = acteurSid, acteurNom
	if not anom then asid, anom = L.Decrire(acteur) end
	local csid, cnom = L.Decrire(cible)
	L.File[#L.File + 1] = {
		os.time(), categorie, asid, anom and ORIGINE.Tronquer(anom, 150), csid, cnom and ORIGINE.Tronquer(cnom, 150),
		ORIGINE.Tronquer(texte or "", 250), details and util.TableToJSON(details) or nil,
	}
	if #L.File >= 500 then L.Vider() end
end

local INSERTION = [[INSERT INTO origine_logs (date, categorie, acteur_sid, acteur_nom, cible_sid, cible_nom, texte, details)
	VALUES (?, ?, ?, ?, ?, ?, ?, ?)]]

function L.Vider(synchrone)
	if #L.File == 0 or not DB.Pret then return end
	local requetes = {}
	for i, l in ipairs(L.File) do requetes[i] = { INSERTION, l } end
	L.File = {}
	DB.Lot(requetes, synchrone)
end

timer.Create("origine_logs_ecriture", CL.Intervalle, 0, function() L.Vider() end)
hook.Add("ShutDown", "origine_logs", function()
	L.VidersDegats(true)
	L.Vider(true)
end)

-- Rétention
local function purger()
	DB.Requete("DELETE FROM origine_logs WHERE date < ?", { os.time() - CL.RetentionJours * 86400 })
end
timer.Simple(30, purger)
timer.Create("origine_logs_purge", 6 * 3600, 0, purger)

---------------------------------------------------------------------------
-- Lecture (menu staff) : catégorie, joueur, texte, période, page
---------------------------------------------------------------------------
local function versSid(texte)
	texte = string.Trim(texte or "")
	if texte:match("^%d+$") and #texte == 17 then return texte end
	if texte:upper():match("^STEAM_%d:%d:%d+$") then return util.SteamIDTo64(texte:upper()) end
	return nil
end

function L.Rechercher(filtres, callback)
	L.Vider()
	local conditions, params = { "categorie = ?" }, { filtres.categorie }
	local joueur = string.Trim(filtres.joueur or "")
	if joueur ~= "" then
		local sid = versSid(joueur)
		if sid then
			conditions[#conditions + 1] = "(acteur_sid = ? OR cible_sid = ?)"
			params[#params + 1] = sid
			params[#params + 1] = sid
		else
			local like = "%" .. joueur:gsub("[%%_]", "") .. "%"
			conditions[#conditions + 1] = "(acteur_nom LIKE ? OR cible_nom LIKE ?)"
			params[#params + 1] = like
			params[#params + 1] = like
		end
	end
	local texte = string.Trim(filtres.texte or "")
	if texte ~= "" then
		conditions[#conditions + 1] = "texte LIKE ?"
		params[#params + 1] = "%" .. texte:gsub("[%%_]", "") .. "%"
	end
	if (filtres.periode or 0) > 0 then
		conditions[#conditions + 1] = "date >= ?"
		params[#params + 1] = os.time() - filtres.periode
	end
	local parPage = CL.ParPage
	local page = math.max(1, filtres.page or 1)
	local requete = "SELECT * FROM origine_logs WHERE " .. table.concat(conditions, " AND ") ..
		" ORDER BY id DESC LIMIT " .. (parPage + 1) .. " OFFSET " .. ((page - 1) * parPage)
	DB.Requete(requete, params, function(lignes)
		lignes = lignes or {}
		local res = {}
		for i = 1, math.min(#lignes, parPage) do
			local l = lignes[i]
			res[i] = {
				id = tonumber(l.id), date = tonumber(l.date),
				acteur_sid = l.acteur_sid ~= "NULL" and l.acteur_sid or nil, acteur_nom = l.acteur_nom ~= "NULL" and l.acteur_nom or nil,
				cible_sid = l.cible_sid ~= "NULL" and l.cible_sid or nil, cible_nom = l.cible_nom ~= "NULL" and l.cible_nom or nil,
				texte = l.texte, details = l.details ~= "NULL" and l.details or nil,
			}
		end
		callback(res, #lignes > parPage, page)
	end)
end

---------------------------------------------------------------------------
-- Collecte : dégâts (regroupés), morts
---------------------------------------------------------------------------
local TYPES_DEGATS = {
	{ DMG_BULLET, "balle" }, { DMG_BUCKSHOT, "chevrotine" }, { DMG_SLASH, "tranchant" }, { DMG_CLUB, "contondant" },
	{ DMG_BURN, "feu" }, { DMG_BLAST, "explosion" }, { DMG_FALL, "chute" }, { DMG_CRUSH, "écrasement" },
	{ DMG_DROWN, "noyade" }, { DMG_SHOCK, "électrique" }, { DMG_POISON, "poison" }, { DMG_VEHICLE, "véhicule" },
}
local function typeDegats(dmg)
	for _, t in ipairs(TYPES_DEGATS) do
		if t[1] and dmg:IsDamageType(t[1]) then return t[2] end
	end
	return "autre"
end

local function armeDe(dmg, attaquant)
	local infl = dmg:GetInflictor()
	if IsValid(infl) and infl ~= attaquant then return infl:GetClass() end
	if IsValid(attaquant) and attaquant:IsPlayer() then
		local w = attaquant:GetActiveWeapon()
		if IsValid(w) then return w:GetClass() end
	end
	return IsValid(infl) and infl:GetClass() or "—"
end

local degats = {}

local function ecrireDegat(d)
	local texte = math.Round(d.total) .. " dégâts (" .. d.type .. ") avec " .. d.arme
	if d.coups > 1 then texte = texte .. " en " .. d.coups .. " coups" end
	L.File[#L.File + 1] = {
		os.time(), "degats", d.asid, d.anom, d.csid, d.cnom, ORIGINE.Tronquer(texte, 250),
		util.TableToJSON({ degats = math.Round(d.total, 1), coups = d.coups, type = d.type, arme = d.arme, pv_restants = d.pv }),
	}
end

function L.VidersDegats(tout)
	local maintenant = CurTime()
	for cle, d in pairs(degats) do
		if tout or maintenant - d.fin >= CL.RegroupementDegats then
			ecrireDegat(d)
			degats[cle] = nil
		end
	end
end
timer.Create("origine_logs_degats", 1, 0, function() L.VidersDegats(false) end)

hook.Add("PostEntityTakeDamage", "origine_logs", function(ent, dmg, subi)
	if not subi or CL.Desactivees.degats then return end
	local montant = dmg:GetDamage()
	if montant <= 0 then return end
	if not (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() or CL.DegatsProps) then return end
	local attaquant = dmg:GetAttacker()
	local arme = armeDe(dmg, attaquant)
	local typ = typeDegats(dmg)
	local cle = tostring(attaquant) .. "|" .. tostring(ent) .. "|" .. arme .. "|" .. typ
	local maintenant = CurTime()
	local d = degats[cle]
	if d and maintenant - d.fin < CL.RegroupementDegats then
		d.total, d.coups, d.fin, d.pv = d.total + montant, d.coups + 1, maintenant, ent:Health()
		return
	end
	if d then ecrireDegat(d) end
	local asid, anom = L.Decrire(attaquant)
	local csid, cnom = L.Decrire(ent)
	degats[cle] = {
		fin = maintenant, total = montant, coups = 1, arme = arme, type = typ, pv = ent:Health(),
		asid = asid, anom = anom or "Inconnu", csid = csid, cnom = cnom,
	}
end)

hook.Add("PlayerDeath", "origine_logs", function(victime, inflicteur, attaquant)
	local arme = IsValid(inflicteur) and inflicteur ~= attaquant and inflicteur:GetClass() or nil
	if not arme and IsValid(attaquant) and attaquant:IsPlayer() and IsValid(attaquant:GetActiveWeapon()) then
		arme = attaquant:GetActiveWeapon():GetClass()
	end
	local distance = IsValid(attaquant) and attaquant ~= victime and math.Round(attaquant:GetPos():Distance(victime:GetPos())) or 0
	local texte
	if attaquant == victime then texte = "s'est tué"
	elseif IsValid(attaquant) and attaquant:IsPlayer() then texte = "a tué avec " .. (arme or "?") .. " à " .. distance .. " u"
	else texte = "tué par " .. (select(2, L.Decrire(attaquant)) or "?") end
	if IsValid(attaquant) and attaquant:IsPlayer() and attaquant ~= victime then
		L.Ajouter("morts", attaquant, victime, texte, { arme = arme, distance = distance })
	else
		L.Ajouter("morts", victime, nil, texte, { arme = arme })
	end
end)

hook.Add("OnNPCKilled", "origine_logs", function(npc, attaquant, inflicteur)
	if not (IsValid(attaquant) and attaquant:IsPlayer()) then return end
	L.Ajouter("morts", attaquant, npc, "a tué un PNJ avec " .. (IsValid(inflicteur) and inflicteur:GetClass() or "?"))
end)

---------------------------------------------------------------------------
-- Personnages
---------------------------------------------------------------------------
local function nomPerso(p) return p and (p.prenom .. " " .. p.nom) or "?" end

hook.Add("origine_PersonnageCree", "origine_logs", function(ply, p)
	L.Ajouter("personnages", ply, nil, "création de " .. nomPerso(p) .. " (slot " .. p.slot .. ")")
end)
hook.Add("origine_Tirage", "origine_logs", function(ply, p, estReroll, ancienne)
	local texte = (estReroll and "reroll" or "tirage") .. " : " .. nomPerso(p) .. " -> " .. ORIGINE.NomRace(p.race)
	if estReroll and ancienne then texte = texte .. " (avant : " .. ORIGINE.NomRace(ancienne) .. ")" end
	L.Ajouter("personnages", ply, nil, texte, { slot = p.slot, race = p.race, ancienne = ancienne })
end)
hook.Add("origine_PersonnageCharge", "origine_logs", function(ply, p)
	L.Ajouter("personnages", ply, nil, "joue " .. nomPerso(p) .. " (slot " .. p.slot .. ", " .. ORIGINE.NomRace(p.race) .. ")", { slot = p.slot })
end)
hook.Add("origine_PersonnageDecharge", "origine_logs", function(ply, p, options)
	if options and options.deconnexion then return end
	L.Ajouter("personnages", ply, nil, "quitte " .. nomPerso(p) .. " (slot " .. p.slot .. ") et retourne au menu", { slot = p.slot })
end)
hook.Add("origine_PersonnageRenomme", "origine_logs", function(ply, p, ancien)
	L.Ajouter("personnages", ply, nil, "renomme " .. tostring(ancien) .. " en " .. nomPerso(p), { slot = p.slot })
end)

---------------------------------------------------------------------------
-- Chat
---------------------------------------------------------------------------
local function canal(texte, equipe)
	local t = string.lower(texte)
	if equipe then return "équipe" end
	if t:sub(1, 2) == "//" or t:sub(1, 5) == "/ooc " or t:sub(1, 3) == "/a " then return "OOC" end
	if t:sub(1, 4) == "/me " then return "action" end
	if t:sub(1, 3) == "/y " then return "cri" end
	if t:sub(1, 3) == "/w " then return "chuchotement" end
	if t:sub(1, 4) == "/pm " then return "MP" end
	if t:sub(1, 8) == "/advert " then return "annonce" end
	if t:sub(1, 1) == "!" or t:sub(1, 1) == "/" then return "commande" end
	return "local"
end

hook.Add("PlayerSay", "origine_logs", function(ply, texte, equipe)
	local c = canal(texte, equipe)
	L.Ajouter("chat", ply, nil, "[" .. c .. "] " .. texte, { canal = c, menu = ORIGINE.EnMenu(ply) or nil })
end)

---------------------------------------------------------------------------
-- Connexions / déconnexions
---------------------------------------------------------------------------
gameevent.Listen("player_connect")
hook.Add("player_connect", "origine_logs", function(d)
	local sid = d.networkid and util.SteamIDTo64(d.networkid) or nil
	if sid == "0" then sid = nil end
	L.Ajouter("connexions", nil, nil, "connexion en cours" .. (tonumber(d.bot) == 1 and " (bot)" or ""),
		{ steamid = d.networkid }, sid, tostring(d.name))
end)

hook.Add("PlayerInitialSpawn", "origine_logs", function(ply)
	ply.OrigineDebutSession = os.time()
	L.Ajouter("connexions", ply, nil, "arrivé en jeu", { steamid = ply:SteamID() })
end)

local function duree(s)
	local h, m = math.floor(s / 3600), math.floor(s % 3600 / 60)
	if h > 0 then return h .. " h " .. m .. " min" end
	return m .. " min " .. (s % 60) .. " s"
end

gameevent.Listen("player_disconnect")
hook.Add("player_disconnect", "origine_logs", function(d)
	local ply = Player(d.userid)
	local texte = "déconnexion (" .. tostring(d.reason or "?") .. ")"
	local details = { raison = d.reason, steamid = d.networkid }
	if IsValid(ply) and ply.OrigineDebutSession then
		local s = os.time() - ply.OrigineDebutSession
		texte = texte .. " après " .. duree(s)
		details.duree = s
	end
	if IsValid(ply) then
		L.Ajouter("connexions", ply, nil, texte, details)
	else
		local sid = d.networkid and util.SteamIDTo64(d.networkid) or nil
		L.Ajouter("connexions", nil, nil, texte, details, sid ~= "0" and sid or nil, tostring(d.name))
	end
end)

---------------------------------------------------------------------------
-- Props / entités / outils
---------------------------------------------------------------------------
hook.Add("PlayerSpawnedProp", "origine_logs", function(ply, modele) L.Ajouter("props", ply, nil, "prop : " .. modele) end)
hook.Add("PlayerSpawnedSENT", "origine_logs", function(ply, ent) L.Ajouter("props", ply, nil, "entité : " .. ent:GetClass()) end)
hook.Add("PlayerSpawnedVehicle", "origine_logs", function(ply, ent) L.Ajouter("props", ply, nil, "véhicule : " .. ent:GetClass()) end)
hook.Add("PlayerSpawnedNPC", "origine_logs", function(ply, ent) L.Ajouter("props", ply, nil, "PNJ : " .. ent:GetClass()) end)
hook.Add("PlayerSpawnedRagdoll", "origine_logs", function(ply, modele) L.Ajouter("props", ply, nil, "ragdoll : " .. modele) end)
hook.Add("PlayerSpawnedEffect", "origine_logs", function(ply, modele) L.Ajouter("props", ply, nil, "effet : " .. modele) end)
hook.Add("PlayerSpawnedSWEP", "origine_logs", function(ply, ent) L.Ajouter("props", ply, nil, "arme : " .. ent:GetClass()) end)

hook.Add("CanTool", "origine_logs", function(ply, tr, outil)
	if not IsValid(ply) then return end
	local cle = outil .. "|" .. tostring(tr.Entity)
	if ply.OrigineDernierOutil == cle and CurTime() - (ply.OrigineDernierOutilDate or 0) < 1 then return end
	ply.OrigineDernierOutil, ply.OrigineDernierOutilDate = cle, CurTime()
	local cible = IsValid(tr.Entity) and (tr.Entity:GetClass() .. " " .. (tr.Entity:GetModel() or "")) or "le monde"
	L.Ajouter("props", ply, nil, "outil " .. tostring(outil) .. " sur " .. cible)
end)

---------------------------------------------------------------------------
-- Économie (hooks DarkRP)
---------------------------------------------------------------------------
local function covan(n) return ORIGINE.FormaterCovan(tonumber(n) or 0) end
local function nomObjet(t) return istable(t) and (t.name or t.entity or t.ent) or tostring(t) end

hook.Add("playerDroppedMoney", "origine_logs", function(ply, montant) L.Ajouter("economie", ply, nil, "jette " .. covan(montant), { montant = montant }) end)
hook.Add("playerPickedUpMoney", "origine_logs", function(ply, montant) L.Ajouter("economie", ply, nil, "ramasse " .. covan(montant), { montant = montant }) end)
hook.Add("playerGaveMoney", "origine_logs", function(ply, cible, montant) L.Ajouter("economie", ply, cible, "donne " .. covan(montant), { montant = montant }) end)
hook.Add("playerDroppedCheque", "origine_logs", function(ply, cible, montant) L.Ajouter("economie", ply, cible, "écrit un chèque de " .. covan(montant), { montant = montant }) end)
hook.Add("playerPickedUpCheque", "origine_logs", function(ply, cible, montant, ok) if ok then L.Ajouter("economie", ply, cible, "encaisse un chèque de " .. covan(montant), { montant = montant }) end end)
hook.Add("playerBoughtCustomEntity", "origine_logs", function(ply, t, _, prix) L.Ajouter("economie", ply, nil, "achète " .. nomObjet(t) .. " pour " .. covan(prix), { prix = prix }) end)
hook.Add("playerBoughtShipment", "origine_logs", function(ply, t, _, prix) L.Ajouter("economie", ply, nil, "achète une cargaison " .. nomObjet(t) .. " pour " .. covan(prix), { prix = prix }) end)
hook.Add("playerBoughtPistol", "origine_logs", function(ply, t, _, prix) L.Ajouter("economie", ply, nil, "achète " .. nomObjet(t) .. " pour " .. covan(prix), { prix = prix }) end)
hook.Add("playerBoughtFood", "origine_logs", function(ply, t, _, prix) L.Ajouter("economie", ply, nil, "achète " .. nomObjet(t) .. " pour " .. covan(prix), { prix = prix }) end)
hook.Add("playerBoughtVehicle", "origine_logs", function(ply, ent, prix) L.Ajouter("economie", ply, nil, "achète un véhicule (" .. (IsValid(ent) and ent:GetClass() or "?") .. ") pour " .. covan(prix), { prix = prix }) end)
hook.Add("playerBoughtDoor", "origine_logs", function(ply, _, prix) L.Ajouter("economie", ply, nil, "achète une porte pour " .. covan(prix), { prix = prix }) end)
hook.Add("playerSellDoor", "origine_logs", function(ply) L.Ajouter("economie", ply, nil, "vend une porte") end)
hook.Add("playerGetSalary", "origine_logs", function(ply, montant)
	if CL.Salaires and ORIGINE.PersoActuel(ply) then L.Ajouter("economie", ply, nil, "salaire de " .. covan(montant), { montant = montant }) end
end)

---------------------------------------------------------------------------
-- Inventaire (hooks d'origine_inventaire)
---------------------------------------------------------------------------
local ACTIONS_INV = {
	ranger = "range", equiper = "équipe depuis la sacoche", deposer = "dépose", detruire = "détruit",
	sac_cree = "meurt : sac de mort créé", sac_ouvert = "fouille un sac de mort", sac_equiper = "équipe depuis un sac",
	sac_deposer = "sort d'un sac", sac_detruire = "détruit depuis un sac", sac_tout = "transfère tout un sac",
}
hook.Add("origine_InvAction", "origine_logs", function(ply, action, objet, extra)
	local texte = ACTIONS_INV[action] or action
	if objet then texte = texte .. " " .. ORIGINE.Inv.NomObjet(objet) .. " (" .. tostring(objet.classe) .. ")" end
	if extra and extra.objets then texte = texte .. " — " .. extra.objets .. " objet(s)" end
	if extra and extra.sac and extra.sac ~= "" then texte = texte .. " de " .. extra.sac end
	L.Ajouter("inventaire", ply, nil, texte, extra)
end)

---------------------------------------------------------------------------
-- Jobs (et police si elle est réactivée dans la config)
---------------------------------------------------------------------------
hook.Add("OnPlayerChangedTeam", "origine_logs", function(ply, ancien, nouveau)
	L.Ajouter("jobs", ply, nil, (team.GetName(ancien) or "?") .. " -> " .. (team.GetName(nouveau) or "?"))
end)
hook.Add("playerArrested", "origine_logs", function(criminel, duree_, agent) L.Ajouter("police", agent, criminel, "arrestation (" .. tostring(duree_) .. " s)") end)
hook.Add("playerUnArrested", "origine_logs", function(criminel, agent) L.Ajouter("police", agent, criminel, "libération") end)
hook.Add("playerWanted", "origine_logs", function(criminel, agent, raison) L.Ajouter("police", agent, criminel, "avis de recherche : " .. tostring(raison or "")) end)
hook.Add("playerUnWanted", "origine_logs", function(criminel, agent) L.Ajouter("police", agent, criminel, "fin de l'avis de recherche") end)
hook.Add("playerWarranted", "origine_logs", function(criminel, agent, raison) L.Ajouter("police", agent, criminel, "mandat : " .. tostring(raison or "")) end)
