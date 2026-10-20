--[[-----------------------------------------------------------------------
	Origine du monde — configuration de la mise à terre et des captures

	Un coup d'arme (joueur ou PNJ) non mortel qui laisse la victime à Seuil PV
	ou moins la met à terre ; un coup qui l'amène à 0 PV la tue directement.
	Chutes, feu, noyade (et objets écrasants) suivent les règles normales.

	Touche E sur un joueur à terre : Relever, Ligoter.
	Touche E sur un captif : Délier (tout le monde), Escorter / Lâcher (son ravisseur).

	Staff : ulx relever <joueur>, ulx delier <joueur> (aussi dans le menu TAB).
-------------------------------------------------------------------------]]

ORIGINE.ConfigMiseATerre = {
	Seuil = 15,              -- PV restants ou moins après un coup d'arme : à terre
	Duree = 180,             -- secondes à terre avant de mourir (le sac de mort tombe)
	Distance = 110,          -- distance maximum pour agir sur un joueur (vérifiée pendant toute l'action)

	Relever = {
		-- Jobs guérisseurs (commandes des jobs, voir jobs.lua). Vide = aucun guérisseur.
		Guerisseurs = {},
		DureeGuerisseur = 5, PVGuerisseur = 25,   -- relevé par un guérisseur
		DureeTous = 10, PVTous = 20,              -- par n'importe qui, si aucun guérisseur n'est connecté
	},
	Ligoter = { Duree = 3 },
	Delier = { Duree = 5 },

	-- Se déconnecter à terre ou ligoté compte comme une mort (le sac de mort tombe)
	DeconnexionEstMort = true,

	-- Captif escorté : il suit son ravisseur jusqu'à cette distance
	DistanceEscorte = 70,

	-- Animation au sol (séquence des playermodels), et hauteur de la caméra à terre
	Sequence = "zombie_slump_idle_02",
	HauteurVue = 18,

	-- Types de dégâts qui ne mettent jamais à terre
	DegatsExclus = { DMG_FALL, DMG_BURN, DMG_DROWN, DMG_CRUSH, DMG_SLOWBURN },

	-- Distance d'affichage de « À terre » / « Ligoté » au-dessus de la tête
	DistanceAffichage = 600,
}

if ORIGINE.AjouterTypeHistorique then ORIGINE.AjouterTypeHistorique("mise_a_terre", "Relevé / délié par le staff") end
