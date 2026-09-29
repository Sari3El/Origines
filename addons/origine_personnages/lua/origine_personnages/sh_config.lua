--[[-----------------------------------------------------------------------
	Origine du monde — configuration de origine_personnages

	Tous les réglages du système de personnages sont ici. Aucun besoin de
	toucher au reste du code : modifiez les valeurs, sauvegardez, redémarrez
	le serveur.

	Les couleurs de rareté définies plus bas sont utilisées par TOUS les
	addons Origine (HUD, menu, inventaire, staff).
-------------------------------------------------------------------------]]

ORIGINE = ORIGINE or {}
ORIGINE.Config = {}
local C = ORIGINE.Config

---------------------------------------------------------------------------
-- Monnaie
---------------------------------------------------------------------------
C.Monnaie = {
	Nom = "Covan",              -- nom affiché après les montants (ex. 12 500 Covan)
	SeparateurMilliers = " ",   -- séparateur de milliers
	RemplacerFormatDarkRP = true, -- true : le F4 et le chat DarkRP affichent aussi « 12 500 Covan »
}

-- Montant de départ d'un nouveau personnage.
-- nil = le montant de départ de DarkRP (GM.Config.startingmoney).
C.MontantDepart = nil

---------------------------------------------------------------------------
-- Groupes ULX
---------------------------------------------------------------------------
-- Groupes qui donnent accès au slot 3 (VIP). Nom exact du groupe ULX.
C.GroupesVIP = { "vip" }

-- Groupes qui donnent accès au slot 5 (Staff), avec choix libre de la race.
C.GroupesStaff = { "superadmin", "admin" }

---------------------------------------------------------------------------
-- Slots
---------------------------------------------------------------------------
-- Noms affichés des slots et messages quand ils sont verrouillés.
C.Slots = {
	[1] = { Nom = "Slot 1" },
	[2] = { Nom = "Slot 2" },
	[3] = { Nom = "Slot 3", Verrou = "Réservé VIP" },
	[4] = { Nom = "EVENT",  Verrou = "Slot événement" },
	[5] = { Nom = "Staff",  Verrou = "Réservé au staff" },
}

---------------------------------------------------------------------------
-- Changement de personnage (!perso)
---------------------------------------------------------------------------
C.DelaiChangement = 300      -- secondes minimum entre deux changements (5 minutes)
C.DelaiApresCoup = 30        -- secondes sans avoir été touché avant de pouvoir changer
C.VerificationGroupes = 30   -- toutes les X secondes : vérifie si un slot VIP/Staff doit se verrouiller

-- Retourne true si le joueur est menotté. Adaptez selon votre addon de menottes.
C.EstMenotte = function(ply)
	if ply.IsHandcuffed and ply:IsHandcuffed() then return true end
	if ply.isHandcuffed and ply:isHandcuffed() then return true end
	if ply:GetNWBool("Handcuffed", false) or ply:GetNWBool("isHandcuffed", false) then return true end
	return false
end

-- Messages de chat autorisés pendant le menu personnage (début du message).
-- Par défaut : le chat OOC de DarkRP et les commandes « ! » (ULX, !perso…).
C.ChatAutoriseMenu = { "//", "/ooc ", "/a ", "!" }

---------------------------------------------------------------------------
-- Rerolls
---------------------------------------------------------------------------
C.RerollsPremiereConnexion = 1 -- points de reroll offerts à la première connexion
C.DureeAnimationTirage = 5     -- durée de la roulette (secondes) ; l'annonce chat part à la fin

---------------------------------------------------------------------------
-- Noms de personnage
---------------------------------------------------------------------------
C.Nom = {
	Min = 2,   -- caractères minimum pour le prénom et pour le nom
	Max = 16,  -- caractères maximum pour le prénom et pour le nom

	-- Noms refusés tels quels (prénom, nom ou « prénom nom »). Majuscules et accents ignorés.
	NomsInterdits = {
		"jesus", "hitler", "staline", "mahomet",
	},

	-- Mots refusés s'ils apparaissent n'importe où dans le nom (insultes…).
	MotsInterdits = {
		"connard", "salope", "encule", "pute", "nazi",
	},
}

