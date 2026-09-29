--[[-----------------------------------------------------------------------
	Origine du monde — configuration de origine_chat
	Les couleurs et polices viennent de la charte commune (origine_personnages).
-------------------------------------------------------------------------]]

ORIGINE.ConfigChat = {
	-- Taille de la zone des messages à 1080p (adaptée de 720p à 4K).
	-- Le chat se place en bas à gauche en laissant la place au HUD dessous.
	Largeur = 560,
	Hauteur = 260,
	MargeGauche = 24,

	TaillePolice = 17,
	Horodatage = true,       -- [14:32:07] devant chaque message

	MessagesEnMemoire = 300, -- messages gardés en mémoire
	DureeAffichage = 12,     -- chat fermé : secondes avant qu'un message s'efface
	LignesFerme = 8,         -- chat fermé : nombre de lignes affichées au maximum

	LongueurMax = 126,       -- longueur maximum d'un message (octets, limite du moteur)
	HistoriqueEnvoyes = 50,  -- messages envoyés retrouvables avec les flèches haut / bas

	-- Un seul chat général : pour écrire hors RP, /ooc message ou // message.
	-- Préfixes DarkRP reconnus comme du chat OOC (selon la langue de DarkRP), utilisés par le menu personnage
	MotifsOOC = { "%(OOC%)", "%(HRP%)", "^OOC", "^HRP", "^%[OOC%]" },

	-- Son joué quand un message contient le nom de votre personnage ("" = aucun)
	SonMention = "buttons/blip1.wav",

	-- Anti-spam (vérifié par le serveur)
	AntiSpam = {
		Messages = 5,            -- au plus 5 messages…
		Fenetre = 4,             -- …en 4 secondes
		Repetitions = 3,         -- le même message au plus 3 fois…
		FenetreRepetition = 20,  -- …en 20 secondes
		GroupesExemptes = { "superadmin", "admin" },
	},

	-- Commandes proposées quand on tape « / » ou « ! »
	-- (les commandes DarkRP connues sont ajoutées automatiquement)
	Commandes = {
		{ "//", "Parler en OOC (hors RP)" },
		{ "/ooc", "Parler en OOC (hors RP)" },
		{ "/me", "Décrire une action de votre personnage" },
		{ "/y", "Crier" },
		{ "/w", "Chuchoter" },
		{ "/pm", "Message privé : /pm nom message" },
		{ "/advert", "Faire une annonce" },
		{ "!perso", "Changer de personnage" },
		{ "!origine", "Menu staff" },
	},
}
