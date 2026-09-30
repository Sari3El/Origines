--[[-----------------------------------------------------------------------
	Origine du monde — banque (partagé)
-------------------------------------------------------------------------]]

ORIGINE.Banque = ORIGINE.Banque or {}
local B = ORIGINE.Banque
local CB = ORIGINE.ConfigBanque

-- Libellés des opérations du relevé
B.TypesOperation = {
	depot = "Dépôt",
	retrait = "Retrait",
	virement_envoye = "Virement envoyé",
	virement_recu = "Virement reçu",
	pret = "Prêt reçu",
	remboursement = "Remboursement",
	correction = "Correction du staff",
	ck = "Remise à zéro (CK/RPK)",
	restauration = "Restauration (annulation CK/RPK)",
}

-- Droit d'un joueur sur le trésor selon son job : "Consulter", "Preter" ou "Retirer"
function B.ADroit(ply, droit)
	local commande = ORIGINE.CommandeJob(ply:Team())
	return commande ~= nil and ORIGINE.DansListe(CB.Jobs[droit], commande)
end

-- Frais d'une opération (entier, arrondi à l'inférieur)
function B.Frais(typ, montant)
	local taux = CB.Frais[typ] or 0
	return math.floor(montant * taux / 100)
end

-- Montant valide : entier strictement positif
function B.MontantValide(v)
	v = tonumber(v)
	return v ~= nil and v == math.floor(v) and v > 0 and v < 2 ^ 50
end

-- Total à rembourser pour un prêt
function B.TotalDu(montant, taux)
	return math.ceil(montant * (1 + taux / 100))
end
