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
		{ id = "inventaire", Nom = "Inventaire" },
		{ id = "ck", Nom = "CK" },
		{ id = "rpk", Nom = "RPK" },
		{ id = "annulation", Nom = "Annulation CK/RPK" },
	},
}

function ORIGINE.NomTypeHistorique(id)
	for _, t in ipairs(ORIGINE.ConfigStaff.TypesHistorique) do
		if t.id == id then return t.Nom end
	end
	return id
end
