"""Exécute darkrpmodification/.../jobs.lua avec un faux DarkRP et vérifie la liste des jobs.

Usage : python3 tests/tester_jobs.py
"""
import pathlib
import sys

from lupa import luajit21 as lupa

racine = pathlib.Path(__file__).resolve().parent.parent
lua = lupa.LuaRuntime()
lua.execute(r'''
Color = function(r, g, b, a) return { r = r, g = g, b = b, a = a or 255 } end
string.Replace = function(s, a, b) return (s:gsub(a:gsub("%p", "%%%0"), (b:gsub("%%", "%%%%")))) end
GAMEMODE = { Config = {} }
JOBS, CATS = {}, {}
local n = 0
DarkRP = {
	createCategory = function(t) CATS[t.name] = true end,
	createJob = function(nom, t) n = n + 1 t.nom = nom JOBS[#JOBS + 1] = t return n end,
	createGroupChat = function() end,
}
''')
lua.execute((racine / "darkrpmodification/lua/darkrp_customthings/jobs.lua").read_text(encoding="utf-8"))
G = lua.globals()
jobs = [G.JOBS[i] for i in range(1, len(G.JOBS) + 1)]
erreurs = []
commandes = [j.command for j in jobs]
if len(set(commandes)) != len(commandes):
    erreurs.append("commandes en double")
for j in jobs:
    if not G.CATS[j.category]:
        erreurs.append(f"catégorie inconnue pour {j.nom}")
    if list(j.weapons.values()) != ["origine_mains", "origine_sacoche"]:
        erreurs.append(f"armes inattendues pour {j.nom}")
    if not j.command.replace("_", "").isalnum():
        erreurs.append(f"commande invalide : {j.command}")
if not G.GAMEMODE.DefaultTeam:
    erreurs.append("pas de job par défaut")
print(f"{len(jobs)} jobs, {len(erreurs)} erreur(s)")
for e in erreurs:
    print("ERREUR", e)
sys.exit(1 if erreurs else 0)
