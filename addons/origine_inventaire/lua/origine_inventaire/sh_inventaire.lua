--[[-----------------------------------------------------------------------
	Origine du monde — inventaire (partagé)

	Un objet = { classe, modele, arme, n }
	  classe : classe de l'entité (pour une arme : la classe de l'arme)
	  modele : modèle de l'entité
	  arme   : classe d'arme si c'est une arme, sinon nil
	  n      : quantité dans la case (1 à TaillePile)
-------------------------------------------------------------------------]]

ORIGINE.Inv = ORIGINE.Inv or {}
local I = ORIGINE.Inv
local CI = ORIGINE.ConfigInv

-- Liste des entités autorisées (depuis sh_entites.lua)
function I.ChargerListe()
	I.Autorisees = {}
	local liste = ORIGINE_INV and ORIGINE_INV.EntitesAutorisees or {}
	for _, c in ipairs(liste) do
		c = string.Trim(tostring(c))
		if c ~= "" then I.Autorisees[c] = true end
	end
	I.Interdites = {}
	for _, c in ipairs(CI.Interdites) do I.Interdites[c] = true end
	ORIGINE_INV = nil -- une seule table globale : ORIGINE
end

function I.EstAutorisee(classe)
	if not isstring(classe) or classe == "" then return false end
	if I.Interdites[classe] or ORIGINE.EstSwepDeRace(classe) then return false end
	return I.Autorisees[classe] == true
end

function I.Cle(objet)
	return (objet.classe or "") .. "|" .. (objet.arme or "") .. "|" .. string.lower(objet.modele or "")
end

function I.Capacite(ply)
	local groupes = CI.GroupesVIP or ORIGINE.Config.GroupesVIP
	if IsValid(ply) and ORIGINE.DansListe(groupes, ply:GetUserGroup()) then return CI.Capacite.VIP end
	return CI.Capacite.Joueur
end

function I.Copier(objet)
	return { classe = objet.classe, modele = objet.modele, arme = objet.arme }
end

-- Ajoute UN objet dans les cases (piles de TaillePile). Retourne true si rangé.
-- Au-delà de la capacité (VIP expiré), plus rien ne peut être rangé.
function I.AjouterDans(cases, objet, capacite)
	if #cases > capacite then return false end
	local cle = I.Cle(objet)
	for _, c in ipairs(cases) do
		if I.Cle(c) == cle and (c.n or 1) < CI.TaillePile then
			c.n = (c.n or 1) + 1
			return true
		end
	end
	if #cases >= capacite then return false end
	local nouveau = I.Copier(objet)
	nouveau.n = 1
	cases[#cases + 1] = nouveau
	return true
end

-- Retire UN objet de la case index. Retourne l'objet retiré (ou nil).
function I.RetirerDe(cases, index)
	local c = cases[index]
	if not c then return nil end
	local objet = I.Copier(c)
	c.n = (c.n or 1) - 1
	if c.n <= 0 then table.remove(cases, index) end
	return objet
end

function I.Compter(cases)
	local total = 0
	for _, c in ipairs(cases) do total = total + (c.n or 1) end
	return total
end

-- Nom d'affichage d'un objet
function I.NomObjet(objet)
	if objet.arme then
		local w = weapons.GetStored(objet.arme)
		if w and w.PrintName then
			return CLIENT and language.GetPhrase(w.PrintName) or w.PrintName
		end
		return objet.arme
	end
	local e = scripted_ents.GetStored(objet.classe)
	if e and e.t and e.t.PrintName and e.t.PrintName ~= "" then return e.t.PrintName end
	for _, v in ipairs(DarkRPEntities or {}) do
		if v.ent == objet.classe and v.name then return v.name end
	end
	local l = list.Get("SpawnableEntities")[objet.classe]
	if l and l.PrintName then return l.PrintName end
	return objet.classe
end
