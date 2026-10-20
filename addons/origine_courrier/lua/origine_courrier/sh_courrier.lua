--[[-----------------------------------------------------------------------
	Origine du monde — missives (partagé)
-------------------------------------------------------------------------]]

ORIGINE.Courrier = ORIGINE.Courrier or {}
local MC = ORIGINE.Courrier
local CC = ORIGINE.ConfigCourrier
local I = ORIGINE.Inv

MC.Portees = {
	perso = "Personnages",
	faction = "Ma faction",
	factions = "Autres factions",
	general = "Tout le serveur",
}

-- Parchemin et missive rangeables dans l'inventaire (sans toucher à sh_entites.lua)
I.Autoriser("origine_parchemin")
I.Autoriser("origine_missive")

-- Action « Lire » de l'inventaire pour les missives rangées
I.AjouterActionObjet("origine_missive", "lire", "Lire", "icon16/book_open.png", function(ply, objet)
	if MC.EnvoyerPapier then MC.EnvoyerPapier(ply, objet.donnees or {}, nil) end
end)

-- Missives générales réservées à certains jobs ?
function MC.PeutEcrireGenerale(ply)
	if #CC.JobsGenerale == 0 then return true end
	return ORIGINE.DansListe(CC.JobsGenerale, ORIGINE.CommandeJob(ply:Team()))
end

-- Parchemin vierge au F4 (catégorie « Origine » des entités) et commande /parchemin
local function creerAchat()
	if MC.AchatCree or not (DarkRP and DarkRP.createEntity) then return end
	MC.AchatCree = true
	if DarkRP.createCategory then
		DarkRP.createCategory({
			name = "Origine", categorises = "entities", startExpanded = true,
			color = Color(201, 164, 92), canSee = function() return true end, sortOrder = 50,
		})
	end
	DarkRP.createEntity("Parchemin vierge", {
		ent = "origine_parchemin",
		model = CC.ModeleParchemin,
		price = CC.PrixParchemin,
		max = CC.MaxParchemins,
		cmd = CC.CommandeAchat,
		category = "Origine",
	})
end
hook.Add("loadCustomDarkRPItems", "origine_courrier", creerAchat)
hook.Add("DarkRPFinishedLoading", "origine_courrier", creerAchat)
