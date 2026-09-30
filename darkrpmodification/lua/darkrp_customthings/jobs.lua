--[[---------------------------------------------------------------------------
DarkRP custom jobs
---------------------------------------------------------------------------
Médiéval RP — Origine du monde

Les jobs sont générés depuis les tables de hiérarchie ci-dessous : pour
renommer un grade, changez son nom dans la table, le job suit.

Armes : chaque job a uniquement les armes de base (clés, physics gun,
toolgun, gravity gun, données à tous) + le SWEP « origine_mains ».
La sacoche et les SWEPs de race sont donnés par les addons Origine.

This file contains your custom jobs.
This file should also contain jobs from DarkRP that you edited.

Note: If you want to edit a default DarkRP job, first disable it in darkrp_config/disabled_defaults.lua
      Once you've done that, copy and paste the job to this file and edit it.

The default jobs can be found here:
https://github.com/FPtje/DarkRP/blob/master/gamemode/config/jobrelated.lua

For examples and explanation please visit this wiki page:
https://darkrp.miraheze.org/wiki/DarkRP:CustomJobFields
---------------------------------------------------------------------------]]

-- ============================================================
-- HIÉRARCHIES DES FACTIONS
-- Grades 1 à 9 = basse hiérarchie / 10 à 15 = haute hiérarchie
-- ============================================================

-- ---------- EMPIRE (Milice de la Marche) ----------
Empire = {
    grades = {
        [1]  = "Recrue",
        [2]  = "Milicien",
        [3]  = "Soldat",
        [4]  = "Vétéran",
        [5]  = "Chef de file",
        [6]  = "Caporal",
        [7]  = "Caporal-chef",
        [8]  = "Sergent",
        [9]  = "Sergent-chef",
        -- haute hiérarchie
        [10] = "Adjudant",
        [11] = "Adjudant-chef",
        [12] = "Enseigne",
        [13] = "Lieutenant",
        [14] = "Second",
        [15] = "Capitaine de la Milice",
    }
}

-- ---------- CRÉATURES DE LA NUIT ----------
-- Deux arbres séparés (Lycan / Vampire) sur les grades 1 à 9,
-- puis fusion en Hybride commun à partir du grade 10.
CreaturesDeLaNuit = {
    -- Voie de la Lune (Lycan)
    lycan = {
        [1] = "Griffé",
        [2] = "Louveteau",
        [3] = "Rôdeur",
        [4] = "Chasseur",
        [5] = "Traqueur",
        [6] = "Égorgeur",
        [7] = "Fauve",
        [8] = "Meneur",
        [9] = "Alpha",
    },
    -- Voie du Sang (Vampire)
    vampire = {
        [1] = "Assoiffé",
        [2] = "Nouveau-Né",
        [3] = "Affranchi",
        [4] = "Nocturne",
        [5] = "Prédateur",
        [6] = "Vampire",
        [7] = "Baron",
        [8] = "Vicomte",
        [9] = "Comte",
    },
    -- Haute hiérarchie commune (Hybrides)
    hybride = {
        [10] = "Hybride",
        [11] = "Margrave",
        [12] = "Palatin",
        [13] = "Landgrave",
        [14] = "Burgrave",
        [15] = "L'Originel", -- unique : Radu Cosmin
    }
}

-- ---------- CONSORTIUM ----------
Consortium = {
    chef = "Banquier", -- chef local (Ferant Valek)
    employes = {
        [1] = "Courtier",   -- négocie prêts, contrats, location des combattants
        [2] = "Intendant",  -- supérieur du courtier, gère le comptoir
    },
    -- Combattants mercenaires ("les Lames"), loués aux factions contre de l'or
    lames = {
        [1] = "Lame Commune",
        [2] = "Lame Inhabituelle",
        [3] = "Lame Rare",
        [4] = "Lame d'Élite",
        [5] = "Lame Épique",
        [6] = "Lame Héroïque",
        [7] = "Lame Légendaire",
        [8] = "Lame Relique",
        [9] = "Lame Mythique",
    }
}

-- ============================================================
-- RÉGLAGES
-- ============================================================

-- Modèles des joueurs (à remplacer quand vous aurez des playermodels par faction).
-- Le playermodel doit aussi être installé sur le serveur pour les animations wOS.
local MODELE_PAR_DEFAUT = "models/pm_shadow/shadow.mdl"
local MODELES = {
    civil      = { MODELE_PAR_DEFAUT },
    empire     = { MODELE_PAR_DEFAUT },
    lycan      = { MODELE_PAR_DEFAUT },
    vampire    = { MODELE_PAR_DEFAUT },
    hybride    = { MODELE_PAR_DEFAUT },
    consortium = { MODELE_PAR_DEFAUT },
    lames      = { MODELE_PAR_DEFAUT },
}

-- Armes données à TOUS les joueurs : clés (touches de base), physics gun, toolgun, gravity gun
GAMEMODE.Config.DefaultWeapons = { "keys", "weapon_physgun", "gmod_tool", "weapon_physcannon" }

