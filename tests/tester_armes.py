"""Tests hors jeu des armes wOS de base (origine_armes), avec un wOS simulé (LuaJIT via lupa).

Vérifie : catégories « Origine [Faction] Weapon », saut de Force seul pour les factions, lame
« Invisible », pas de brûlure ni d'étourdissement, sons vides, listes du Mage construites depuis
wOS (packs absents ignorés, pouvoirs ajoutés inclus), cooldown pour le sélecteur, enregistrement
de la lame, catégorie « magie » des pouvoirs du Mage.

Usage : python3 tests/tester_armes.py
"""
import pathlib
import sys

from lupa import luajit21 as lupa

racine = pathlib.Path(__file__).resolve().parent.parent / "addons" / "origine_armes" / "lua"
lua = lupa.LuaRuntime()
lua.execute(r"""
Color = function(r, g, b, a) return { r = r, g = g, b = b, a = a or 255 } end
IsValid = function(v) return v ~= nil and v ~= false end
istable = function(v) return type(v) == "table" end
isstring = function(v) return type(v) == "string" end
table.Copy = function(t) local c = {} for k, v in pairs(t) do c[k] = type(v) == "table" and table.Copy(v) or v end return c end
SERVER, CLIENT = true, false
TEMPS = 100
CurTime = function() return TEMPS end
RENDERGROUP_BOTH = 1
AddCSLuaFile = function() end
HOOKS = {}
hook = { Add = function(ev, id, fn) HOOKS[ev .. "/" .. id] = fn end }
BASES = { wos_adv_single_lightsaber_base = { Initialize = function(self) self.InitBase = true end } }
baseclass = { Get = function(n) BASES[n] = BASES[n] or {} return BASES[n] end }
STOCKEES = {}
weapons = { GetStored = function(c) return STOCKEES[c] end }
killicon = { Add = function() end }
ORIGINE = { Inv = { Autorisees = {}, Autoriser = function(c) ORIGINE.Inv.Autorisees[c] = true end } }
LAMES = {}
wOS = { ALCS = { LightsaberBase = { Blades = LAMES, AddBlade = function(self, t) LAMES[t.Name] = t end } } }
IN_ATTACK, IN_ATTACK2 = 1, 2048
local VMT = {}
VMT.__index = VMT
function VMT:DistToSqr(o) local dx, dy, dz = self.x - o.x, self.y - o.y, self.z - o.z return dx * dx + dy * dy + dz * dz end
Vector = function(x, y, z) return setmetatable({ x = x, y = y, z = z }, VMT) end
Angle = function(p, y, r) return { p = p, y = y, r = r } end
vector_origin, angle_zero = Vector(0, 0, 0), Angle(0, 0, 0)
PRECACHE = {}
JOUEURS = {}
player = { GetAll = function() return JOUEURS end }
isfunction = function(v) return type(v) == "function" end
SONS_CREES, SONS_JOUES, DECALS, EFFETS = {}, {}, {}, {}
CreateSound = function(ent, nom) SONS_CREES[#SONS_CREES + 1] = nom return { nom = nom } end
sound = { Play = function(nom) SONS_JOUES[#SONS_JOUES + 1] = nom end }
util = { Decal = function(nom) DECALS[#DECALS + 1] = nom end, Effect = function(nom) EFFETS[#EFFETS + 1] = nom end,
	PrecacheModel = function(m) PRECACHE[m] = true end }
""")
lua.execute((racine / "origine_armes" / "sh_modele.lua").read_text(encoding="utf-8"))
lua.execute((racine / "origine_armes" / "sh_armes.lua").read_text(encoding="utf-8"))
lua.execute((racine / "origine_armes" / "sh_epee.lua").read_text(encoding="utf-8"))


def charger(cle):
    lua.execute("SWEP = { Primary = {}, Secondary = {} }")
    lua.execute((racine / "weapons" / f"weapon_origine_{cle}.lua").read_text(encoding="utf-8"))
    lua.execute(f'STOCKEES["weapon_origine_{cle}"] = SWEP')
    return lua.globals().SWEP


