--[[-----------------------------------------------------------------------
	Origine du monde — base de données (SQLite par défaut, MySQLOO en option)

	ORIGINE.DB.Requete(sql, params, callback, synchrone)
		sql      : requête avec des « ? » à la place des valeurs
		params   : liste des valeurs (échappées avec sql.SQLStr ou préparées MySQLOO)
		callback : function(lignes, erreur)
-------------------------------------------------------------------------]]

ORIGINE.DB = ORIGINE.DB or {}
local DB = ORIGINE.DB
local cfg = ORIGINE.Config.BaseDeDonnees

DB.Mode = "sqlite"
DB.Pret = false

local function compterParams(requete)
	local _, n = string.gsub(requete, "%?", "")
	return n
end

local function echapper(v)
	if v == nil then return "NULL" end
	if isbool(v) then return v and "1" or "0" end
	if isnumber(v) then
		if v ~= v or v == math.huge or v == -math.huge then return "0" end
		return tostring(v)
	end
	return sql.SQLStr(tostring(v))
end

function DB.Construire(requete, params)
	if not params then return requete end
	local i = 0
	return (string.gsub(requete, "%?", function()
		i = i + 1
		return echapper(params[i])
	end))
end

local function erreurSQL(err, requete)
	ErrorNoHalt("[Origine] Erreur SQL : " .. tostring(err) .. "\n  Requête : " .. tostring(requete) .. "\n")
end

function DB.Requete(requete, params, callback, synchrone)
	if DB.Mode == "mysql" and DB.Conn then
		local q = DB.Conn:prepare(requete)
		local n = compterParams(requete)
		for i = 1, n do
			local v = params and params[i]
			if v == nil then q:setNull(i)
			elseif isnumber(v) then q:setNumber(i, v)
			elseif isbool(v) then q:setBoolean(i, v)
			else q:setString(i, tostring(v)) end
		end
		function q:onSuccess(data)
			if callback then callback(data or {}) end
		end
		function q:onError(err)
			erreurSQL(err, requete)
			if callback then callback(nil, err) end
		end
		q:start()
		if synchrone then q:wait() end
		return
	end

	local construite = DB.Construire(requete, params)
	local res = sql.Query(construite)
	if res == false then
		local err = sql.LastError()
		erreurSQL(err, construite)
		if callback then callback(nil, err) end
		return
	end
	if callback then callback(res or {}) end
end

-- Plusieurs écritures d'un coup (transaction en SQLite)
function DB.Lot(requetes, synchrone)
	if #requetes == 0 then return end
	if DB.Mode == "sqlite" then
		sql.Begin()
		for _, r in ipairs(requetes) do DB.Requete(r[1], r[2]) end
		sql.Commit()
	else
		for _, r in ipairs(requetes) do DB.Requete(r[1], r[2], nil, synchrone) end
	end
end

-- Déclarations des tables. {sqlite, mysql} quand la syntaxe diffère.
local function auto()
	if DB.Mode == "mysql" then return "id INT NOT NULL AUTO_INCREMENT PRIMARY KEY" end
	return "id INTEGER PRIMARY KEY AUTOINCREMENT"
end

