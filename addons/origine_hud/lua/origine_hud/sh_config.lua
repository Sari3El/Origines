--[[-----------------------------------------------------------------------
	Origine du monde — configuration de origine_hud
	Les couleurs viennent de la charte commune (origine_personnages/sh_config.lua).
-------------------------------------------------------------------------]]

ORIGINE.ConfigHUD = {
	-- Espace (en pixels à 1080p) entre le bas de la chatbox et le HUD
	Marge = 8,

	-- Largeur du bloc à 1080p (adaptée automatiquement de 720p à 4K).
	-- Bloc allongé et bas : PV, armure et faim sont côte à côte sur une seule ligne
	-- (la faim est retirée si le module faim de DarkRP est désactivé ou en mode Sans faim).
	Largeur = 440,

	-- S'il n'y a pas assez de place sous la chatbox, le HUD est réduit
	-- jusqu'à cette échelle minimum ; en dessous, il se place à droite de la chatbox.
	EchelleMinimum = 0.55,

	-- Jauges
	SeuilAlerte = 0.20,  -- PV et faim clignotent en rouge sous 20 %
	DelaiTraine = 0.35,  -- secondes avant que la traînée claire rejoigne la valeur
	VitesseTraine = 0.8, -- vitesse de la traînée (fraction de jauge par seconde)

	-- Covan : le montant défile jusqu'à la nouvelle valeur, la variation (+/-) s'affiche un instant
	DureeVariationCovan = 2.5,

	-- Infos au-dessus de la tête des joueurs
	InfosTete = {
		-- true : seuls les superadmins voient les infos au-dessus des joueurs (nom, métier, race).
		-- false : tout le monde les voit.
		SuperadminSeulement = true,
		Distance = 400,           -- distance d'affichage normale
		DistanceDiscretion = 120, -- races avec « discrétion » : visibles seulement de près
		Rafraichissement = 0.2,   -- secondes entre deux tests de visibilité
	},

	-- Éléments masqués et remplacés par le HUD.
	-- « DarkRP_HUD » n'est volontairement PAS masqué : dans DarkRP il englobe aussi
	-- l'arrestation, le couvre-feu, l'agenda et le chat vocal, qui doivent rester visibles.
	-- Vie, argent, salaire et job DarkRP sont dans « DarkRP_LocalPlayerHUD ».
	Masquer = {
		"CHudHealth", "CHudBattery", "CHudAmmo", "CHudSecondaryAmmo",
		"DarkRP_LocalPlayerHUD", "DarkRP_Hungermod", "DarkRP_EntityDisplay",
	},
}