---------------------------------------------------------------------------
-- Statistiques de base
---------------------------------------------------------------------------
-- Si un job de job.lua ne précise pas « origine_pvmax » / « origine_armuremax »,
-- ces valeurs servent de base (avant les modificateurs de race).
C.PVMaxDefaut = 100
C.ArmureMaxDefaut = 100

---------------------------------------------------------------------------
-- Armes jamais sauvegardées ni déposées dans le sac de mort
-- (en plus des armes du job, des armes par défaut de DarkRP et des SWEPs de race)
---------------------------------------------------------------------------
C.ArmesExclues = {
	"keys", "pocket", "weapon_keypadchecker", "weapon_physgun", "weapon_physcannon",
	"gmod_tool", "gmod_camera", "weapon_fists", "origine_sacoche",
}

---------------------------------------------------------------------------
-- Job caché pendant le menu personnage
---------------------------------------------------------------------------
C.JobSelection = {
	Nom = "Sélection du personnage",
	Commande = "origine_selection",
	Modele = "models/player/kleiner.mdl",
	Couleur = Color(90, 90, 90),
}

---------------------------------------------------------------------------
-- Sauvegarde
---------------------------------------------------------------------------
C.Sauvegarde = {
	Intervalle = 300,       -- sauvegarde automatique toutes les X secondes (5 minutes)
	CopieJournaliere = true, -- copie complète des tables Origine chaque jour (data/origine/sauvegardes/)
	JoursConservation = 7,   -- nombre de jours de copies gardées
}

-- SQLite (intégré à GMod) par défaut. MySQL seulement si un site ou un autre serveur lit les données.
C.BaseDeDonnees = {
	Mode = "sqlite", -- "sqlite" ou "mysql" (module MySQLOO requis dans lua/bin)
	Hote = "127.0.0.1",
	Port = 3306,
	Utilisateur = "",
	MotDePasse = "",
	Base = "",
}

---------------------------------------------------------------------------
-- Contenu Workshop (police, textures)
---------------------------------------------------------------------------
-- ID Workshop de l'addon qui contient vos polices (.ttf dans resource/fonts)
-- et textures. Laisser "" si vous n'en avez pas.
C.WorkshopID = ""

---------------------------------------------------------------------------
-- Charte graphique commune (HUD, menus, inventaire, sac, staff)
---------------------------------------------------------------------------
C.Charte = {
	PoliceTitre = "Georgia",  -- nom de la police (celle du .ttf si vous en distribuez une)
	PoliceTexte = "Georgia",
	FondMenu = "",            -- matériau de fond du menu personnage (ex. "origine/fond_menu.png"), "" = fond dessiné
	Couleurs = {
		Fond        = Color(28, 22, 17, 240),   -- fond des cadres
		FondClair   = Color(48, 38, 28, 240),   -- fond des cases, boutons
		Survol      = Color(72, 56, 38, 245),   -- bouton survolé
		Bordure     = Color(122, 92, 54),       -- cadre extérieur
		Or          = Color(201, 164, 92),      -- liseré doré, titres
		Texte       = Color(236, 224, 198),     -- texte principal
		TexteSombre = Color(160, 146, 120),     -- texte secondaire
		Grise       = Color(90, 84, 76),        -- éléments verrouillés
		PV          = Color(176, 44, 38),
		Armure      = Color(70, 110, 170),
		Faim        = Color(196, 140, 52),
		Traine      = Color(245, 230, 200, 170), -- traînée claire quand une jauge baisse
		Alerte      = Color(230, 40, 30),
		Succes      = Color(96, 170, 80),
	},
}

---------------------------------------------------------------------------
-- Paliers de rareté (couleurs utilisées partout)
---------------------------------------------------------------------------
C.Raretes = {
	{ id = "sans_lignee", Nom = "Sans lignée",        Couleur = Color(165, 165, 165) },
	{ id = "commune",     Nom = "Lignée commune",     Couleur = Color(88, 190, 92) },
	{ id = "ancienne",    Nom = "Lignée ancienne",    Couleur = Color(72, 146, 232) },
	{ id = "illustre",    Nom = "Lignée illustre",    Couleur = Color(172, 96, 226) },
	{ id = "legendaire",  Nom = "Lignée légendaire",  Couleur = Color(242, 152, 40) },
	{ id = "primordiale", Nom = "Lignée primordiale", Couleur = Color(226, 52, 52) },
}

