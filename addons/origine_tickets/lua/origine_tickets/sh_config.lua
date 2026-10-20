--[[-----------------------------------------------------------------------
	Origine du monde — configuration des tickets (demandes d'aide au staff)

	F6 (réglable) : menu des tickets. Joueur : ouvrir une demande et la suivre.
	Staff : file des tickets, historique, statistiques.
	!report <message> : ticket rapide.
	Les tickets sont liés au COMPTE (hors RP), pas au personnage.

	Permissions ULX :
	  origine_tickets_staff (admins par défaut) : traiter les tickets
	  origine_tickets_admin (superadmins)       : statistiques, réattribution, suppression
-------------------------------------------------------------------------]]

ORIGINE.ConfigTickets = {
	Touche = KEY_F6,

	Categories = { "Question", "Signalement d'un joueur", "Bug", "Remboursement", "Autre" },
	CategorieRapide = "Autre",   -- catégorie des tickets ouverts avec !report

	LongueurDescription = 1000,
	LongueurMessage = 1000,

	DelaiEntreTickets = 120,     -- secondes entre deux tickets d'un même joueur
	RetentionJours = 90,         -- tickets fermés supprimés après X jours
	ParPage = 30,

	Priorites = { [1] = "Basse", [2] = "Normale", [3] = "Haute" },

	-- Sons
	SonNouveau = "buttons/bell1.wav",      -- staff : nouveau ticket
	SonReponse = "buttons/button9.wav",    -- joueur : réponse du staff

	--[[ Discord : notification quand un ticket est ouvert SANS staff connecté.
		Coller l'URL du webhook du salon (Paramètres du salon > Intégrations > Webhooks).
		À vérifier sur votre hébergeur : GMod envoie la requête avec HTTP() ; certains
		serveurs bloquent les requêtes sortantes (il faut alors un module comme CHTTP). ]]
	Discord = {
		Webhook = "",
		NomServeur = "Médiéval RP : Origine du monde",
	},
}

ORIGINE.Tickets = ORIGINE.Tickets or {}
ORIGINE.Tickets.Statuts = {
	ouvert = "Ouvert",
	pris = "Pris en charge",
	attente = "En attente du joueur",
	ferme = "Fermé",
}
ORIGINE.Tickets.CouleursStatuts = {
	ouvert = Color(220, 150, 50),
	pris = Color(96, 170, 80),
	attente = Color(110, 150, 220),
	ferme = Color(140, 130, 120),
}
