--[[-----------------------------------------------------------------------
	Origine du monde — fonctions utilitaires partagées
-------------------------------------------------------------------------]]

ORIGINE = ORIGINE or {}
local C = ORIGINE.Config

ORIGINE.NB_SLOTS = 5
ORIGINE.SLOT_VIP = 3
ORIGINE.SLOT_EVENT = 4
ORIGINE.SLOT_STAFF = 5

---------------------------------------------------------------------------
-- Nombres et monnaie
---------------------------------------------------------------------------
function ORIGINE.FormaterNombre(n)
	n = math.floor(tonumber(n) or 0)
	local signe = n < 0 and "-" or ""
	local s = tostring(math.abs(n))
	local sep = C.Monnaie.SeparateurMilliers
	local res = s:reverse():gsub("(%d%d%d)", "%1" .. sep:reverse()):reverse()
	if res:sub(1, #sep) == sep then res = res:sub(#sep + 1) end
	return signe .. res
end

function ORIGINE.FormaterCovan(n)
	return ORIGINE.FormaterNombre(n) .. " " .. C.Monnaie.Nom
end

---------------------------------------------------------------------------
-- UTF-8 (décodage manuel pour ne dépendre d'aucune bibliothèque)
---------------------------------------------------------------------------
function ORIGINE.Utf8Codes(s)
	local codes, i, n = {}, 1, #s
	while i <= n do
		local c = s:byte(i)
		local cp, len
		if c < 0x80 then cp, len = c, 1
		elseif c >= 0xC2 and c < 0xE0 then cp, len = c - 0xC0, 2
		elseif c >= 0xE0 and c < 0xF0 then cp, len = c - 0xE0, 3
		elseif c >= 0xF0 and c < 0xF5 then cp, len = c - 0xF0, 4
		else return nil end
		for j = 1, len - 1 do
			local b = s:byte(i + j)
			if not b or b < 0x80 or b >= 0xC0 then return nil end
			cp = cp * 64 + (b - 0x80)
		end
		codes[#codes + 1] = cp
		i = i + len
	end
	return codes
end

function ORIGINE.Utf8Char(cp)
	if cp < 0x80 then return string.char(cp) end
	if cp < 0x800 then
		return string.char(0xC0 + math.floor(cp / 64), 0x80 + cp % 64)
	end
	if cp < 0x10000 then
		return string.char(0xE0 + math.floor(cp / 4096), 0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
	end
	return string.char(0xF0 + math.floor(cp / 262144), 0x80 + math.floor(cp / 4096) % 64,
		0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
end

-- Minuscule d'un point de code (ASCII + Latin-1 + Œ/Ÿ)
local function minuscule(cp)
	if cp >= 65 and cp <= 90 then return cp + 32 end
	if cp >= 0xC0 and cp <= 0xDE and cp ~= 0xD7 then return cp + 32 end
	if cp == 0x152 then return 0x153 end
	if cp == 0x178 then return 0xFF end
	return cp
end

-- Lettre sans accent, pour comparer les noms (é -> e, œ -> oe…)
local SANS_ACCENT = {
	[0xE0] = "a", [0xE1] = "a", [0xE2] = "a", [0xE3] = "a", [0xE4] = "a", [0xE5] = "a", [0xE6] = "ae",
	[0xE7] = "c", [0xE8] = "e", [0xE9] = "e", [0xEA] = "e", [0xEB] = "e",
	[0xEC] = "i", [0xED] = "i", [0xEE] = "i", [0xEF] = "i", [0xF1] = "n",
	[0xF2] = "o", [0xF3] = "o", [0xF4] = "o", [0xF5] = "o", [0xF6] = "o", [0xF8] = "o",
	[0xF9] = "u", [0xFA] = "u", [0xFB] = "u", [0xFC] = "u", [0xFD] = "y", [0xFF] = "y",
	[0x153] = "oe", [0xDF] = "ss",
}

-- Forme « clé » d'un texte : minuscules, sans accents, apostrophes unifiées.
function ORIGINE.Normaliser(s)
	local codes = ORIGINE.Utf8Codes(tostring(s or "")) or {}
	local out = {}
	for _, cp in ipairs(codes) do
		cp = minuscule(cp)
		if cp == 0x2019 then cp = 39 end
		out[#out + 1] = SANS_ACCENT[cp] or ORIGINE.Utf8Char(cp)
	end
	return table.concat(out)
end

---------------------------------------------------------------------------
-- Validation des noms
---------------------------------------------------------------------------
local function estLettre(cp)
	if (cp >= 65 and cp <= 90) or (cp >= 97 and cp <= 122) then return true end
	if cp >= 0xC0 and cp <= 0xFF and cp ~= 0xD7 and cp ~= 0xF7 then return true end
	if cp == 0x152 or cp == 0x153 or cp == 0x178 then return true end
	return false
end

-- Vérifie une partie du nom (prénom ou nom). Retourne true ou false, "raison".
function ORIGINE.ValiderPartieNom(s, libelle)
	libelle = libelle or "Le nom"
	if type(s) ~= "string" then return false, libelle .. " est invalide." end
	local codes = ORIGINE.Utf8Codes(s)
	if not codes then return false, libelle .. " contient des caractères invalides." end
	local min, max = C.Nom.Min, C.Nom.Max
	if #codes < min then return false, libelle .. " doit faire au moins " .. min .. " caractères." end
	if #codes > max then return false, libelle .. " doit faire au plus " .. max .. " caractères." end
	for i, cp in ipairs(codes) do
		local ok = estLettre(cp) or cp == 45 or cp == 39 or cp == 0x2019
		if not ok then
			if cp >= 48 and cp <= 57 then return false, libelle .. " ne doit pas contenir de chiffres." end
			return false, libelle .. " ne peut contenir que des lettres, un tiret ou une apostrophe."
		end
		if i == 1 and not estLettre(cp) then return false, libelle .. " doit commencer par une lettre." end
	end
	local dernier = codes[#codes]
	if not estLettre(dernier) then return false, libelle .. " doit finir par une lettre." end
	return true
end

-- Met la première lettre en majuscule (le reste tel que saisi).
function ORIGINE.Capitaliser(s)
	local codes = ORIGINE.Utf8Codes(s) or {}
	if #codes == 0 then return s end
	local cp = codes[1]
	if cp >= 97 and cp <= 122 then cp = cp - 32
	elseif cp >= 0xE0 and cp <= 0xFE and cp ~= 0xF7 then cp = cp - 32 end
	codes[1] = cp
	local out = {}
	for _, c in ipairs(codes) do out[#out + 1] = ORIGINE.Utf8Char(c) end
	return table.concat(out)
end

-- Vérifie prénom + nom (longueur, caractères, liste noire). Pas l'unicité (serveur).
function ORIGINE.ValiderNom(prenom, nom)
	prenom = string.Trim and string.Trim(prenom or "") or prenom
	nom = string.Trim and string.Trim(nom or "") or nom
	local ok, err = ORIGINE.ValiderPartieNom(prenom, "Le prénom")
	if not ok then return false, err end
	ok, err = ORIGINE.ValiderPartieNom(nom, "Le nom")
	if not ok then return false, err end

	local p, n = ORIGINE.Normaliser(prenom), ORIGINE.Normaliser(nom)
	local complet = p .. " " .. n
	for _, interdit in ipairs(C.Nom.NomsInterdits) do
		local cle = ORIGINE.Normaliser(interdit)
		if cle ~= "" and (cle == p or cle == n or cle == complet) then
			return false, "Ce nom n'est pas autorisé."
		end
	end
	for _, mot in ipairs(C.Nom.MotsInterdits) do
		local cle = ORIGINE.Normaliser(mot)
		if cle ~= "" and string.find(complet, cle, 1, true) then
			return false, "Ce nom n'est pas autorisé."
		end
	end
	return true, nil, prenom, nom
end

function ORIGINE.CleNom(prenom, nom)
	return ORIGINE.Normaliser(prenom) .. " " .. ORIGINE.Normaliser(nom)
end

---------------------------------------------------------------------------
-- Races et raretés
---------------------------------------------------------------------------
ORIGINE.RacesParId = {}
ORIGINE.RaretesParId = {}

function ORIGINE.IndexerRaces()
	ORIGINE.RacesParId = {}
	ORIGINE.RaretesParId = {}
	for i, r in ipairs(C.Raretes) do
		r.Ordre = i
		ORIGINE.RaretesParId[r.id] = r
	end
	for i, race in ipairs(C.Races) do
		race.Ordre = i
		ORIGINE.RacesParId[race.id] = race
	end
end
ORIGINE.IndexerRaces()

function ORIGINE.Race(id) return ORIGINE.RacesParId[id] end
function ORIGINE.Rarete(id) return ORIGINE.RaretesParId[id] end

function ORIGINE.RareteDeRace(id)
	local race = ORIGINE.Race(id)
	return race and ORIGINE.Rarete(race.Rarete)
end

local BLANC = Color and Color(255, 255, 255) or { r = 255, g = 255, b = 255, a = 255 }
function ORIGINE.CouleurRace(id)
	local r = ORIGINE.RareteDeRace(id)
	return r and r.Couleur or BLANC
end

function ORIGINE.NomRace(id)
	local race = ORIGINE.Race(id)
	return race and race.Nom or "Inconnue"
end

-- Taux recalculés depuis les poids : { races = {id = %}, raretes = {id = %} }
function ORIGINE.Taux()
	local total = 0
	for _, race in ipairs(C.Races) do total = total + math.max(0, tonumber(race.Poids) or 0) end
	local res = { races = {}, raretes = {} }
	for _, r in ipairs(C.Raretes) do res.raretes[r.id] = 0 end
	for _, race in ipairs(C.Races) do
		local p = total > 0 and (math.max(0, tonumber(race.Poids) or 0) / total * 100) or 0
		res.races[race.id] = p
		res.raretes[race.Rarete] = (res.raretes[race.Rarete] or 0) + p
	end
	return res
end

-- Format « 3,5 % »
function ORIGINE.FormaterTaux(p)
	local arrondi = math.floor(p * 10 + 0.5) / 10
	local s
	if arrondi == math.floor(arrondi) then s = tostring(math.floor(arrondi)) else s = string.format("%.1f", arrondi) end
	return (s:gsub("%.", ",")) .. " %"
end

-- Tirage pondéré. aleatoire : fonction optionnelle qui retourne un nombre dans [0, 1[
function ORIGINE.TirerRace(aleatoire)
	aleatoire = aleatoire or math.random
	local total = 0
	for _, race in ipairs(C.Races) do total = total + math.max(0, tonumber(race.Poids) or 0) end
	if total <= 0 then return C.Races[1] and C.Races[1].id end
	local x = aleatoire() * total
	local cumul = 0
	for _, race in ipairs(C.Races) do
		cumul = cumul + math.max(0, tonumber(race.Poids) or 0)
		if x < cumul then return race.id end
	end
	return C.Races[#C.Races].id
end

-- Liste lisible des effets chiffrés (en plus du texte descriptif)
function ORIGINE.EffetsChiffres(id)
	local race = ORIGINE.Race(id)
	if not race then return {} end
	local m, l = race.Mod or {}, {}
	local function pct(v) return (v > 0 and "+" or "") .. v .. " %" end
	if m.PV and m.PV ~= 1 then l[#l + 1] = "PV max ×" .. tostring(m.PV):gsub("%.", ",") end
	if m.Armure and m.Armure ~= 1 then l[#l + 1] = "Armure max ×" .. tostring(m.Armure):gsub("%.", ",") end
	if m.Reduction and m.Reduction ~= 0 then l[#l + 1] = "Réduction des dégâts : " .. m.Reduction .. " %" end
	if m.Vitesse and m.Vitesse ~= 1 then l[#l + 1] = "Vitesse ×" .. tostring(m.Vitesse):gsub("%.", ",") end
	local noms = { melee = "mêlée", lame_legere = "lames légères", arc = "arc", magie = "magie" }
	for cat, v in pairs(m.Degats or {}) do
		if v ~= 0 then l[#l + 1] = "Dégâts " .. (noms[cat] or cat) .. " : " .. pct(v) end
	end
	if m.Esquive and m.Esquive > 0 then l[#l + 1] = "Esquive : " .. m.Esquive .. " %" end
	if m.Regen and (m.Regen.PV or 0) > 0 then
		l[#l + 1] = "Régénération : " .. m.Regen.PV .. " PV / " .. (m.Regen.Intervalle or 5) .. " s hors combat"
	end
	if m.Feu and m.Feu ~= 0 then l[#l + 1] = "Résistance au feu : " .. m.Feu .. " %" end
	if m.Magie and m.Magie ~= 0 then l[#l + 1] = "Résistance magique : " .. m.Magie .. " %" end
	if m.Discretion then l[#l + 1] = "Discrétion" end
	return l
end

---------------------------------------------------------------------------
-- Groupes et slots
---------------------------------------------------------------------------
local function dansListe(liste, valeur)
	for _, v in ipairs(liste or {}) do
		if v == valeur then return true end
	end
	return false
end
ORIGINE.DansListe = dansListe

function ORIGINE.EstVIP(ply)
	return IsValid(ply) and dansListe(C.GroupesVIP, ply:GetUserGroup())
end

function ORIGINE.EstStaffSlot(ply)
	return IsValid(ply) and dansListe(C.GroupesStaff, ply:GetUserGroup())
end

-- Le slot est-il jouable par ce joueur ? compte = données du compte (event_debloque)
function ORIGINE.SlotAccessible(ply, slot, compte)
	if slot == 1 or slot == 2 then return true end
	if slot == ORIGINE.SLOT_VIP then
		if ORIGINE.EstVIP(ply) then return true end
		return false, C.Slots[slot].Verrou
	end
	if slot == ORIGINE.SLOT_EVENT then
		if compte and tonumber(compte.event_debloque) == 1 then return true end
		return false, C.Slots[slot].Verrou
	end
	if slot == ORIGINE.SLOT_STAFF then
		if ORIGINE.EstStaffSlot(ply) then return true end
		return false, C.Slots[slot].Verrou
	end
	return false, "Slot invalide"
end

-- Toutes les classes de SWEP de race (pour les retirer / les exclure)
function ORIGINE.EstSwepDeRace(classe)
	for _, race in ipairs(C.Races) do
		if dansListe(race.Mod and race.Mod.Sweps, classe) then return true end
	end
	return false
end

-- Catégorie d'une classe d'arme (melee, lame_legere, arc, magie) ou nil
function ORIGINE.CategorieArme(classe)
	if not classe or classe == "" then return nil end
	for cat, liste in pairs(C.CategoriesArmes) do
		if dansListe(liste, classe) then return cat end
	end
	return nil
end

---------------------------------------------------------------------------
-- Données du personnage visibles par tous (variables réseau)
---------------------------------------------------------------------------
function ORIGINE.Prenom(ply) return ply:GetNW2String("origine_prenom", "") end
function ORIGINE.NomFamille(ply) return ply:GetNW2String("origine_nom", "") end
function ORIGINE.NomComplet(ply)
	local p, n = ORIGINE.Prenom(ply), ORIGINE.NomFamille(ply)
	if p == "" then return ply:Nick() end
	return p .. " " .. n
end
function ORIGINE.RaceJoueur(ply)
	local id = ply:GetNW2String("origine_race", "")
	return id ~= "" and id or nil
end
function ORIGINE.EnMenu(ply) return ply:GetNW2Bool("origine_enmenu", false) end
function ORIGINE.SlotJoueur(ply) return ply:GetNW2Int("origine_slot", 0) end

function ORIGINE.ModsJoueur(ply)
	local race = ORIGINE.Race(ORIGINE.RaceJoueur(ply))
	return race and race.Mod
end

---------------------------------------------------------------------------
-- Discrétion : bruits de pas atténués (partagé client/serveur)
---------------------------------------------------------------------------
if hook then
	hook.Add("PlayerFootstep", "origine_discretion", function(ply, pos, pied, son, volume)
		if ORIGINE.EnMenu(ply) then return true end
		local m = ORIGINE.ModsJoueur(ply)
		if not (m and m.Discretion) then return end
		if SERVER then
			ply:EmitSound(son, 60, 100, volume * C.Discretion.VolumePas)
		end
		return true
	end)
end
