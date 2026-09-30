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
		-- false : pas de sac de mort, l'inventaire et les armes restent au joueur
		Actif = false,
		Duree = 600,   -- secondes avant disparition (10 minutes) ; son contenu est alors perdu
		Portee = 120,  -- distance maximum pour fouiller le sac
		Modele = "models/props_junk/garbage_bag001a.mdl",
	},

	-- Classes jamais rangeables (en plus des SWEPs de race), même si listées dans sh_entites.lua
	Interdites = {
		"spawned_money", "origine_sac_mort", "origine_sacoche", "player", "prop_door_rotating",
		"func_door", "func_door_rotating",
	},
}