function DB.CreerTables()
	local requetes = {
		[[CREATE TABLE IF NOT EXISTS origine_comptes (
			steamid64 VARCHAR(20) NOT NULL PRIMARY KEY,
			nom_steam VARCHAR(64),
			rerolls INTEGER NOT NULL DEFAULT 0,
			dernier_slot INTEGER NOT NULL DEFAULT 1,
			reroll_gratuit INTEGER NOT NULL DEFAULT 0,
			event_debloque INTEGER NOT NULL DEFAULT 0,
			event_race VARCHAR(64),
			vip_debloque INTEGER NOT NULL DEFAULT 0,
			migration_covan BIGINT,
			migration_faite INTEGER NOT NULL DEFAULT 0,
			premiere_connexion INTEGER
		)]],
		[[CREATE TABLE IF NOT EXISTS origine_personnages (
			steamid64 VARCHAR(20) NOT NULL,
			slot INTEGER NOT NULL,
			prenom VARCHAR(64) NOT NULL,
			nom VARCHAR(64) NOT NULL,
			nom_cle VARCHAR(160) NOT NULL,
			race VARCHAR(64) NOT NULL,
			valide INTEGER NOT NULL DEFAULT 0,
			covan BIGINT NOT NULL DEFAULT 0,
			job VARCHAR(64),
			pv INTEGER, pvmax INTEGER, armure INTEGER, armuremax INTEGER,
			faim DOUBLE,
			mort INTEGER NOT NULL DEFAULT 0,
			nouveau INTEGER NOT NULL DEFAULT 1,
			armes MEDIUMTEXT, munitions MEDIUMTEXT, licences MEDIUMTEXT,
			arrete INTEGER NOT NULL DEFAULT 0,
			recherche INTEGER NOT NULL DEFAULT 0,
			recherche_raison VARCHAR(255),
			modeles MEDIUMTEXT,
			modele VARCHAR(255),
			date_creation INTEGER,
			derniere_connexion INTEGER,
			nom_a_redonner INTEGER NOT NULL DEFAULT 0,
			PRIMARY KEY (steamid64, slot)
		)]],
		[[CREATE TABLE IF NOT EXISTS origine_inventaires (
			steamid64 VARCHAR(20) NOT NULL,
			slot INTEGER NOT NULL,
			donnees MEDIUMTEXT,
			PRIMARY KEY (steamid64, slot)
		)]],
		[[CREATE TABLE IF NOT EXISTS origine_historique (
			]] .. auto() .. [[,
			date INTEGER NOT NULL,
			type VARCHAR(32) NOT NULL,
			staff_sid VARCHAR(20),
			staff_nom VARCHAR(64),
			cible_sid VARCHAR(20),
			cible_slot INTEGER,
			cible_nom VARCHAR(160),
			avant MEDIUMTEXT,
			apres MEDIUMTEXT,
			raison VARCHAR(255)
		)]],
		[[CREATE TABLE IF NOT EXISTS origine_copies (
			]] .. auto() .. [[,
			date INTEGER NOT NULL,
			type VARCHAR(8) NOT NULL,
			steamid64 VARCHAR(20) NOT NULL,
			slot INTEGER NOT NULL,
			staff_sid VARCHAR(20),
			raison VARCHAR(255),
			donnees MEDIUMTEXT,
			restauree INTEGER NOT NULL DEFAULT 0
		)]],
	}
	for _, r in ipairs(requetes) do DB.Requete(r, nil, nil, true) end

	-- Colonnes ajoutées après la première version (bases déjà créées)
	DB.AjouterColonne("origine_comptes", "vip_debloque", "INTEGER NOT NULL DEFAULT 0")

	DB.CreerIndex("origine_idx_nom", "origine_personnages", "nom_cle")
	DB.CreerIndex("origine_idx_hist_cible", "origine_historique", "cible_sid")
	DB.CreerIndex("origine_idx_hist_staff", "origine_historique", "staff_sid")
end

-- Déclaration d'une clé auto-incrémentée selon le moteur
function DB.AutoIncrement()
	return auto()
end

-- Ajoute une colonne si elle n'existe pas encore (requêtes synchrones, au démarrage)
function DB.AjouterColonne(nomTable, colonne, definition)
	local existe = false
	if DB.Mode == "mysql" then
		DB.Requete("SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?",
			{ nomTable, colonne }, function(lignes)
			existe = lignes ~= nil and #lignes > 0
		end, true)
	else
		for _, l in ipairs(sql.Query("PRAGMA table_info(" .. nomTable .. ")") or {}) do
			if l.name == colonne then existe = true end
		end
	end
	if not existe then
		DB.Requete("ALTER TABLE " .. nomTable .. " ADD COLUMN " .. colonne .. " " .. definition, nil, nil, true)
	end
end

-- Crée un index s'il n'existe pas encore
function DB.CreerIndex(nom, nomTable, colonnes)
	if DB.Mode == "mysql" then
		local existe = false
		DB.Requete("SELECT INDEX_NAME FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ?",
			{ nomTable, nom }, function(lignes)
			existe = lignes ~= nil and #lignes > 0
		end, true)
		if not existe then
			DB.Requete("CREATE INDEX " .. nom .. " ON " .. nomTable .. " (" .. colonnes .. ")", nil, nil, true)
		end
	else
		DB.Requete("CREATE INDEX IF NOT EXISTS " .. nom .. " ON " .. nomTable .. " (" .. colonnes .. ")")
	end
end

local function pret()
	DB.Pret = true
	DB.CreerTables()
	MsgC(Color(201, 164, 92), "[Origine] ", color_white, "Base de données prête (" .. DB.Mode .. ").\n")
	hook.Run("origine_BaseDeDonneesPrete")
end

function DB.Connecter()
	if cfg.Mode ~= "mysql" then
		DB.Mode = "sqlite"
		pret()
		return
	end
	local ok = pcall(require, "mysqloo")
	if not ok or not mysqloo then
		ErrorNoHalt("[Origine] MySQLOO introuvable : utilisation de SQLite.\n")
		DB.Mode = "sqlite"
		pret()
		return
	end
	local conn = mysqloo.connect(cfg.Hote, cfg.Utilisateur, cfg.MotDePasse, cfg.Base, cfg.Port)
	function conn:onConnected()
		DB.Mode = "mysql"
		DB.Conn = conn
		pret()
	end
	function conn:onConnectionFailed(err)
		ErrorNoHalt("[Origine] Connexion MySQL impossible (" .. tostring(err) .. ") : utilisation de SQLite.\n")
		DB.Mode = "sqlite"
		pret()
	end
	conn:connect()
	conn:wait()
end

DB.Connecter()
