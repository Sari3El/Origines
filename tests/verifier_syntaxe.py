"""Vérifie la syntaxe de tous les fichiers .lua des addons avec LuaJIT (via lupa).

Usage : python3 tests/verifier_syntaxe.py
"""
import pathlib
import sys

from lupa import luajit21 as lupa

racine = pathlib.Path(__file__).resolve().parent.parent / "addons"
lua = lupa.LuaRuntime()
charger = lua.eval("function(code, nom) local f, err = loadstring(code, nom) return err end")

erreurs = 0
fichiers = sorted(racine.rglob("*.lua"))
for chemin in fichiers:
    err = charger(chemin.read_text(encoding="utf-8"), "@" + str(chemin.relative_to(racine)))
    if err:
        erreurs += 1
        print("ERREUR", err)

print(f"{len(fichiers)} fichiers vérifiés, {erreurs} erreur(s)")
sys.exit(1 if erreurs else 0)
