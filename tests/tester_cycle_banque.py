"""Tests hors jeu du cycle jour/nuit et des règles de la banque (LuaJIT via lupa).

Couvre :
  - 15 minutes de jour puis 45 minutes de nuit, heure RP 6 h -> 18 h -> 6 h ;
  - aube / crépuscule de 2 minutes, luminosité progressive ;
  - heure RP réglée par le staff -> bonne position dans le cycle ;
  - reprise au même endroit (position figée en pause) ;
  - banque : frais (dépôt 0 %, retrait 2 %, virement 2 %), montants entiers positifs, total d'un prêt ;
  - banque : virement entre deux personnages du même joueur refusé.

Usage : python3 tests/tester_cycle_banque.py
"""
import pathlib
import sys

from lupa import luajit21 as lupa

racine = pathlib.Path(__file__).resolve().parent.parent / "addons"
lua = lupa.LuaRuntime()
lua.execute(r"""
Color = function(r, g, b, a) return { r = r, g = g, b = b, a = a or 255 } end
Vector = function(x, y, z) return { x = x, y = y, z = z } end
IsValid = function(v) return v ~= nil and v ~= false end
isstring = function(v) return type(v) == "string" end
string.Trim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
SERVER, CLIENT = true, false
TEMPS = 1000
CurTime = function() return TEMPS end
HOOKS = {}
hook = { Add = function() end, Run = function(nom, ...) HOOKS[#HOOKS + 1] = nom end }
ORIGINE = { DansListe = function(l, v) for _, x in ipairs(l or {}) do if x == v then return true end end return false end,
	CommandeJob = function(t) return t end }
""")


def charger(chemin):
    lua.execute((racine / chemin).read_text(encoding="utf-8"))


charger("origine_cycle/lua/origine_cycle/sh_config.lua")
charger("origine_cycle/lua/origine_cycle/sh_cycle.lua")
charger("origine_banque/lua/origine_banque/sh_config.lua")
charger("origine_banque/lua/origine_banque/sh_banque.lua")

G = lua.globals()
E = G.ORIGINE.Cycle
B = G.ORIGINE.Banque
echecs = total = 0


def verifier(nom, ok, detail=""):
    global echecs, total
    total += 1
    if ok:
        print(f"ok     {nom}")
    else:
        echecs += 1
        print(f"ÉCHEC  {nom} {detail}")


heure = lua.eval("function(p) local m = ORIGINE.Cycle.MinutesA(p) return math.floor(m / 60), m % 60 end")

# --- Cycle -------------------------------------------------------------------
verifier("cycle complet = 1 h", E.Duree() == 3600, E.Duree())
verifier("début : aube, 6 h", E.PhaseA(0) == "aube" and heure(0) == (6, 0), heure(0))
verifier("2 min : jour", E.PhaseA(120) == "jour")
verifier("7 min 30 : midi", heure(450) == (12, 0), heure(450))
verifier("15 min : crépuscule, 18 h", E.PhaseA(900) == "crepuscule" and heure(900) == (18, 0), heure(900))
verifier("17 min : nuit", E.PhaseA(1020) == "nuit")
verifier("37 min 30 : minuit", heure(900 + 1350) == (0, 0), heure(2250))
verifier("fin du cycle : 5 h 59", heure(3599) == (5, 59), heure(3599))
verifier("jour = 15 min exactement", E.PhaseA(899) == "jour" and E.PhaseA(900) == "crepuscule")
verifier("nuit = 45 min exactement", E.PhaseA(3599) == "nuit" and E.PhaseA(0) == "aube")
verifier("luminosité : aube progressive", abs(E.LuminositeA(60) - 0.5) < 1e-9)
verifier("luminosité : jour 1, nuit 0", E.LuminositeA(600) == 1 and E.LuminositeA(2000) == 0)
verifier("luminosité : crépuscule progressif", abs(E.LuminositeA(960) - 0.5) < 1e-9)

pos = E.PositionPourHeure(23, 40)
verifier("!cycle heure 23:40 -> 23:40", heure(pos) == (23, 40), heure(pos))
pos = E.PositionPourHeure(9, 15)
verifier("!cycle heure 9:15 -> 9:15", heure(pos) == (9, 15), heure(pos))

lua.execute("ORIGINE.Cycle.Fixer(1000) ORIGINE.Cycle.pause = false TEMPS = TEMPS + 600")
verifier("le temps avance", abs(E.Position() - 1600) < 1e-6, E.Position())
lua.execute("ORIGINE.Cycle.position, ORIGINE.Cycle.pause = ORIGINE.Cycle.Position(), true TEMPS = TEMPS + 900")
verifier("pause : position figée", abs(E.Position() - 1600) < 1e-6, E.Position())
lua.execute("ORIGINE.Cycle.pause = false ORIGINE.Cycle.reference = TEMPS TEMPS = TEMPS + 60")
verifier("reprise au même endroit", abs(E.Position() - 1660) < 1e-6, E.Position())
verifier("EstNuit() pendant la nuit", G.ORIGINE.EstNuit())
lua.execute("ORIGINE.Cycle.Fixer(100)")
verifier("EstNuit() faux pendant l'aube", not G.ORIGINE.EstNuit())

# --- Banque ------------------------------------------------------------------
verifier("dépôt : 0 % de frais", B.Frais("Depot", 1000) == 0)
verifier("retrait : 2 % de frais", B.Frais("Retrait", 1000) == 20, B.Frais("Retrait", 1000))
verifier("virement : 2 % arrondi à l'inférieur", B.Frais("Virement", 149) == 2, B.Frais("Virement", 149))
verifier("montant entier positif accepté", B.MontantValide(250))
verifier("montant négatif refusé", not B.MontantValide(-5))
verifier("montant nul refusé", not B.MontantValide(0))
verifier("montant décimal refusé", not B.MontantValide(10.5))
verifier("montant texte refusé", not B.MontantValide("abc"))
verifier("prêt 1000 à 10 % -> 1100", B.TotalDu(1000, 10) == 1100)

# Virement entre deux personnages du même joueur : refusé avant tout débit
src = (racine / "origine_banque/lua/origine_banque/sv_banque.lua").read_text(encoding="utf-8")
verifier("virement même joueur refusé", "if cible.sid == p.steamid64 then" in src and "propres personnages" in src)
verifier("prêt limité au trésor", "if montant > B.Tresor then" in src and "if pret.montant > B.Tresor then" in src)
verifier("opérations en une transaction", src.count("DB.Transaction(") >= 7, src.count("DB.Transaction("))

print(f"\n{total - echecs}/{total} tests réussis")
sys.exit(1 if echecs else 0)
