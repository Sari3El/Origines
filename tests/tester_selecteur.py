"""Tests du sélecteur d'armes (origine_selecteur) dans LuaJIT (lupa), avec un GMod simulé.

Couvre les tests de validation du cahier des charges :
  - une épée qui frappe toutes les 0,5 s n'affiche aucune barre ;
  - 30 s au clic gauche + 10 s au clic droit : deux barres qui se vident au bon rythme ;
  - SWEP:OrigineCooldowns pris en compte ;
  - la Sacoche est toujours la première arme du slot 1 ;
  - hud_fastswitch 1 : l'arme change sans ouvrir le sélecteur ;
  - le sélecteur ne s'ouvre pas quand le joueur est mort.

Usage : python3 tests/tester_selecteur.py
"""
import pathlib
import sys

from lupa import luajit21 as lupa

racine = pathlib.Path(__file__).resolve().parent.parent / "addons" / "origine_selecteur" / "lua"
lua = lupa.LuaRuntime()

lua.execute(r"""
Color = function(r, g, b, a) return { r = r, g = g, b = b, a = a or 255 } end
IsValid = function(v) return v ~= nil and v ~= false and (type(v) ~= "table" or not v.supprime) end
istable = function(v) return type(v) == "table" end
math.Clamp = function(v, a, b) return math.min(math.max(v, a), b) end
math.Round = function(v) return math.floor(v + 0.5) end
table.HasValue = function(t, v) for _, x in pairs(t) do if x == v then return true end end return false end
SERVER, CLIENT = false, true
TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, TEXT_ALIGN_RIGHT = 0, 1, 2
CHAN_STATIC, IN_ATTACK = 6, 1

TEMPS = 100
CurTime = function() return TEMPS end
RealTime = function() return TEMPS end
ScrW = function() return 1920 end
ScrH = function() return 1080 end

HOOKS = {}
hook = { Add = function(ev, id, fn) HOOKS[ev .. "/" .. id] = fn end }
surface = setmetatable({ GetTextureID = function(n) return n end, GetTextSize = function(t) return #t * 8, 16 end },
	{ __index = function() return function() end end })
draw = { SimpleText = function() end }
language = { GetPhrase = function(s) return s end }
vgui = { CursorVisible = function() return false end }
FASTSWITCH = false
GetConVar = function() return { GetBool = function() return FASTSWITCH end } end
EQUIPEE = nil
input = { SelectWeapon = function(w) EQUIPEE = w end }
ErrorNoHalt = print

local BASE = { DrawWeaponSelection = function() end }
weapons = { GetStored = function(c) if c == "weapon_base" then return BASE end end }

local Arme = {}
Arme.__index = Arme
function Arme:GetClass() return self.classe end
function Arme:GetSlot() return self.slot end
function Arme:GetSlotPos() return self.slotpos end
function Arme:IsScripted() return true end
function Arme:GetNextPrimaryFire() return self.np or 0 end
function Arme:GetNextSecondaryFire() return self.ns or 0 end
function Arme:GetPrintName() return self.classe end
function Arme:GetPrimaryAmmoType() return -1 end
function Arme:Clip1() return -1 end
Arme.DrawWeaponSelection = BASE.DrawWeaponSelection
Arme.WepSelectIcon = "weapons/swep"

function NouvelleArme(classe, slot, slotpos)
	return setmetatable({ classe = classe, slot = slot, slotpos = slotpos }, Arme)
end

ARMES = {}
JOUEUR = {
	vivant = true,
	GetWeapons = function() return ARMES end,
	Alive = function(s) return s.vivant end,
	InVehicle = function() return false end,
	GetActiveWeapon = function() return ARMES[1] end,
	KeyDown = function() return false end,
	EmitSound = function() end,
	GetAmmoCount = function() return 0 end,
}
LocalPlayer = function() return JOUEUR end
ORIGINE = {}
""")

lua.execute((racine / "origine_selecteur" / "sh_config.lua").read_text(encoding="utf-8"))
lua.execute((racine / "origine_selecteur" / "cl_selecteur.lua").read_text(encoding="utf-8"))

G = lua.globals()
echecs = total = 0


def verifier(nom, condition, detail=""):
    global echecs, total
    total += 1
    if condition:
        print(f"ok     {nom}")
    else:
        echecs += 1
        print(f"ÉCHEC  {nom} {detail}")


lua.execute(r"""
TICK = HOOKS["Tick/origine_selecteur_cooldowns"]
BIND = HOOKS["PlayerBindPress/origine_selecteur"]
SEL = ORIGINE.Selecteur
function Avancer(s) TEMPS = TEMPS + s TICK() end

EPEE = NouvelleArme("epee", 0, 2)
CAPA = NouvelleArme("capacite", 4, 1)
SACOCHE = NouvelleArme("origine_sacoche", 1, 1)
MAINS = NouvelleArme("origine_mains", 0, 1)
ARMES = { MAINS, EPEE, CAPA, SACOCHE }
TICK()
""")

# Épée : un coup toutes les 0,5 s pendant 5 s -> jamais de barre
lua.execute(r"""
MAX_BARRES_EPEE = 0
for _ = 1, 10 do
	EPEE.np = TEMPS + 0.5
	Avancer(0.05)
	local e = SEL.Cooldowns[EPEE].primaire
	if e and e.fin then MAX_BARRES_EPEE = MAX_BARRES_EPEE + 1 end
	Avancer(0.45)
end
""")
verifier("épée 0,5 s : aucune barre", G.MAX_BARRES_EPEE == 0, G.MAX_BARRES_EPEE)

