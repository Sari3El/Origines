"""Vérifie que chaque fonction ORIGINE.* (ou alias local) appelée est définie quelque part."""
import pathlib, re, sys
racine = pathlib.Path(__file__).resolve().parent.parent / "addons"
fichiers = sorted(racine.rglob("*.lua"))
alias_re = re.compile(r"^local\s+(\w+)\s*=\s*(ORIGINE(?:\.\w+)*)\s*$", re.M)
defs, usages = set(), []
for f in fichiers:
    src = f.read_text(encoding="utf-8")
    alias = {"ORIGINE": "ORIGINE"}
    for a, cible in alias_re.findall(src):
        alias[a] = cible
    def resoudre(nom):
        tete, _, reste = nom.partition(".")
        if tete in alias:
            return alias[tete] + ("." + reste if reste else "")
        return None
    for m in re.finditer(r"function\s+([\w.]+)[.:](\w+)\s*\(", src):
        r = resoudre(m.group(1))
        if r: defs.add(r + "." + m.group(2))
    for m in re.finditer(r"([\w.]+)\.(\w+)\s*=\s*(?!=)", src):
        r = resoudre(m.group(1))
        if r: defs.add(r + "." + m.group(2))
    for m in re.finditer(r"([A-Za-z_][\w.]*)\.(\w+)\s*\(", src):
        r = resoudre(m.group(1))
        if r:
            ligne = src.count("\n", 0, m.start()) + 1
            usages.append((r + "." + m.group(2), f.relative_to(racine), ligne))
manquants = [(u, f, l) for u, f, l in usages if u not in defs]
for u, f, l in manquants:
    print(f"INCONNU {u}  ({f}:{l})")
print(f"{len(usages)} appels, {len(manquants)} inconnu(s)")
sys.exit(1 if manquants else 0)
