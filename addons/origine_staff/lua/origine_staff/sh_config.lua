--[[-----------------------------------------------------------------------
	Origine du monde — configuration de origine_staff
-------------------------------------------------------------------------]]

ORIGINE.ConfigStaff = {
	-- Permission ULX (donnée aux superadmins par défaut, à attribuer à d'autres rangs via XGUI)
	Permission = "origine_menu",

	-- Nombre maximum de résultats affichés
	LimiteRecherche = 50,
	LimiteHistorique = 200,

	-- Libellés des types d'actions de l'historique
	TypesHistorique = {
		{ id = "tirage", Nom = "Tirage de race" },
		{ id = "reroll", Nom = "Reroll de race" },
		{ id = "race", Nom = "Modification de race" },
		{ id = "rerolls", Nom = "Points de reroll" },
		{ id = "rerolls_tous", Nom = "Rerolls pour tous" },
		{ id = "nom", Nom = "Changement de nom" },
		{ id = "forcer_slot", Nom = "Slot forcé" },
		{ id = "event", Nom = "Slot EVENT" },
		{ id = "vip_slot", Nom = "Slot 3 (VIP)" },
		{ id = "inventaire", Nom = "Inventaire" },
		{ id = "ck", Nom = "CK" },
		{ id = "rpk", Nom = "RPK" },
		{ id = "annulation", Nom = "Annulation CK/RPK" },
	},

	-- Logs (onglet « Logs » du menu !origine)
	Logs = {
		Intervalle = 5,           -- écriture en base toutes les X secondes (par lots, jamais un par un)
		RetentionJours = 14,      -- logs plus vieux supprimés automatiquement
		ParPage = 100,            -- lignes par page
		RegroupementDegats = 1,   -- coups identiques (même attaquant, victime, arme) regroupés sur X secondes
		DegatsProps = false,      -- true : journaliser aussi les dégâts faits aux props
		Salaires = false,         -- true : journaliser chaque salaire DarkRP (beaucoup de lignes)
		Desactivees = {},         -- catégories à ne pas enregistrer, ex. { chat = true }
	},

	-- Sous-onglets des logs (l'onglet « staff » affiche l'historique des actions staff)
	CategoriesLogs = {
		{ id = "degats", Nom = "Dégâts" },
		{ id = "morts", Nom = "Morts" },
		{ id = "personnages", Nom = "Personnages" },
		{ id = "chat", Nom = "Chat" },
		{ id = "connexions", Nom = "Connexions" },
		{ id = "props", Nom = "Props / entités" },
		{ id = "economie", Nom = "Économie" },
		{ id = "inventaire", Nom = "Inventaire" },
		{ id = "jobs", Nom = "Jobs" },
		{ id = "police", Nom = "Police" },
		{ id = "staff", Nom = "Staff" },
	},
}

function ORIGINE.NomTypeHistorique(id)
	for _, t in ipairs(ORIGINE.ConfigStaff.TypesHistorique) do
		if t.id == id then return t.Nom end
	end
	return id
end
