--[[-----------------------------------------------------------------------
	Origine du monde — configuration du menu TAB

	Ce module remplace le scoreboard de FAdmin (et uniquement lui).
	DarkRP charge tout seul les fichiers sh_, sv_ et cl_ de ce dossier ;
	les mises à jour de DarkRP ne touchent jamais darkrpmodification.

	Permissions ULX (à régler dans XGUI > Groupes, catégorie « Origine TAB ») :
	  origine_tab_staff : voir les infos staff (nom Steam, SteamID, slot, PV,
	                      Covan, kills/morts). Donnée par défaut aux admins.
	  origine_tab_job   : changer le job d'un joueur depuis sa fiche (pas
	                      d'équivalent ULX). Donnée par défaut aux admins.
	Toutes les autres actions staff sont des commandes ULX (ulx kick, ulx ban…)
	et suivent les permissions ULX habituelles.
-------------------------------------------------------------------------]]

ORIGINE = ORIGINE or {}
ORIGINE.Tab = ORIGINE.Tab or {}

ORIGINE.Tab.Config = {
	NomServeur = "Médiéval RP : Origine du monde",

	-- Liens de l'en-tête (ouverts dans le navigateur Steam). Laisser "" pour masquer le bouton.
	Liens = {
		{ Nom = "Discord", Url = "" },
		{ Nom = "Règlement", Url = "" },
		{ Nom = "Collection Workshop", Url = "" },
	},

	-- Couleur du ping : vert sous Vert ms, orange sous Orange ms, rouge au-delà
	Ping = { Vert = 80, Orange = 150 },

	-- Mise à jour de la liste tant que le TAB est ouvert (secondes)
	Rafraichissement = 2,

	-- Groupe unique vu par les joueurs sans origine_tab_staff (ils ne voient que le nom Steam et le SteamID)
	GroupeJoueurs = "Joueurs connectés",

	-- Nom du groupe des joueurs qui choisissent leur personnage (tout en bas)
	GroupeSelection = "En sélection de personnage",

	-- Groupe des joueurs dont le job n'a pas de catégorie
	GroupeSansCategorie = "Autres",

	-- Couleurs utilisées si origine_personnages n'est pas chargé
	-- (sinon ce sont celles de la charte : ORIGINE.Config.Charte.Couleurs)
	CouleursParDefaut = {
		Fond        = Color(28, 22, 17, 240),
		FondClair   = Color(48, 38, 28, 240),
		Survol      = Color(72, 56, 38, 245),
		Bordure     = Color(122, 92, 54),
		Or          = Color(201, 164, 92),
		Texte       = Color(236, 224, 198),
		TexteSombre = Color(160, 146, 120),
		Grise       = Color(90, 84, 76),
		PV          = Color(176, 44, 38),
		Alerte      = Color(230, 40, 30),
		Succes      = Color(96, 170, 80),
	},
	PolicesParDefaut = { Titre = "Georgia", Texte = "Georgia" },
	CouleurPingVert = Color(96, 170, 80),
	CouleurPingOrange = Color(220, 150, 50),
	CouleurPingRouge = Color(220, 60, 50),
	CouleurBadgeStaff = Color(200, 60, 50),
	CouleurBadgeEvent = Color(150, 90, 210),

	--[[ Actions staff sur un joueur.
		ulx     : commande ULX lancée (le bouton n'apparaît que si le staff a la permission
		          ET si la commande existe sur le serveur ; ULX revérifie tout côté serveur)
		args    : saisies demandées avant l'envoi (raison, durée…), dans l'ordre de la commande
		inverse : commande ULX du bouton « annuler » (dégeler, libérer…), même permission ULX
		          que la sienne propre
	]]
	Actions = {
		{ id = "kick", Nom = "Expulser", ulx = "ulx kick", args = { { libelle = "Raison", indication = "Raison de l'expulsion" } } },
		{ id = "ban", Nom = "Bannir", ulx = "ulx ban", args = {
			{ libelle = "Durée en minutes (0 = définitif)", indication = "60", numerique = true },
			{ libelle = "Raison", indication = "Raison du bannissement" },
		} },
		{ id = "slay", Nom = "Tuer", ulx = "ulx slay" },
		{ id = "jail", Nom = "Emprisonner", ulx = "ulx jail", inverse = { Nom = "Libérer", ulx = "ulx unjail" } },
		{ id = "freeze", Nom = "Geler", ulx = "ulx freeze", inverse = { Nom = "Dégeler", ulx = "ulx unfreeze" } },
		{ id = "goto", Nom = "Aller vers", ulx = "ulx goto" },
		{ id = "bring", Nom = "Ramener", ulx = "ulx bring" },
		{ id = "return", Nom = "Renvoyer", ulx = "ulx return" },
		{ id = "spectate", Nom = "Observer", ulx = "ulx spectate" },
		{ id = "gag", Nom = "Couper le micro", ulx = "ulx gag", inverse = { Nom = "Rendre le micro", ulx = "ulx ungag" } },
		{ id = "mute", Nom = "Couper le chat", ulx = "ulx mute", inverse = { Nom = "Rendre le chat", ulx = "ulx unmute" } },
		{ id = "strip", Nom = "Retirer les armes", ulx = "ulx strip" },
		{ id = "cloak", Nom = "Rendre invisible", ulx = "ulx cloak", inverse = { Nom = "Rendre visible", ulx = "ulx uncloak" } },
		{ id = "god", Nom = "Rendre invincible", ulx = "ulx god", inverse = { Nom = "Retirer l'invincibilité", ulx = "ulx ungod" } },
		{ id = "ignite", Nom = "Enflammer", ulx = "ulx ignite", inverse = { Nom = "Éteindre", ulx = "ulx unignite" } },
		{ id = "psay", Nom = "Message privé", ulx = "ulx psay", args = { { libelle = "Message", indication = "Votre message" } } },
		-- Autres actions du scoreboard FAdmin
		{ id = "slap", Nom = "Gifler", ulx = "ulx slap" },
		{ id = "ragdoll", Nom = "Ragdoll", ulx = "ulx ragdoll", inverse = { Nom = "Relever", ulx = "ulx unragdoll" } },
		{ id = "noclip", Nom = "Noclip", ulx = "ulx noclip" },
		{ id = "hp", Nom = "Régler les PV", ulx = "ulx hp", args = { { libelle = "Points de vie", indication = "100", numerique = true } } },
		{ id = "armor", Nom = "Régler l'armure", ulx = "ulx armor", args = { { libelle = "Armure", indication = "100", numerique = true } } },
		-- origine_mise_a_terre : relever un joueur à terre, délier un captif
		{ id = "relever", Nom = "Relever", ulx = "ulx relever" },
		{ id = "delier", Nom = "Délier", ulx = "ulx delier" },
		-- Sans équivalent ULX : permission propre « origine_tab_job »
		{ id = "job", Nom = "Changer le job", permission = "origine_tab_job" },
	},

	-- Actions serveur (onglet « Serveur » du TAB), mêmes règles que ci-dessus
	ActionsServeur = {
		{ id = "map", Nom = "Changer de carte", ulx = "ulx map", args = { { libelle = "Nom de la carte", indication = "rp_..." } } },
		{ id = "stopsounds", Nom = "Couper tous les sons", ulx = "ulx stopsounds" },
		{ id = "cleanup", Nom = "Nettoyer la carte", ulx = "ulx cleanup" },
		{ id = "csay", Nom = "Annonce à l'écran", ulx = "ulx csay", args = { { libelle = "Message", indication = "Annonce" } } },
	},
}