---------------------------------------------------------------------------
-- Catégories d'armes (GMod ne les distingue pas tout seul)
-- Mettez les classes d'armes entre les guillemets, une par ligne.
---------------------------------------------------------------------------
C.CategoriesArmes = {
	melee = {        -- mêlée (épées, haches, masses…)
		"",
	},
	lame_legere = {  -- lames légères (dagues, rapières…)
		"",
	},
	arc = {          -- arcs et arbalètes
		"",
	},
	magie = {        -- armes magiques (sorts)
		"",
	},
}

---------------------------------------------------------------------------
-- Restrictions de job par race
-- Format : ["commande_du_job"] = { "id_race", "id_race" }  (races autorisées)
-- Vide = aucune restriction.
---------------------------------------------------------------------------
C.RestrictionsJobs = {
}

---------------------------------------------------------------------------
-- Discrétion (races avec discretion = true)
---------------------------------------------------------------------------
C.Discretion = {
	VolumePas = 0.3, -- volume des bruits de pas (1 = normal)
}

---------------------------------------------------------------------------
-- SWEPs de race (valeurs à définir plus tard, voici des valeurs de départ)
---------------------------------------------------------------------------
C.SwepVol = {
	Duree = 8,           -- secondes de vol
	Recharge = 20,       -- secondes avant de pouvoir revoler
	VitesseMontee = 260, -- vitesse verticale avec SAUT
	VitesseDescente = 200, -- vitesse verticale avec ACCROUPI
	ChuteMax = 60,       -- vitesse de descente maximum en planant
	-- Zones interdites : { Min = Vector(x, y, z), Max = Vector(x, y, z) }
	ZonesInterdites = {
	},
}

C.SwepCrachat = {
	Degats = 0,          -- dégâts par souffle (0 = neutre en attendant l'équilibrage)
	Portee = 300,        -- portée en unités
	Angle = 20,          -- demi-angle du cône en degrés
	Brulure = 0,         -- secondes d'embrasement de la cible (0 = aucun, neutre en attendant l'équilibrage)
	Recharge = 10,       -- secondes entre deux souffles
}