G = lua.globals()
echecs = total = 0


def verifier(nom, ok, detail=""):
    global echecs, total
    total += 1
    if ok:
        print(f"ok     {nom}")
    else:
        echecs += 1
        print(f"ÉCHEC  {nom} {detail}")


def liste(t):
    return [t[i] for i in range(1, len(t) + 1)] if t else []


categories = {"nuit": "Origine Créatures de la nuit Weapon", "empire": "Origine Empire Weapon",
              "consortium": "Origine Consortium Weapon", "mage": "Origine Mage Weapon"}
armes = {cle: charger(cle) for cle in categories}

for cle, s in armes.items():
    verifier(f"{cle} : catégorie", s.Category == categories[cle], s.Category)
    verifier(f"{cle} : classe", s.Class == f"weapon_origine_{cle}")
    verifier(f"{cle} : lame invisible", s.CustomSettings["Blade"] == "Invisible")
    verifier(f"{cle} : longueur normale (portée gardée)", s.UseLength == 42)
    verifier(f"{cle} : pas de brûlure, pas d'étourdissement", s.SaberBurnDamage == 0 and s.ShouldStun is False)
    verifier(f"{cle} : ni compétences, ni atelier, formes wOS", s.UseSkills is False and s.PersonalLightsaber is False and s.UseForms is False)
    verifier(f"{cle} : aucun son (allumage, extinction, bourdonnement, balancement)",
             s.UseLoopSound == s.UseOnSound == s.UseOffSound == s.UseSwingSound == "common/null.wav")
    verifier(f"{cle} : lumière de lame éteinte (noir)", s.UseColor.r == 0 and s.UseColor.g == 0 and s.UseColor.b == 0)
    verifier(f"{cle} : base wOS", s.Base == "wos_adv_single_lightsaber_base")
    verifier(f"{cle} : pas d'icône de sabre dans le sélecteur", s.OrigineSansIcone is True)
    verifier(f"{cle} : rangeable dans l'inventaire", G.ORIGINE.Inv.Autorisees[f"weapon_origine_{cle}"] is True)

for cle, s in armes.items():
    verifier(f"{cle} : modèle d'épée templarsword", s.UseHilt == s.WorldModel == "models/peanut/templarsword.mdl")
    verifier(f"{cle} : placement en main réglable", s.OrigineEnMain is not None and s.OrigineEnMain.Garde == 0.2)
    verifier(f"{cle} : dessin wOS non remplacé", s.DrawWorldModelTranslucent is None and s.GetSaberPosAng is None)
verifier("modèle préchargé", G.PRECACHE["models/peanut/templarsword.mdl"] is True)

for cle in ("nuit", "empire", "consortium"):
    s = armes[cle]
    verifier(f"{cle} : saut de Force uniquement", liste(s.ForcePowerList) == ["Force Leap"], liste(s.ForcePowerList))
    verifier(f"{cle} : aucun ultime", len(liste(s.DevestatorList)) == 0)

# Mage sans wOS chargé : liste connue complète
mage = armes["mage"]
p = liste(mage.ForcePowerList)
verifier("mage : tous les pouvoirs connus (wOS pas encore chargé)", len(p) == 44 and "Meditate" in p and "Channel Hatred" in p, len(p))
verifier("mage : tous les ultimes connus", liste(mage.DevestatorList) == ["Kyber Slam", "Sonic Discharge", "Lightning Coil"])

