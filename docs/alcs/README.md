# Base de connaissances — wiltOS Advanced Lightsaber Combat System (ALCS)

Copie de travail de toutes les fiches de la base de connaissances officielle
(https://support.wiltostech.com/knowledgebase/15/Advanced-Lightsaber-Combat-System),
relevées le 30/09/2026, pour préparer les modifications de l'ALCS sur Origine du monde.
Le texte d'origine est en anglais ; les blocs de code sont reproduits tels quels.

Attention : l'éditeur signale un wiki plus à jour : https://wiki.wiltostech.com/3/ALCS
Ces fiches peuvent donc être plus anciennes que la version de l'addon installée sur le serveur :
en cas de doute, c'est le code de l'addon (lua/wos/advswl/…) qui fait foi.

| Fichier | Contenu |
|---|---|
| `01_general.md` | Contrôles, pouvoirs de Force, installation et configuration, création de sabres et de formes, DRM, packs, contenu requis, pub du chat |
| `02_hooks.md` | Liste complète des hooks (arguments, retours) |
| `03_administration.md` | Commandes console, permissions, fonctions pour donner des objets / de l'XP |
| `04_crafting.md` | Objets, inventaire, MySQL, cristaux, types de lame |
| `05_lightsabers.md` | Réglages des armes-sabres : pouvoirs, formes, dégâts, endurance, traçage des coups… |
| `06_dueling.md` | Esprits de duel et artefacts |
| `07_skills.md` | Arbres de compétences, niveaux, XP |
| `08_errors.md` | Erreurs connues et solutions |
| `09_dll.md` | Dépendances Windows des DLL |

## Version installée sur le serveur

Les fichiers de l'addon envoyés au début du projet (Sentinel, 359 fichiers Lua) sont plus récents que la base
de connaissances : ils contiennent aussi des systèmes que les fiches ne décrivent pas (prestige, exécutions,
échanges, stockage, grips, datadesc). Pour ces parties, il faudra lire directement le code de
`lua/wos/advswl/` avant de modifier quoi que ce soit.

Fiches relevées : 62 (63 annoncées sur le site, « Setting Blade Type » apparaît dans deux catégories).