---------------------------------------------------------------------------
-- Races
--
-- Poids : taux de tirage. Le système ramène le total à 100 %, un total
-- différent ne casse rien. Le menu affiche les taux recalculés en direct.
--
-- Modificateurs (valeurs neutres en attendant l'équilibrage) :
--   PV         multiplicateur de PV max (1 = normal, 1.2 = +20 %)
--   Armure     multiplicateur d'armure max
--   Reduction  réduction de tous les dégâts reçus, en %
--   Vitesse    multiplicateur de vitesse, marche et course
--   Degats     bonus/malus de dégâts par catégorie d'arme, en %
--              ex. { melee = 15, arc = -10 }
--   Esquive    % de chance d'annuler un coup d'arme porté par un joueur
--   Regen      { PV = 0, Intervalle = 5, Delai = 10 }
--              PV rendus toutes les Intervalle secondes, après Delai secondes sans coup reçu
--   Feu        résistance aux dégâts de feu (DMG_BURN), en %
--   Magie      résistance aux armes de la catégorie magie, en %
--   Discretion true : pas atténués, infos au-dessus de la tête visibles seulement de près
--   Sweps      classes d'armes données au personnage
---------------------------------------------------------------------------
local function neutre(sup)
	local m = {
		PV = 1, Armure = 1, Reduction = 0, Vitesse = 1, Degats = {}, Esquive = 0,
		Regen = { PV = 0, Intervalle = 5, Delai = 10 },
		Feu = 0, Magie = 0, Discretion = false, Sweps = {},
	}
	for k, v in pairs(sup or {}) do m[k] = v end
	return m
end

C.Races = {
	{
		id = "etre_vivant", Nom = "Être Vivant", Rarete = "sans_lignee", Poids = 27,
		Inspiree = "Humain",
		Description = "Aucune descendance particulière, la référence.",
		Effets = "Vitesse ×0,9, rien de plus.",
		Mod = neutre({ Vitesse = 0.9 }),
	},
	{
		id = "gardien", Nom = "Descendant du Gardien", Rarete = "commune", Poids = 9,
		Inspiree = "Nain",
		Description = "Lignée de défenseurs.",
		Effets = "PV en plus, réduction de dégâts, lent.",
		Mod = neutre(),
	},
	{
		id = "archer", Nom = "Descendant de l'Archer", Rarete = "commune", Poids = 9,
		Inspiree = "Elfe",
		Description = "Lignée de tireurs d'élite.",
		Effets = "Bonus de dégâts à l'arc et aux lames légères.",
		Mod = neutre(),
	},
	{
		id = "colosse", Nom = "Descendant du Colosse", Rarete = "commune", Poids = 9,
		Inspiree = "Ogre",
		Description = "Sang de titans.",
		Effets = "Beaucoup de PV et réduction de dégâts, très lent, mauvais à distance.",
		Mod = neutre(),
	},
	{
		id = "guerrier", Nom = "Descendant du Guerrier", Rarete = "commune", Poids = 9,
		Inspiree = "Demi-orc",
		Description = "Lignée de combattants.",
		Effets = "Bonus de dégâts en mêlée, un peu plus de PV.",
		Mod = neutre(),
	},
	{
		id = "filou", Nom = "Descendant du Filou", Rarete = "commune", Poids = 9,
		Inspiree = "Gobelin",
		Description = "Lignée de voleurs.",
		Effets = "Rapide, chance d'esquive.",
		Mod = neutre(),
	},
	{
		id = "rescape", Nom = "Descendant du Rescapé", Rarete = "ancienne", Poids = 4,
		Inspiree = "Homme-lézard",
		Description = "Sang endurant.",
		Effets = "Régénération passive, légère réduction de dégâts.",
		Mod = neutre(),
	},
	{
		id = "ombre", Nom = "Descendant de l'Ombre", Rarete = "ancienne", Poids = 4,
		Inspiree = "Homme-rat",
		Description = "Lignée d'espions.",
		Effets = "Rapide et discret.",
		Mod = neutre({ Discretion = true }),
	},
	{
		id = "chasseur", Nom = "Descendant du Chasseur", Rarete = "ancienne", Poids = 4,
		Inspiree = "Homme-loup",
		Description = "Lignée de traqueurs.",
		Effets = "Rapide, bonus de dégâts en mêlée.",
		Mod = neutre(),
	},
	{
		id = "acrobate", Nom = "Descendant de l'Acrobate", Rarete = "ancienne", Poids = 4,
		Inspiree = "Homme-chat",
		Description = "Lignée d'agiles.",
		Effets = "Le plus d'esquive, très rapide, fragile.",
		Mod = neutre(),
	},
	{
		id = "runiste", Nom = "Descendant du Runiste", Rarete = "ancienne", Poids = 4,
		Inspiree = "Gnome",
		Description = "Sang protégé par les runes.",
		Effets = "Résistance magique.",
		Mod = neutre(),
	},
	{
		id = "haute_lignee", Nom = "Haute Lignée", Rarete = "illustre", Poids = 3.5,
		Inspiree = "Humain de haute lignée",
		Description = "Sang noble « pur ». Le choix sûr parmi les races rares.",
		Effets = "Bonus équilibrés, régénération légère.",
		Mod = neutre(),
	},
	{
		id = "celeste", Nom = "Céleste", Rarete = "illustre", Poids = 3.5,
		Inspiree = "Homme-aigle",
		Description = "Sang lié au ciel.",
		Effets = "Le plus rapide, SWEP Vol.",
		Mod = neutre({ Sweps = { "origine_vol" } }),
	},
	{
		id = "sang_dragon", Nom = "Sang de Dragon", Rarete = "legendaire", Poids = 0.8,
		Inspiree = "Sang-dragon",
		Description = "Descendance draconique.",
		Effets = "Résistance au feu, SWEP Crachat de feu.",
		Mod = neutre({ Sweps = { "origine_crachat_feu" } }),
	},
	{
		id = "sang_arcanique", Nom = "Sang Arcanique", Rarete = "primordiale", Poids = 0.2,
		Inspiree = "Sorcier",
		Description = "Sang des premiers mages.",
		Effets = "À définir plus tard.",
		Mod = neutre(),
	},
}
