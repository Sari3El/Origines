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
""")
lua.execute((racine / "origine_armes" / "sh_armes.lua").read_text(encoding="utf-8"))


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
    verifier(f"{cle} : sons vides + son d'épée", s.UseLoopSound == s.UseOnSound == s.UseOffSound == "origine_armes/silence.wav"
             and s.UseSwingSound == "origine_armes/epee_swing.wav")
    verifier(f"{cle} : lumière de lame éteinte (noir)", s.UseColor.r == 0 and s.UseColor.g == 0 and s.UseColor.b == 0)
    verifier(f"{cle} : base wOS", s.Base == "wos_adv_single_lightsaber_base")
    verifier(f"{cle} : pas d'icône de sabre dans le sélecteur", s.OrigineSansIcone is True)
    verifier(f"{cle} : rangeable dans l'inventaire", G.ORIGINE.Inv.Autorisees[f"weapon_origine_{cle}"] is True)

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
INSTANCE:Initialize()
""")
inst = G.INSTANCE
p = liste(inst.ForcePowerList)
verifier("mage sans packs : 20 pouvoirs de base + pouvoir ajouté", len(p) == 21 and p[-1] == "Pouvoir Maison", p)
verifier("mage sans packs : aucun pouvoir de pack", "Burn Out" not in p and "Force Choke" not in p)
verifier("mage : ordre wOS respecté (Force Leap en premier)", p[0] == "Force Leap")
verifier("mage : Initialize de la base wOS appelé", inst.InitBase is True)
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

print(f"\n{total - echecs}/{total} tests réussis")
sys.exit(1 if echecs else 0)
