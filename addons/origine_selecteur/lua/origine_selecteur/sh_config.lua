--[[-----------------------------------------------------------------------
	Origine du monde — configuration du sélecteur d'armes

	Remplace le sélecteur de GMod (CHudWeaponSelection), en haut au centre.
	Mêmes contrôles : molette, touches 1 à 6, clic gauche pour équiper,
	clic droit pour fermer, lastinv, hud_fastswitch 1.

	Cooldowns : lus sur NextPrimaryFire / NextSecondaryFire de chaque arme.
	Un SWEP peut aussi donner les siens (ex. capacité de race) :

		function SWEP:OrigineCooldowns()
			return {
				primaire   = { fin = self:GetNextPrimaryFire(),   duree = 30 },
				secondaire = { fin = self:GetNextSecondaryFire(), duree = 10 },
			}
		end
-------------------------------------------------------------------------]]

ORIGINE.ConfigSelecteur = {
	-- Fermeture automatique après X secondes sans action
	FermetureAuto = 3,

	-- Un cooldown ne s'affiche que s'il dure au moins X secondes à son démarrage
	-- (sinon la barre clignoterait à chaque coup d'épée)
	SeuilCooldown = 1,

	-- Armes toujours placées en tête du slot 1, dans cet ordre
	PremieresDuSlot1 = { "origine_sacoche" },

	-- Nombre de colonnes (slots 1 à 6) ; une arme d'un slot plus grand va dans la dernière
	Colonnes = 6,

	-- Position : distance au haut de l'écran (en pixels à 1080p, mis à l'échelle)
	Marge = 20,

	-- Taille d'une carte (à 1080p)
	LargeurCarte = 150,
	HauteurIcone = 48,

	-- Sons : désactivés (le sélecteur est silencieux).
	-- Pour en remettre : Actives = true et chemins relatifs à sound/, ex. "origine_selecteur/clic.wav"
	Sons = {
		Actives = false,
		Volume = 0.5,          -- 0 à 1
		Fichiers = {
			Defilement = "",   -- molette, touches 1 à 6
			Selection = "",    -- arme équipée
		},
	},

	-- Icônes des armes de base de HL2 (police HalfLife2) ; les SWEPs Lua utilisent la leur
	IconesHL2 = {
		weapon_physcannon = "m",
		weapon_crowbar = "c",
		weapon_stunstick = "n",
		weapon_pistol = "d",
		weapon_357 = "e",
		weapon_smg1 = "a",
		weapon_ar2 = "l",
		weapon_shotgun = "b",
		weapon_crossbow = "g",
		weapon_frag = "k",
		weapon_rpg = "i",
		weapon_bugbait = "j",
		weapon_slam = "o",
	},

	-- Couleurs utilisées si origine_personnages n'est pas chargé
	CouleursParDefaut = {
		Fond        = Color(28, 22, 17, 235),
		FondClair   = Color(48, 38, 28, 235),
		Survol      = Color(72, 56, 38, 245),
		Bordure     = Color(122, 92, 54),
		Or          = Color(201, 164, 92),
		Texte       = Color(236, 224, 198),
		TexteSombre = Color(160, 146, 120),
	},
	PolicesParDefaut = { Titre = "Georgia", Texte = "Georgia" },

	-- Couleurs des barres de cooldown (clic gauche au-dessus, clic droit en dessous)
	CouleurPrimaire = Color(201, 164, 92),
	CouleurSecondaire = Color(120, 150, 200),
}
