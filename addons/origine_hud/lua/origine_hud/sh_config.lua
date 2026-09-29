--[[-----------------------------------------------------------------------
	Origine du monde — configuration de origine_hud
	Les couleurs viennent de la charte commune (origine_personnages/sh_config.lua).
-------------------------------------------------------------------------]]

ORIGINE.ConfigHUD = {
	-- Espace (en pixels à 1080p) entre le bas de la chatbox et le HUD
	Marge = 8,

	-- Taille du bloc à 1080p (adaptée automatiquement de 720p à 4K)
	Largeur = 380,
	Hauteur = 196,

	-- S'il n'y a pas assez de place sous la chatbox, le HUD est réduit
	-- jusqu'à cette échelle minimum ; en dessous, il se place à droite de la chatbox.
	EchelleMinimum = 0.55,

	-- Jauges
	SeuilAlerte = 0.20,  -- PV et faim clignotent en rouge sous 20 %
	DelaiTraine = 0.35,  -- secondes avant que la traînée claire rejoigne la valeur
	VitesseTraine = 0.8, -- vitesse de la traînée (fraction de jauge par seconde)

	-- Infos au-dessus de la tête des joueurs
	InfosTete = {
		Distance = 400,           -- distance d'affichage normale
		DistanceDiscretion = 120, -- races avec « discrétion » : visibles seulement de près
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
