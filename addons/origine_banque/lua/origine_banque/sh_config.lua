--[[-----------------------------------------------------------------------
	Origine du monde — configuration de la banque

	Bourse  : les Covan portés par le personnage (l'argent DarkRP du personnage).
	Compte  : les Covan déposés à la banque, par personnage.
	Trésor  : le solde de la banque (faction bancaire), alimenté par les frais,
	          qui sert à prêter aux personnages.

	Le guichet (entité « origine_guichet », catégorie Origine du menu des entités)
	est placé par le staff et reste au même endroit après un redémarrage.

	Permission ULX origine_banque_admin (superadmins par défaut) :
	onglet Administration du guichet (Covan de tous les personnages d'un joueur).
-------------------------------------------------------------------------]]

ORIGINE.ConfigBanque = {
	-- Frais en % du montant, versés au trésor
	Frais = {
		Depot = 0,
		Retrait = 2,
		Virement = 2,
	},

	-- Distance maximum au guichet (unités)
	Portee = 150,

	-- Nombre d'opérations du relevé
	Releve = 50,

	-- Prêts
	Pret = {
		MontantMax = 50000,
		TauxMax = 30,          -- % d'intérêts sur la totalité du prêt
		EcheanceMaxJours = 30, -- échéance maximum, en jours réels
	},

	-- Droits sur le trésor, par job (commandes des jobs, voir jobs.lua)
	Jobs = {
		Consulter = { "consortium_banquier", "consortium_intendant", "consortium_courtier" },
		Preter = { "consortium_banquier", "consortium_intendant", "consortium_courtier" },  -- banquiers
		Retirer = { "consortium_banquier" },                                                 -- dirigeant
	},

	-- Mouvements du trésor affichés au guichet
	MouvementsAffiches = 100,

	-- Modèle du guichet
	Modele = "models/props_wasteland/controlroom_desk001b.mdl",
}

if ORIGINE.AjouterTypeHistorique then ORIGINE.AjouterTypeHistorique("banque", "Banque") end