# 30 s au clic gauche, 10 s au clic droit
lua.execute(r"""
CAPA.np = TEMPS + 30
CAPA.ns = TEMPS + 10
TICK()
P = SEL.Cooldowns[CAPA].primaire
S2 = SEL.Cooldowns[CAPA].secondaire
Avancer(5)
FRAC_P5 = (P.fin - TEMPS) / P.duree
FRAC_S5 = (S2.fin - TEMPS) / S2.duree
""")
verifier("30 s : durée mesurée au démarrage", abs(G.P.duree - 30) < 1e-6, G.P.duree)
verifier("10 s : durée mesurée au démarrage", abs(G.S2.duree - 10) < 1e-6, G.S2.duree)
verifier("après 5 s : barre gauche à 5/6", abs(G.FRAC_P5 - 25 / 30) < 1e-6, G.FRAC_P5)
verifier("après 5 s : barre droite à 1/2", abs(G.FRAC_S5 - 0.5) < 1e-6, G.FRAC_S5)
lua.execute("Avancer(6)")
verifier("après 11 s : barre droite finie, gauche encore là",
         G.SEL.Cooldowns[G.CAPA].secondaire.fin <= G.TEMPS and G.SEL.Cooldowns[G.CAPA].primaire.fin > G.TEMPS)

# SWEP:OrigineCooldowns (durée donnée par le SWEP)
lua.execute(r"""
CAPA.OrigineCooldowns = function(self) return { primaire = { fin = TEMPS + 12, duree = 20 } } end
TICK()
OC = SEL.Cooldowns[CAPA].primaire
CAPA.OrigineCooldowns = nil
""")
verifier("OrigineCooldowns : durée du SWEP utilisée", G.OC.duree == 20 and abs(G.OC.fin - G.TEMPS - 12) < 1e-6)

# Sacoche en tête du slot 1, touche 1
lua.execute(r"""
BIND(JOUEUR, "slot1", true)
PREMIERE = SEL.Arme
OUVERT_SLOT1 = SEL.Ouvert
BIND(JOUEUR, "slot1", true)
DEUXIEME = SEL.Arme
BIND(JOUEUR, "slot1", true)
TROISIEME = SEL.Arme
SEL.Fermer()
""")
verifier("slot 1 : ouvre le sélecteur", G.OUVERT_SLOT1 is True)
verifier("slot 1 : Sacoche en premier", lua.eval("PREMIERE == SACOCHE"))
verifier("slot 1 : puis Mains (SlotPos 1)", lua.eval("DEUXIEME == MAINS"))
verifier("slot 1 : puis Épée (SlotPos 2)", lua.eval("TROISIEME == EPEE"))

# Clic gauche équipe, clic droit ferme sans changer
lua.execute(r"""
EQUIPEE = nil
BIND(JOUEUR, "slot5", true)
BIND(JOUEUR, "+attack", true)
EQUIPE_CLIC = EQUIPEE
EQUIPEE = nil
BIND(JOUEUR, "slot5", true)
BIND(JOUEUR, "+attack2", true)
FERME_CLIC_DROIT = not SEL.Ouvert and EQUIPEE == nil
""")
verifier("clic gauche : équipe l'arme", lua.eval("EQUIPE_CLIC == CAPA"))
verifier("clic droit : ferme sans équiper", G.FERME_CLIC_DROIT is True)

# Lame wOS avec le choix des pouvoirs ouvert (F) : les touches 1 à 6 vont à wOS
lua.execute(r"""
SEL.Fermer()
MAINS.IsLightsaber, MAINS.ForceSelectEnabled = true, true
R_POUVOIR = BIND(JOUEUR, "slot2", true)
OUVERT_POUVOIR = SEL.Ouvert
MAINS.ForceSelectEnabled = false
R_ARME = BIND(JOUEUR, "slot2", true)
MAINS.IsLightsaber, MAINS.ForceSelectEnabled = nil, nil
SEL.Fermer()
""")
verifier("choix des pouvoirs wOS : touche laissée à wOS", G.R_POUVOIR is None and not G.OUVERT_POUVOIR)
verifier("choix des pouvoirs fermé : sélecteur normal", G.R_ARME is True)

# hud_fastswitch 1
lua.execute(r"""
FASTSWITCH = true
EQUIPEE = nil
BIND(JOUEUR, "slot1", true)
FAST_EQUIPEE, FAST_OUVERT = EQUIPEE, SEL.Ouvert
FASTSWITCH = false
""")
verifier("fastswitch : arme suivante du slot équipée directement", lua.eval("FAST_EQUIPEE == EPEE"))
verifier("fastswitch : sélecteur pas affiché", not G.FAST_OUVERT)

# Mort : ne s'ouvre pas
lua.execute(r"""
JOUEUR.vivant = false
BIND(JOUEUR, "invnext", true)
MORT_OUVERT = SEL.Ouvert
JOUEUR.vivant = true
""")
verifier("mort : pas d'ouverture", not G.MORT_OUVERT)

# Fermeture auto après 3 s
lua.execute(r"""
BIND(JOUEUR, "invnext", true)
HOOKS["HUDPaint/origine_selecteur"]()
AVANT = SEL.Ouvert
TEMPS = TEMPS + 3.5
HOOKS["HUDPaint/origine_selecteur"]()
APRES = SEL.Ouvert
""")
verifier("fermeture auto après 3 s", G.AVANT is True and not G.APRES)

print(f"\n{total - echecs}/{total} tests réussis")
sys.exit(1 if echecs else 0)