# wOS chargé SANS les packs, avec un pouvoir ajouté plus tard
lua.execute(r"""
wOS.AvailablePowers = {}
for _, n in ipairs({ "Force Leap", "Charge", "Force Absorb", "Saber Throw", "Force Heal", "Group Heal", "Cloak",
	"Force Reflect", "Rage", "Shadow Strike", "Force Pull", "Force Push", "Lightning Strike", "Advanced Cloak",
	"Force Lightning", "Force Combust", "Force Repulse", "Storm", "Meditate", "Channel Hatred", "Pouvoir Maison" }) do
	wOS.AvailablePowers[n] = { name = n }
end
wOS.AvailableDevestators = { ["Kyber Slam"] = {}, ["Lightning Coil"] = {}, ["Sonic Discharge"] = {} }
HOOKS["wOS.ALCS.PostLoaded/origine_armes"]()
INSTANCE = setmetatable({}, { __index = STOCKEES["weapon_origine_mage"] })
""")
inst = G.INSTANCE
p = liste(inst.ForcePowerList)
verifier("mage sans packs : 20 pouvoirs de base + pouvoir ajouté", len(p) == 21 and p[-1] == "Pouvoir Maison", p)
verifier("mage sans packs : aucun pouvoir de pack", "Burn Out" not in p and "Force Choke" not in p)
verifier("mage : ordre wOS respecté (Force Leap en premier)", p[0] == "Force Leap")
verifier("mage : Initialize de wOS non remplacé (jauge de Force, pouvoirs)", all(a.Initialize is None for a in armes.values()))
verifier("mage : classe mise à jour après le chargement de wOS", len(liste(G.STOCKEES["weapon_origine_mage"].ForcePowerList)) == 21)
verifier("lame « Invisible » enregistrée dans wOS", G.LAMES["Invisible"] is not None and G.LAMES["Invisible"].EnvelopeMaterial == ""
         and G.LAMES["Invisible"].DrawTrail is False and G.LAMES["Invisible"].UseParticle is False)

# Cooldown du pouvoir sélectionné pour le sélecteur
lua.execute(r"""
ARME = setmetatable({}, { __index = STOCKEES["weapon_origine_empire"] })
ARME.GetForceCooldown = function() return 1.5 end
ARME.GetForceType = function() return 1 end
ARME.GetActiveForcePowerType = function() return { name = "Force Leap", cooldown = 2 } end
CD = ARME:OrigineCooldowns()
ARME.GetForceCooldown = function() return 0 end
CD0 = ARME:OrigineCooldowns()
""")
verifier("cooldown : temps restant et durée du pouvoir", abs(G.CD.primaire.fin - 101.5) < 1e-6 and G.CD.primaire.duree == 2)
verifier("cooldown : rien quand il est fini", G.CD0.primaire is None)

# Catégorie « magie » : pouvoir du Mage (inflicteur = le joueur), lame du Mage (inflicteur = l'arme)
lua.execute(r"""
MAGE_ARME = { GetClass = function() return "weapon_origine_mage" end }
JOUEUR = { IsPlayer = function() return true end, GetActiveWeapon = function() return MAGE_ARME end }
local function dmg(infl) return { GetInflictor = function() return infl end } end
F = HOOKS["origine_CategorieDegats/origine_armes"]
CAT_POUVOIR = F(dmg(JOUEUR), JOUEUR)
CAT_LAME = F(dmg(MAGE_ARME), JOUEUR)
HOOKS["wOS.ALCS.CanUseForcepower/origine_armes_suivi"](JOUEUR)
CAT_RECENT = F(dmg(MAGE_ARME), JOUEUR)
TEMPS = TEMPS + 2
CAT_APRES = F(dmg(MAGE_ARME), JOUEUR)
EMPIRE_ARME = { GetClass = function() return "weapon_origine_empire" end }
JOUEUR2 = { IsPlayer = function() return true end, GetActiveWeapon = function() return EMPIRE_ARME end }
CAT_EMPIRE = F(dmg(JOUEUR2), JOUEUR2)
""")
verifier("pouvoir offensif du Mage = magie", G.CAT_POUVOIR == "magie")
verifier("coup de lame du Mage = mêlée (catégorie de l'arme)", G.CAT_LAME is None)
verifier("dégâts juste après un pouvoir = magie", G.CAT_RECENT == "magie")
verifier("coup de lame 2 s après = mêlée", G.CAT_APRES is None)
verifier("armes de faction : jamais magie", G.CAT_EMPIRE is None)

