--[[-----------------------------------------------------------------------
	Origine du monde — historique (actions staff, tirages, rerolls)
-------------------------------------------------------------------------]]

ORIGINE.Historique = ORIGINE.Historique or {}
local H = ORIGINE.Historique

-- Types d'actions enregistrées (clé = type stocké, valeur = libellé affiché)
H.Types = {
	tirage = "Tirage de race",
	reroll = "Reroll de race",
	race = "Modification de race",
	rerolls = "Points de reroll",
	rerolls_tous = "Rerolls pour tous",
	nom = "Changement de nom",
	forcer_slot = "Slot forcé",
	event = "Slot EVENT",
	inventaire = "Inventaire",
	ck = "CK",
	rpk = "RPK",
	annulation = "Annulation CK/RPK",
}

local function versJSON(v)
	if v == nil then return nil end
	if istable(v) then return util.TableToJSON(v) end
	return tostring(v)
end

--[[
	Enregistre une action.
	infos = {
		type, staff (joueur ou nil pour le système), cible_sid, cible_slot, cible_nom,
		avant, apres (tables ou textes), raison
	}
]]
function H.Ajouter(infos)
	local staff = infos.staff
	local staffSid, staffNom = nil, "Système"
	if IsValid(staff) then
		staffSid, staffNom = staff:SteamID64(), staff:Nick()
	elseif isstring(staff) then
		staffNom = staff
	end
	ORIGINE.DB.Requete([[INSERT INTO origine_historique
		(date, type, staff_sid, staff_nom, cible_sid, cible_slot, cible_nom, avant, apres, raison)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
		os.time(), infos.type, staffSid, staffNom, infos.cible_sid, infos.cible_slot,
		infos.cible_nom, versJSON(infos.avant), versJSON(infos.apres), infos.raison,
	})
end
