"""Liste les variables globales lues dans les addons qui ne sont ni des API GMod/DarkRP
connues, ni définies par les addons. Sert à repérer les fautes de frappe.

Usage : python3 tests/verifier_globales.py
"""
import pathlib
import sys

from luaparser import ast, astnodes

racine = pathlib.Path(__file__).resolve().parent.parent
# Addons + modules DarkRP (menu TAB)
DOSSIERS = [racine / "addons", racine / "darkrpmodification" / "lua" / "darkrp_modules"]

# API globales de Garry's Mod / DarkRP / ULib utilisées par les addons
CONNUES = set("""
_G ORIGINE ORIGINE_INV SWEP ENT GAMEMODE GM DarkRP RPExtraTeams DarkRPEntities MySQLite ULib mysqloo
SERVER CLIENT
print pairs ipairs next type tostring tonumber select unpack pcall error setmetatable getmetatable
rawget rawset require include AddCSLuaFile Msg MsgC ErrorNoHalt IsValid IsEntity IsColor
isstring isnumber istable isbool isentity isfunction SortedPairs Color Vector Angle Matrix Material
Lerp CurTime FrameTime ScrW ScrH LocalPlayer DamageInfo ParticleEmitter VectorRand SafeRemoveEntity
DermaMenu FindMetaTable IsFirstTimePredicted
string table math os util net hook timer sql file player team ents game weapons scripted_ents list
language surface draw render cam vgui chat concommand resource jit utf8 bit
color_white
TEXT_ALIGN_LEFT TEXT_ALIGN_CENTER TEXT_ALIGN_RIGHT TEXT_ALIGN_TOP TEXT_ALIGN_BOTTOM TEXFILTER
TOP BOTTOM LEFT RIGHT FILL
COLLISION_GROUP_IN_VEHICLE COLLISION_GROUP_PLAYER COLLISION_GROUP_WEAPON
SOLID_VPHYSICS MOVETYPE_VPHYSICS SIMPLE_USE MASK_SHOT MASK_VISIBLE
DMG_BURN DMG_DROWN GetGlobalBool SetGlobalBool CONTINUOUS_USE IN_USE NULL STENCIL_ALWAYS STENCIL_REPLACE STENCIL_KEEP STENCIL_EQUAL DMG_BLAST DMG_BUCKSHOT DMG_BULLET DMG_CLUB DMG_CRUSH DMG_FALL DMG_POISON DMG_SHOCK DMG_SLASH DMG_VEHICLE Player gameevent IN_JUMP IN_DUCK TEAM_UNASSIGNED TEAM_CONNECTING TEAM_SPECTATOR
RunConsoleCommand cookie gui input SetClipboardText MOUSE_RIGHT KEY_ENTER KEY_PAD_ENTER KEY_UP KEY_DOWN KEY_TAB KEY_ESCAPE
CloseDermaMenus Derma_StringRequest GetConVar RealTime CHAN_STATIC IN_ATTACK
MATERIAL_FOG_LINEAR StormFox2 LerpVector engine DrawColorModify DMG_SLOWBURN ACT_HL2MP_ZOMBIE_SLUMP_IDLE
IN_ATTACK2 IN_RELOAD IN_SPEED ulx KEY_F6 KEY_F7 HTTP
RENDERGROUP_BOTH killicon baseclass wOS WOS_ALCS sound rb655_DrawHit_wos
""".split())


# Seules globales que les addons ont le droit de créer ou modifier
ECRITURES_AUTORISEES = {"ORIGINE", "ORIGINE_INV", "rb655_DrawHit_wos"}  # rb655_DrawHit_wos : impact wOS remplacé par origine_armes


class Portee:
    def __init__(self, parent=None):
        self.noms = set()
        self.parent = parent

    def contient(self, nom):
        p = self
        while p:
            if nom in p.noms:
                return True
            p = p.parent
        return False


def noms_cibles(cibles):
    for c in cibles:
        if isinstance(c, astnodes.Name):
            yield c.id


