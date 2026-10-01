--[[-----------------------------------------------------------------------
	Origine du monde — configuration de origine_inventaire

	La liste des entités autorisées est dans sh_entites.lua (même dossier).
-------------------------------------------------------------------------]]

ORIGINE.ConfigInv = {
	-- Distance maximum (en unités) pour ranger une entité avec la sacoche (clic gauche)
	Portee = 100,

	-- Nombre de cases de l'inventaire
	Capacite = {
		Joueur = 20,
		VIP = 30,
	},

	-- Groupes ULX qui ont la capacité VIP. nil = les mêmes que le slot VIP (origine_personnages)
	GroupesVIP = nil,

	-- Entités identiques empilées au maximum par pile (au-delà, nouvelle case)
	TaillePile = 3,

	-- Regroupement des écritures SQL : l'inventaire est écrit X secondes après la dernière modification
	DelaiEcriture = 1,

	-- Sac de mort
	-- À la mort : fraction des Covan portés qui tombent au sol (0.5 = la moitié, 0 = rien)
	CovanPerdusMort = 0.5,

	Sac = {
		-- false : l'inventaire et les armes restent au joueur (ils ne vont pas dans le sac)
		Actif = false,
		-- true : les Covan perdus à la mort sont dans le sac (E pour les prendre) au lieu d'un tas au sol
		CovanDansSac = true,
		Duree = 30,    -- secondes avant disparition ; son contenu est alors perdu
		Portee = 120,  -- distance maximum pour fouiller le sac
		Modele = "models/props_junk/garbage_bag001a.mdl",
	},

	-- Crâne laissé à la mort (nourriture des créatures de la nuit, voir Nourritures)
	Crane = {
		Actif = true,
	},

	-- Nourritures : maintenir E en visant l'entité pour la manger
	--   Mode "seulement" : seules les Factions listées peuvent manger
	--   Mode "sauf"      : tout le monde sauf les Factions listées
	--   Factions = champ origine_faction des jobs (jobs.lua)
	--   Duree = secondes avant disparition (0 = ne disparaît pas)
	Nourritures = {
		origine_crane = {
			Nom = "Crâne",
			Modele = "models/Gibs/HGIBS.mdl",
			Mode = "seulement",
			Factions = { "lycan", "vampire", "hybride" },
			Refus = "Seules les créatures de la nuit peuvent s'en nourrir.",
			Action = "Se nourrir",
			Duree = 30,
			Temps = 2.5,   -- secondes à maintenir E
			Portee = 100,
			Faim = 40,     -- faim rendue en % (module faim de DarkRP)
			PV = 20,       -- PV rendus
			Son = "npc/barnacle/barnacle_crunch2.wav",
		},
		origine_pasteque = {
			Nom = "Pastèque",
			Modele = "models/props_junk/watermelon01.mdl",
			Mode = "sauf",
			Factions = { "lycan", "vampire", "hybride" },
			Refus = "Les créatures de la nuit ne peuvent pas manger ça.",
			Action = "Manger",
			Duree = 0,
			Temps = 2.5,
			Portee = 100,
			Faim = 30,
			PV = 10,
			Son = "npc/barnacle/barnacle_crunch3.wav",
		},
	},

	-- Classes jamais rangeables (en plus des SWEPs de race), même si listées dans sh_entites.lua
	Interdites = {
		"spawned_money", "origine_sac_mort", "origine_crane", "origine_sacoche", "player", "prop_door_rotating",
		"func_door", "func_door_rotating",
	},
}