-- Armes propres à chaque job (pour l'instant : les mains vides seulement)
local ARMES_JOB = { "origine_mains" }

-- Salaire selon le grade (en Covan, à ajuster)
local function salaire(grade)
    return 20 + grade * 5
end

-- ============================================================
-- CATÉGORIES
-- ============================================================
local COULEURS = {
    civil      = Color(150, 140, 120),
    empire     = Color(170, 40, 40),
    lycan      = Color(140, 100, 60),
    vampire    = Color(130, 20, 40),
    hybride    = Color(110, 60, 150),
    consortium = Color(200, 160, 60),
    lames      = Color(90, 120, 140),
}

local CATEGORIES = {
    civil      = "Civils",
    empire     = "Empire — Milice de la Marche",
    lycan      = "Créatures de la nuit — Voie de la Lune",
    vampire    = "Créatures de la nuit — Voie du Sang",
    hybride    = "Créatures de la nuit — Hybrides",
    consortium = "Consortium",
    lames      = "Consortium — Les Lames",
}

local ORDRE = { "civil", "empire", "lycan", "vampire", "hybride", "consortium", "lames" }
for i, id in ipairs(ORDRE) do
    DarkRP.createCategory{
        name = CATEGORIES[id],
        categorises = "jobs",
        startExpanded = true,
        color = COULEURS[id],
        canSee = function(ply) return true end,
        sortOrder = i,
    }
end

-- ============================================================
-- CRÉATION DES JOBS
-- ============================================================

-- "Caporal-chef" -> "caporal_chef", "L'Originel" -> "l_originel"
local ACCENTS = {
    ["à"] = "a", ["â"] = "a", ["ä"] = "a", ["ç"] = "c", ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e",
    ["î"] = "i", ["ï"] = "i", ["ô"] = "o", ["ö"] = "o", ["ù"] = "u", ["û"] = "u", ["ü"] = "u",
    ["À"] = "a", ["Â"] = "a", ["Ç"] = "c", ["É"] = "e", ["È"] = "e", ["Ê"] = "e", ["Î"] = "i", ["Ô"] = "o", ["Û"] = "u",
}
local function commande(prefixe, nom)
    local s = nom
    for accent, lettre in pairs(ACCENTS) do s = string.Replace(s, accent, lettre) end
    s = string.lower(s):gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    return prefixe .. "_" .. s
end

local EQUIPES = {} -- faction -> { [équipe] = true }

-- faction, nom du grade, grade (1 à 15), réglages en plus
local function creerJob(faction, nom, grade, prefixe, extra)
    extra = extra or {}
    local cmd = commande(prefixe, nom)
    local haute = grade >= 10
    local description = CATEGORIES[faction] .. "\nGrade " .. grade .. " : " .. nom ..
        (haute and "\nHaute hiérarchie." or "\nBasse hiérarchie.") ..
        (extra.description and ("\n" .. extra.description) or "")

    local equipe = DarkRP.createJob(nom, {
        color = COULEURS[faction],
        model = MODELES[faction],
        description = description,
        weapons = ARMES_JOB,
        command = cmd,
        max = extra.max or 0,
        salary = salaire(grade),
        admin = 0,
        vote = false,
        hasLicense = false,
        candemote = not haute and not extra.unique,
        category = CATEGORIES[faction],
        sortOrder = grade,
        -- Champs lus par les addons Origine
        origine_faction = faction,
        origine_grade = grade,
        origine_haute_hierarchie = haute,
    })
    _G["TEAM_" .. string.upper(cmd)] = equipe
    EQUIPES[faction] = EQUIPES[faction] or {}
    EQUIPES[faction][equipe] = true
    return equipe
end

-- ---------- Civils (job par défaut des nouveaux personnages) ----------
TEAM_VILLAGEOIS = creerJob("civil", "Villageois", 1, "civil", {
    description = "Habitant de la Marche, sans allégeance.",
})

-- ---------- Empire ----------
for grade = 1, 15 do
    local nom = Empire.grades[grade]
    if nom then
        creerJob("empire", nom, grade, "empire", { max = (grade == 15) and 1 or 0, unique = grade == 15 })
    end
end

-- ---------- Créatures de la nuit ----------
for grade = 1, 9 do
    if CreaturesDeLaNuit.lycan[grade] then creerJob("lycan", CreaturesDeLaNuit.lycan[grade], grade, "lycan") end
end
for grade = 1, 9 do
    if CreaturesDeLaNuit.vampire[grade] then creerJob("vampire", CreaturesDeLaNuit.vampire[grade], grade, "vampire") end
end
for grade = 10, 15 do
    local nom = CreaturesDeLaNuit.hybride[grade]
    if nom then
        creerJob("hybride", nom, grade, "hybride", {
            max = (grade == 15) and 1 or 0,
            unique = grade == 15,
            description = (grade == 15) and "Unique : Radu Cosmin." or nil,
        })
    end
end

-- ---------- Consortium ----------
creerJob("consortium", Consortium.chef, 15, "consortium", {
    max = 1, unique = true, description = "Chef local du Consortium (Ferant Valek).",
})
creerJob("consortium", Consortium.employes[1], 1, "consortium", {
    description = "Négocie prêts, contrats et location des combattants.",
})
creerJob("consortium", Consortium.employes[2], 2, "consortium", {
    description = "Supérieur du courtier, gère le comptoir.",
})
for grade = 1, 9 do
    local nom = Consortium.lames[grade]
    if nom then
        creerJob("lames", nom, grade, "consortium", {
            description = "Combattant mercenaire, loué aux factions contre de l'or.",
        })
    end
end

-- ============================================================
-- RÉGLAGES DARKRP LIÉS AUX JOBS
-- ============================================================

-- Job des nouveaux personnages (et quand le job sauvegardé n'est plus disponible)
GAMEMODE.DefaultTeam = TEAM_VILLAGEOIS

-- Médiéval RP : aucune police DarkRP (avis de recherche, mandats, prison désactivés par origine_personnages)
GAMEMODE.CivilProtection = {}

-- Chats de faction (/g message)
local function membre(...)
    local factions = { ... }
    return function(ply)
        for _, f in ipairs(factions) do
            if EQUIPES[f] and EQUIPES[f][ply:Team()] then return true end
        end
        return false
    end
end
DarkRP.createGroupChat(membre("empire"))
DarkRP.createGroupChat(membre("lycan", "vampire", "hybride"))
DarkRP.createGroupChat(membre("consortium", "lames"))