class Analyse:
    def __init__(self, fichier):
        self.fichier = fichier
        self.inconnues = {}
        self.definies = set()

    def lire(self, nom, noeud, portee):
        if not portee.contient(nom) and nom not in CONNUES:
            self.inconnues.setdefault(nom, getattr(noeud, "line", None) or "?")

    def bloc(self, instructions, portee):
        for n in instructions:
            self.noeud(n, portee)

    def fonction(self, n, portee):
        p = Portee(portee)
        for a in n.args:
            if isinstance(a, astnodes.Name):
                p.noms.add(a.id)
        if isinstance(n, astnodes.Method):
            p.noms.add("self")
        self.bloc(n.body.body, p)

    def noeud(self, n, portee):
        if n is None:
            return
        if isinstance(n, list):
            for x in n:
                self.noeud(x, portee)
            return
        if isinstance(n, astnodes.LocalAssign):
            for v in n.values or []:
                self.noeud(v, portee)
            portee.noms.update(noms_cibles(n.targets))
            return
        if isinstance(n, astnodes.LocalFunction):
            portee.noms.add(n.name.id)
            self.fonction(n, portee)
            return
        if isinstance(n, astnodes.Function):
            if isinstance(n.name, astnodes.Name):
                self.definies.add(n.name.id)
                if not portee.contient(n.name.id):
                    portee_racine = portee
                    while portee_racine.parent:
                        portee_racine = portee_racine.parent
            else:
                self.noeud(n.name, portee)
            self.fonction(n, portee)
            return
        if isinstance(n, astnodes.Method):
            self.noeud(n.source, portee)
            self.fonction(n, portee)
            return
        if isinstance(n, astnodes.AnonymousFunction):
            self.fonction(n, portee)
            return
        if isinstance(n, astnodes.Assign):
            for v in n.values:
                self.noeud(v, portee)
            for t in n.targets:
                if isinstance(t, astnodes.Name):
                    if not portee.contient(t.id):
                        self.definies.add(t.id)
                        if t.id not in ECRITURES_AUTORISEES:
                            self.inconnues.setdefault("(écriture globale) " + t.id, getattr(t, "line", None) or "?")
                else:
                    self.noeud(t, portee)
            return
        if isinstance(n, astnodes.Fornum):
            self.noeud(n.start, portee)
            self.noeud(n.stop, portee)
            self.noeud(n.step, portee)
            p = Portee(portee)
            p.noms.add(n.target.id)
            self.bloc(n.body.body, p)
            return
        if isinstance(n, astnodes.Forin):
            self.noeud(n.iter, portee)
            p = Portee(portee)
            p.noms.update(noms_cibles(n.targets))
            self.bloc(n.body.body, p)
            return
        if isinstance(n, astnodes.Block):
            self.bloc(n.body, Portee(portee))
            return
        if isinstance(n, (astnodes.While, astnodes.Repeat)):
            self.noeud(n.test, portee)
            self.bloc(n.body.body, Portee(portee))
            return
        if isinstance(n, astnodes.If) or isinstance(n, astnodes.ElseIf):
            self.noeud(n.test, portee)
            self.bloc(n.body.body, Portee(portee))
            if n.orelse is not None:
                if isinstance(n.orelse, (astnodes.If, astnodes.ElseIf)):
                    self.noeud(n.orelse, portee)
                else:
                    self.bloc(n.orelse.body, Portee(portee))
            return
        if isinstance(n, astnodes.Do):
            self.bloc(n.body.body, Portee(portee))
            return
        if isinstance(n, astnodes.Name):
            self.lire(n.id, n, portee)
            return
        if isinstance(n, astnodes.Index):
            self.noeud(n.value, portee)
            if n.notation == astnodes.IndexNotation.SQUARE:
                self.noeud(n.idx, portee)
            return
        if isinstance(n, astnodes.Invoke):
            self.noeud(n.source, portee)
            self.noeud(n.args, portee)
            return
        if isinstance(n, astnodes.Call):
            self.noeud(n.func, portee)
            self.noeud(n.args, portee)
            return
        if isinstance(n, astnodes.Table):
            for champ in n.fields:
                if isinstance(champ.key, astnodes.Name) and not champ.between_brackets:
                    pass
                else:
                    self.noeud(champ.key, portee)
                self.noeud(champ.value, portee)
            return
        if isinstance(n, astnodes.Return):
            self.noeud(n.values, portee)
            return
        # Expressions génériques : on parcourt les attributs
        for attr in ("left", "right", "operand", "value", "values", "args", "test"):
            if hasattr(n, attr):
                self.noeud(getattr(n, attr), portee)


definies_globales = set()
resultats = []
for f in sorted(f for d in DOSSIERS for f in d.rglob("*.lua")):
    arbre = ast.parse(f.read_text(encoding="utf-8"))
    a = Analyse(f)
    a.bloc(arbre.body.body, Portee())
    definies_globales |= a.definies
    resultats.append(a)

problemes = 0
for a in resultats:
    for nom, ligne in sorted(a.inconnues.items()):
        if nom in definies_globales and not nom.startswith("(écriture"):
            continue
        problemes += 1
        print(f"GLOBALE INCONNUE {nom}  ({a.fichier.relative_to(racine)}:{ligne})")
print(f"{len(resultats)} fichiers, {problemes} globale(s) inconnue(s)")
sys.exit(1 if problemes else 0)
