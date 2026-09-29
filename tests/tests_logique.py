"""Tests de la logique pure des addons Origine, exécutés dans LuaJIT (lupa).

Couvre : format des Covan, validation et normalisation des noms, taux de
tirage recalculés depuis les poids, tirage pondéré, piles et capacité de
l'inventaire.

Usage : python3 tests/tests_logique.py
"""
import pathlib
import sys

from lupa import luajit21 as lupa

racine = pathlib.Path(__file__).resolve().parent.parent / "addons"
lua = lupa.LuaRuntime()

# Environnement minimal de Garry's Mod
lua.execute(r"""
Color = function(r, g, b, a) return { r = r, g = g, b = b, a = a or 255 } end
IsValid = function(v) return v ~= nil and v ~= false end
isstring = function(v) return type(v) == "string" end
string.Trim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
SERVER, CLIENT = true, false
""")

def charger(chemin):
    code = (racine / chemin).read_text(encoding="utf-8")
    lua.execute(code)

charger("origine_personnages/lua/origine_personnages/sh_config.lua")
charger("origine_personnages/lua/origine_personnages/sh_util.lua")
charger("origine_inventaire/lua/origine_inventaire/sh_config.lua")
charger("origine_inventaire/lua/origine_inventaire/sh_inventaire.lua")

G = lua.globals()
O = G.ORIGINE
echecs = 0
total = 0

def verifier(nom, condition, detail=""):
    global echecs, total
    total += 1
    if not condition:
        echecs += 1
        print(f"ÉCHEC  {nom} {detail}")
    else:
        print(f"ok     {nom}")

# --- Covan ---------------------------------------------------------------
verifier("12 500 Covan", O.FormaterCovan(12500) == "12 500 Covan", O.FormaterCovan(12500))
verifier("1 234 567", O.FormaterNombre(1234567) == "1 234 567", O.FormaterNombre(1234567))
verifier("999", O.FormaterNombre(999) == "999")
verifier("100 000", O.FormaterNombre(100000) == "100 000", O.FormaterNombre(100000))
verifier("0", O.FormaterNombre(0) == "0")
verifier("-2 500", O.FormaterNombre(-2500) == "-2 500", O.FormaterNombre(-2500))

# --- Noms ----------------------------------------------------------------
def valide(p, n):
    return lua.eval("function(p, n) return (ORIGINE.ValiderNom(p, n)) end")(p, n)

verifier("Jean-Luc D'Arc accepté", valide("Jean-Luc", "D'Arc"))
verifier("accents acceptés", valide("Hélène", "Müller"))
verifier("Œ accepté", valide("Chloé", "Cœur"))
verifier("1 caractère refusé", not valide("É", "Dupont"))
verifier("chiffres refusés", not valide("Jean2", "Dupont"))
verifier("espace refusé", not valide("Jean Paul", "Dupont"))
verifier("16 caractères acceptés", valide("A" * 16, "Dupont"))
verifier("17 caractères refusés", not valide("A" * 17, "Dupont"))
verifier("16 caractères accentués acceptés", valide("é" * 16, "Dupont"))
verifier("tiret au début refusé", not valide("-Jean", "Dupont"))
verifier("apostrophe à la fin refusée", not valide("Jean'", "Dupont"))
verifier("liste noire (exacte)", not valide("Hitler", "Dupont"))
verifier("liste noire (majuscules, accents)", not valide("JÉSUS", "Dupont"))
verifier("mot interdit dans le nom", not valide("Jean", "Connardson"))
verifier("Conrad accepté (pas de faux positif)", valide("Conrad", "Dupont"))
verifier("normalisation", O.Normaliser("Hélène ÉRIC") == "helene eric", O.Normaliser("Hélène ÉRIC"))
verifier("clé du nom", O.CleNom("Éric", "DUPONT") == "eric dupont")
verifier("capitalisation", O.Capitaliser("élise") == "Élise", O.Capitaliser("élise"))

# --- Taux ----------------------------------------------------------------
taux = O.Taux()
def approx(a, b): return abs(a - b) < 1e-6
somme = sum(taux.races[k] for k in taux.races)
verifier("somme des taux = 100 %", approx(somme, 100), str(somme))
verifier("Sans lignée 27 %", approx(taux.raretes["sans_lignee"], 27))
verifier("Lignée commune 45 %", approx(taux.raretes["commune"], 45))
verifier("Lignée ancienne 20 %", approx(taux.raretes["ancienne"], 20))
verifier("Lignée illustre 7 %", approx(taux.raretes["illustre"], 7))
verifier("Lignée légendaire 0,8 %", approx(taux.raretes["legendaire"], 0.8))
verifier("Lignée primordiale 0,2 %", approx(taux.raretes["primordiale"], 0.2))
verifier("Gardien 9 %", approx(taux.races["gardien"], 9))
verifier("Ombre 4 %", approx(taux.races["ombre"], 4))
verifier("Céleste 3,5 %", approx(taux.races["celeste"], 3.5))
verifier("format 3,5 %", O.FormaterTaux(3.5) == "3,5 %", O.FormaterTaux(3.5))
verifier("format 27 %", O.FormaterTaux(27) == "27 %")