# --- Comportement d'épée (sh_epee.lua) ---
lua.execute(r"""
local function arme(c) return { GetClass = function() return c end } end
function joueur(pos, classe)
	local j = { pos = pos, touches = {}, w = classe and arme(classe) or nil }
	j.IsPlayer = function() return true end
	j.GetPos = function() return j.pos end
	j.GetActiveWeapon = function() return j.w end
	j.KeyDown = function(_, k) return j.touches[k] == true end
	return j
end
PORTEUR = joueur(Vector(0, 0, 0), "weapon_origine_empire")
AUTRE = joueur(Vector(2000, 0, 0), nil)
JOUEURS = { PORTEUR, AUTRE }
local emit = HOOKS["EntityEmitSound/origine_armes_sons"]
S_ARME = emit({ SoundName = "lightsaber/saber_hit.wav", Entity = PORTEUR.w })
S_PREFIXE = emit({ SoundName = ")Lightsaber\\Saber_Swing1.wav", Entity = PORTEUR })
S_VICTIME = emit({ SoundName = "lightsaber/saber_hit_laser2.wav", Entity = joueur(Vector(50, 0, 0)) })
S_LOIN = emit({ SoundName = "lightsaber/saber_hit.wav", Entity = AUTRE })
S_POUVOIR = emit({ SoundName = "lightsaber/force_leap.wav", Entity = PORTEUR })
S_AUTRE = emit({ SoundName = "physics/body/body_medium_impact_hard1.wav", Entity = PORTEUR })
CreateSound(PORTEUR.w, "lightsaber/saber_loop3.wav")
CreateSound(AUTRE, "lightsaber/saber_loop3.wav")
sound.Play("lightsaber/saber_hit.wav", Vector(30, 0, 0))
sound.Play("lightsaber/saber_hit.wav", Vector(3000, 0, 0))
util.Decal("FadingScorch", Vector(40, 0, 0), Vector(40, 0, 0))
util.Decal("FadingScorch", Vector(3000, 0, 0), Vector(3000, 0, 0))
util.Decal("Blood", Vector(40, 0, 0), Vector(40, 0, 0))
local function ed(p) return { GetOrigin = function() return p end } end
util.Effect("StunstickImpact", ed(Vector(40, 0, 0)))
util.Effect("BloodImpact", ed(Vector(40, 0, 0)))
util.Effect("StunstickImpact", ed(Vector(3000, 0, 0)))
IMPACTS = 0
rb655_DrawHit_wos = function() IMPACTS = IMPACTS + 1 end
WOS_ALCS = { TRACE = { INTERP = 3, MINIMALINTERP = 4 } }
wOS.ALCS.Config = { LightsaberTrace = 3 }
CLIENT = true
HOOKS["InitPostEntity/origine_armes_epee"]()
CLIENT = false
rb655_DrawHit_wos(Vector(20, 0, 0), Vector(1, 0, 0))
rb655_DrawHit_wos(Vector(3000, 0, 0), Vector(1, 0, 0))
HOOKS["InitPostEntity/origine_armes_epee"]()
rb655_DrawHit_wos(Vector(3000, 0, 0), Vector(1, 0, 0))

-- Dégâts
local degats = HOOKS["EntityTakeDamage/origine_armes_contact"]
local function dmg(att, infl) return { GetAttacker = function() return att end, GetInflictor = function() return infl end } end
local cible = joueur(Vector(30, 0, 0))
TEMPS = 1000
PORTEUR.OrigineDernierPouvoir = nil
D_IMMOBILE = degats(cible, dmg(PORTEUR, PORTEUR.w))
D_IMMOBILE_J = degats(cible, dmg(PORTEUR, PORTEUR))
PORTEUR.touches[IN_ATTACK] = true
D_CLIC_TENU = degats(cible, dmg(PORTEUR, PORTEUR.w))
PORTEUR.touches[IN_ATTACK] = nil
HOOKS["KeyPress/origine_armes_coup"](PORTEUR, IN_ATTACK)
TEMPS = TEMPS + 0.5
D_APRES_CLIC = degats(cible, dmg(PORTEUR, PORTEUR.w))
TEMPS = TEMPS + 1
D_TROP_TARD = degats(cible, dmg(PORTEUR, PORTEUR.w))
PORTEUR.w.GetAttackDelay = function() return TEMPS + 2 end
D_SPECIALE = degats(cible, dmg(PORTEUR, PORTEUR.w))
PORTEUR.w.GetAttackDelay = nil
PORTEUR.OrigineDernierPouvoir = TEMPS
D_POUVOIR = degats(cible, dmg(PORTEUR, PORTEUR))
PORTEUR.OrigineDernierPouvoir = nil
D_OBJET = degats(cible, dmg(PORTEUR, { GetClass = function() return "prop_physics" end }))
D_SANS_ARME = degats(cible, dmg(AUTRE, AUTRE))
""")
verifier("son de sabre de l'arme : coupé", G.S_ARME is False)
verifier("son de sabre (préfixes moteur, majuscules, \\) : coupé", G.S_PREFIXE is False)
verifier("son d'impact joué sur la victime à côté : coupé", G.S_VICTIME is False)
verifier("son de sabre loin de toute arme Origine : gardé", G.S_LOIN is None)
verifier("son du saut de Force : gardé", G.S_POUVOIR is None)
verifier("autre son : gardé", G.S_AUTRE is None)
verifier("CreateSound de sabre de l'arme : remplacé par du silence", liste(G.SONS_CREES) == ["common/null.wav", "lightsaber/saber_loop3.wav"], liste(G.SONS_CREES))
verifier("sound.Play de sabre près d'une arme : coupé, loin : gardé", liste(G.SONS_JOUES) == ["lightsaber/saber_hit.wav"])
verifier("brûlure au mur près de l'arme : retirée (sang gardé)", liste(G.DECALS) == ["FadingScorch", "Blood"], liste(G.DECALS))
verifier("étincelles près de l'arme : retirées (sang gardé)", liste(G.EFFETS) == ["BloodImpact", "StunstickImpact"], liste(G.EFFETS))
verifier("impact wOS (client) : retiré près de l'arme, gardé ailleurs, remplacé une seule fois", G.IMPACTS == 2, G.IMPACTS)
verifier("trace wOS réglée sur MINIMALINTERP", G.wOS.ALCS.Config.LightsaberTrace == 4)
verifier("lame immobile qui touche : aucun dégât", G.D_IMMOBILE is True and G.D_IMMOBILE_J is True)
verifier("clic tenu : dégâts", G.D_CLIC_TENU is None)
verifier("0,5 s après un clic : dégâts", G.D_APRES_CLIC is None)
verifier("1,5 s après un clic : aucun dégât", G.D_TROP_TARD is True)
verifier("attaque spéciale wOS en cours : dégâts", G.D_SPECIALE is None)
verifier("pouvoir utilisé à l'instant : dégâts gardés", G.D_POUVOIR is None)
verifier("dégâts d'autre chose (objet) : non touchés", G.D_OBJET is None)
verifier("joueur sans arme Origine : non touché", G.D_SANS_ARME is None)

# --- Axe de la lame d'après la boîte du modèle (sh_modele.lua) ---
lua.execute(r"""
local function ax(a, b) local r = ORIGINE.Armes.AxeDuModele(a, b) return { r.axe, r.signe, r.longueur, r.pommeau } end
AX1 = ax(Vector(-1, -2, -8), Vector(1, 2, 40))    -- lame vers +Z, pommeau à -8
AX2 = ax(Vector(-45, -1, -3), Vector(6, 1, 3))    -- lame vers -X, pommeau à 6
AX3 = ax(Vector(-2, -10, -1), Vector(2, 50, 1))   -- lame vers +Y
""")
verifier("axe de lame : +Z", liste(G.AX1) == [3, 1, 48, -8], liste(G.AX1))
verifier("axe de lame : -X", liste(G.AX2) == [1, -1, 51, 6], liste(G.AX2))
verifier("axe de lame : +Y", liste(G.AX3) == [2, 1, 60, -10], liste(G.AX3))

print(f"\n{total - echecs}/{total} tests réussis")
sys.exit(1 if echecs else 0)
