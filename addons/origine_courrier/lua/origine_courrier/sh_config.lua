--[[-----------------------------------------------------------------------
	Origine du monde — configuration des missives

	Les personnages s'écrivent des missives sur parchemin : à un ou plusieurs
	personnages, à leur faction, à d'autres factions ou à tout le serveur.
	Une faction = une catégorie de job DarkRP.

	Parchemin vierge : acheté au F4 (onglet Entités, catégorie Origine) ou avec
	la commande de chat /parchemin. E sur un parchemin posé pour écrire.
	Coffret : !missives (ou la touche réglée plus bas).

	Permission ULX origine_courrier_admin (superadmins par défaut) : lire et
	supprimer toutes les missives depuis !origine (onglet Missives).
-------------------------------------------------------------------------]]

ORIGINE.ConfigCourrier = {
	-- Parchemin vierge au F4
	PrixParchemin = 10,
	MaxParchemins = 10,        -- parchemins posés en même temps par joueur
	CommandeAchat = "parchemin",

	-- Écriture
	LongueurTexte = 1000,
	LongueurObjet = 80,
	MaxDestinataires = 10,     -- personnages par missive

	-- Limites
	DelaiMissive = 30,         -- secondes entre deux missives
	DelaiGenerale = 600,       -- secondes entre deux missives générales
	-- Jobs autorisés à envoyer des missives générales (commandes des jobs). Vide = tout le monde.
	JobsGenerale = {},

	-- Coffret
	MaxPersonnelles = 100,     -- missives personnelles gardées par personnage
	ParPage = 20,
	-- Touche du coffret (ex. KEY_F7). nil = aucune (commande !missives)
	Touche = nil,

	-- Distance pour écrire sur un parchemin posé
	Portee = 150,

	-- Modèles et son
	ModeleParchemin = "models/props_c17/paper01.mdl",
	ModeleMissive = "models/props_c17/paper01.mdl",
	SonReception = "physics/cardboard/cardboard_box_impact_soft2.wav",

	-- Couleurs du parchemin
	CouleurParchemin = Color(226, 208, 168),
	CouleurEncre = Color(52, 36, 22),
}

if ORIGINE.AjouterTypeHistorique then ORIGINE.AjouterTypeHistorique("missive", "Missive supprimée") end
