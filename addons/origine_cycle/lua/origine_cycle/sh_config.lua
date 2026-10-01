--[[-----------------------------------------------------------------------
	Origine du monde — configuration du cycle jour/nuit

	Un cycle complet = DureeJour + DureeNuit (par défaut 15 + 45 min = 1 h).
	Heure RP : le jour va de 6 h à 18 h, la nuit de 18 h à 6 h.
	L'aube et le crépuscule (Transition) sont compris dans ces durées.

	Commandes staff (permission ULX origine_cycle_admin, dans le chat ou la console) :
	  !cycle jour               passe au jour (début de l'aube)
	  !cycle nuit               passe à la nuit (début du crépuscule)
	  !cycle heure 23:40        règle l'heure RP
	  !cycle pause / reprendre  fige ou relance le cycle (event…)
	  !cycle lune oui|non|auto  force, annule ou rend automatique la pleine lune
	  (console : origine_cycle jour, origine_cycle heure 23:40…)
-------------------------------------------------------------------------]]

ORIGINE.ConfigCycle = {
	DureeJour = 15 * 60,   -- secondes réelles
	DureeNuit = 45 * 60,
	Transition = 2 * 60,   -- durée de l'aube et du crépuscule (comprise dans les durées ci-dessus)

	-- Pleine lune : une nuit sur X (annoncée au crépuscule). Aucun effet pour l'instant.
	PleineLuneTous = 4,

	-- Noms affichés dans le HUD (« Nuit · 23:40 »)
	NomsPhases = { aube = "Aube", jour = "Jour", crepuscule = "Crépuscule", nuit = "Nuit", pleine_lune = "Pleine lune" },

	-- Messages RP dans le chat
	Messages = {
		Aube = "Le soleil se lève sur le royaume.",
		Crepuscule = "Le soleil se couche, la nuit tombe sur le royaume.",
		PleineLune = "La lune se lève, pleine et rouge… Cette nuit est une nuit de pleine lune.",
	},
	CouleurMessages = Color(220, 200, 150),

	--[[ Rendu (ignoré si StormFox 2 est installé : le cycle pilote alors son heure)
		Lumiere : lettre d'éclairage de la map (a = noir, m = normal, z = très clair).
		L'éclairage change par Paliers pendant l'aube et le crépuscule (chaque changement
		recharge l'éclairage chez les clients : pas de changement continu). ]]
	Rendu = {
		Eclairage = true,
		LumiereJour = "m",
		LumiereNuit = "c",
		Paliers = 6,

		-- Brouillard la nuit (0 = pas de brouillard). Distances en unités.
		Brouillard = true,
		BrouillardDebut = 400,
		BrouillardFin = 3500,
		BrouillardDensite = 0.85,
		BrouillardCouleur = Color(12, 14, 22),

		-- Ciel : seulement sur les maps qui utilisent un ciel peint (env_skypaint)
		Ciel = true,
		CielJour = { Haut = Vector(0.2, 0.5, 1), Bas = Vector(0.8, 1, 1), Etoiles = 0 },
		CielNuit = { Haut = Vector(0.01, 0.01, 0.03), Bas = Vector(0.02, 0.02, 0.05), Etoiles = 2 },
	},

	-- Sauvegarde de la position dans le cycle (reprise après un redémarrage)
	Fichier = "origine/cycle.json",
	IntervalleSauvegarde = 30,
}

if ORIGINE.AjouterTypeHistorique then ORIGINE.AjouterTypeHistorique("cycle", "Cycle jour/nuit") end