# Des poids dont le total n'est pas 100 ne cassent rien
lua.execute("for _, r in ipairs(ORIGINE.Config.Races) do r.Poids = r.Poids * 3 end")
taux3 = O.Taux()
verifier("poids ×3 : mêmes taux", approx(taux3.races["gardien"], 9) and approx(taux3.raretes["commune"], 45))
lua.execute("for _, r in ipairs(ORIGINE.Config.Races) do r.Poids = r.Poids / 3 end")

# --- Tirage --------------------------------------------------------------
tirer = lua.eval("function(x) return ORIGINE.TirerRace(function() return x end) end")
verifier("tirage 0 -> Être Vivant", tirer(0) == "etre_vivant")
verifier("tirage 0,2699 -> Être Vivant", tirer(0.2699) == "etre_vivant")
verifier("tirage 0,27 -> Gardien", tirer(0.27) == "gardien")
verifier("tirage 0,9999 -> Sang Arcanique", tirer(0.9999) == "sang_arcanique", tirer(0.9999))
comptes = lua.eval("""function(n)
	math.randomseed(42)
	local c = {}
	for _ = 1, n do local id = ORIGINE.TirerRace() c[id] = (c[id] or 0) + 1 end
	return c
end""")(400000)
freq_ev = comptes["etre_vivant"] / 400000 * 100
freq_ga = comptes["gardien"] / 400000 * 100
verifier("fréquence Être Vivant ≈ 27 %", abs(freq_ev - 27) < 0.5, f"{freq_ev:.2f} %")
verifier("fréquence Gardien ≈ 9 %", abs(freq_ga - 9) < 0.3, f"{freq_ga:.2f} %")

# --- Inventaire ----------------------------------------------------------
res = lua.eval("""function()
	local I = ORIGINE.Inv
	local cases = {}
	local pomme = { classe = "pomme", modele = "models/pomme.mdl" }
	local ok = 0
	for _ = 1, 7 do if I.AjouterDans(cases, pomme, 20) then ok = ok + 1 end end
	return #cases, cases[1].n, cases[2].n, cases[3].n, ok
end""")()
verifier("7 objets identiques -> piles 3/3/1", tuple(res) == (3, 3, 3, 1, 7), str(tuple(res)))

res = lua.eval("""function()
	local I = ORIGINE.Inv
	local cases = {}
	for i = 1, 2 do I.AjouterDans(cases, { classe = "obj" .. i }, 2) end
	local plein = I.AjouterDans(cases, { classe = "obj3" }, 2)
	local pile = I.AjouterDans(cases, { classe = "obj1" }, 2)
	return plein, pile, #cases, cases[1].n
end""")()
verifier("inventaire plein : nouvelle case refusée", res[0] is False)
verifier("inventaire plein : pile existante acceptée", res[1] is True and res[3] == 2)

res = lua.eval("""function()
	local I = ORIGINE.Inv
	local cases = {}
	for i = 1, 3 do I.AjouterDans(cases, { classe = "obj" .. i }, 30) end
	-- VIP expiré : capacité 2 alors qu'il a 3 cases
	return I.AjouterDans(cases, { classe = "obj1" }, 2), I.AjouterDans(cases, { classe = "neuf" }, 2), #cases
end""")()
verifier("au-delà de la capacité (VIP expiré) : plus rien ne se range", res[0] is False and res[1] is False and res[2] == 3)

res = lua.eval("""function()
	local I = ORIGINE.Inv
	local cases = {}
	for _ = 1, 2 do I.AjouterDans(cases, { classe = "a", modele = "m" }, 20) end
	local o1 = I.RetirerDe(cases, 1)
	local n1 = cases[1].n
	local o2 = I.RetirerDe(cases, 1)
	return o1.classe, n1, o2.classe, #cases, I.RetirerDe(cases, 1) == nil
end""")()
verifier("retrait : pile décrémentée puis case supprimée", tuple(res) == ("a", 1, "a", 0, True), str(tuple(res)))

# Tout transférer vers un inventaire presque plein : le surplus reste dehors, rien n'est dupliqué
res = lua.eval("""function()
	local I = ORIGINE.Inv
	local inv = {}
	for i = 1, 19 do I.AjouterDans(inv, { classe = "x" .. i }, 20) end
	local sac = { { classe = "a", n = 3 }, { classe = "b", n = 2 } }
	local auSol = 0
	for _, c in ipairs(sac) do
		for _ = 1, c.n do
			if not I.AjouterDans(inv, I.Copier(c), 20) then auSol = auSol + 1 end
		end
	end
	return #inv, auSol, I.Compter(inv)
end""")()
verifier("tout transférer (inventaire presque plein)", tuple(res) == (20, 2, 22), str(tuple(res)))

print(f"\n{total - echecs}/{total} tests réussis")
sys.exit(1 if echecs else 0)
