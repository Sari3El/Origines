--[[-----------------------------------------------------------------------
	Origine du monde — sauvegardes

	Quand : changement de personnage, déconnexion, toutes les 5 minutes
	(un crash ne déclenche aucune déconnexion), arrêt du serveur, et à
	chaque modification d'inventaire (origine_inventaire).

	Copie complète des tables Origine chaque jour, gardée 7 jours :
	garrysmod/data/origine/sauvegardes/origine_AAAA-MM-JJ.json
-------------------------------------------------------------------------]]

local C = ORIGINE.Config
local DB = ORIGINE.DB

-- Sauvegarde de tous les joueurs, regroupée en une transaction
function ORIGINE.SauvegarderTout(synchrone)
	local requetes = {}
	for _, ply in ipairs(player.GetAll()) do
		local p = ORIGINE.CapturerEtat(ply)
		if p then
			if synchrone then p.derniere_connexion = os.time() end
			-- Seulement les personnages qui ont changé depuis la dernière écriture
			local r, params = ORIGINE.RequetePersoSiModifie(p)
			if r then requetes[#requetes + 1] = { r, params } end
		end
	end
	DB.Lot(requetes, synchrone)
	hook.Run("origine_SauvegardeGenerale", synchrone)
end

timer.Create("origine_sauvegarde_auto", C.Sauvegarde.Intervalle, 0, function()
	ORIGINE.SauvegarderTout(false)
end)

hook.Add("ShutDown", "origine_sauvegarde", function()
	ORIGINE.SauvegarderTout(true)
end)

---------------------------------------------------------------------------
-- Copie journalière
---------------------------------------------------------------------------
local DOSSIER = "origine/sauvegardes"
local TABLES = { "origine_comptes", "origine_personnages", "origine_inventaires", "origine_historique", "origine_copies" }

function ORIGINE.CopieJournaliere()
	if not C.Sauvegarde.CopieJournaliere then return end
	file.CreateDir(DOSSIER)
	local nom = DOSSIER .. "/origine_" .. os.date("%Y-%m-%d") .. ".json"
	if file.Exists(nom, "DATA") then return end

	local copie, restantes = { date = os.time(), tables = {} }, #TABLES
	for _, t in ipairs(TABLES) do
		DB.Requete("SELECT * FROM " .. t, nil, function(lignes)
			copie.tables[t] = lignes or {}
			restantes = restantes - 1
			if restantes == 0 then
				file.Write(nom, util.TableToJSON(copie))
				MsgC(Color(201, 164, 92), "[Origine] ", color_white, "Copie journalière écrite : data/" .. nom .. "\n")
				ORIGINE.NettoyerCopies()
			end
		end)
	end
end

function ORIGINE.NettoyerCopies()
	local fichiers = file.Find(DOSSIER .. "/origine_*.json", "DATA")
	table.sort(fichiers)
	local trop = #fichiers - C.Sauvegarde.JoursConservation
	for i = 1, trop do file.Delete(DOSSIER .. "/" .. fichiers[i]) end
end

hook.Add("origine_BaseDeDonneesPrete", "origine_copie", function()
	timer.Simple(10, ORIGINE.CopieJournaliere)
end)
if DB.Pret then timer.Simple(10, ORIGINE.CopieJournaliere) end
timer.Create("origine_copie_journaliere", 3600, 0, ORIGINE.CopieJournaliere)
