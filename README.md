# Médiéval RP — Origine du monde

Quatre addons Garry's Mod (DarkRP + ULX/ULib) réalisés d'après le cahier des charges
« Médiéval RP : Origine du monde ».

| Dossier | Contenu | Dépend de |
|---|---|---|
| `origine_personnages` | Slots, menu et création de personnage, races, rerolls, SWEPs de race, sauvegarde SQL, intégration DarkRP | DarkRP, ULX |
| `origine_hud` | HUD sous la chatbox, compteur de munitions, infos au-dessus de la tête | origine_personnages |
| `origine_inventaire` | SWEP Sacoche, inventaire par personnage, sac de mort, liste des entités autorisées | origine_personnages |
| `origine_staff` | Menu `!origine`, actions staff, historique, copies avant CK et RPK | origine_personnages, origine_inventaire |

## Installation

1. Copier les **quatre dossiers** de `addons/` dans `garrysmod/addons/` du serveur
   (un dossier par système, ne pas les fusionner).
2. Redémarrer le serveur. La console doit afficher :
   ```
   [Origine] origine_personnages chargé.
   [Origine] Base de données prête (sqlite).
   [Origine] origine_inventaire chargé.
   [Origine] origine_hud chargé.
   [Origine] origine_staff chargé.
   ```
   Si `origine_personnages` manque, les trois autres ne se lancent pas et le signalent en console.
3. Remplir la liste des entités rangeables :
   `origine_inventaire/lua/origine_inventaire/sh_entites.lua`.

Aucun fichier de DarkRP n'est modifié : tout passe par les hooks.

## Réglages

Tous les réglages sont dans les `sh_config.lua`, commentés en français :

- `origine_personnages/lua/origine_personnages/sh_config.lua` : monnaie, groupes VIP / staff,
  délais de `!perso`, rerolls, règles et liste noire des noms, **couleurs de la charte et des raretés**,
  races (poids, modificateurs), catégories d'armes, restrictions de job par race, SWEPs de race,
  sauvegarde, SQLite / MySQL, Workshop.
- `origine_hud/lua/origine_hud/sh_config.lua` : taille, jauges, distance des infos au-dessus de la tête.
- `origine_inventaire/lua/origine_inventaire/sh_config.lua` : portée de la sacoche, capacité (20 / 30 VIP),
  taille des piles (3), durée du sac de mort (10 min).
- `origine_staff/lua/origine_staff/sh_config.lua` : permission, limites d'affichage.

### Champs optionnels dans `job.lua`

Les maximums suivent le job et la race. Un job peut préciser ses valeurs de base :

```lua
TEAM_GARDE = DarkRP.createJob("Garde", {
    -- …
    origine_pvmax = 150,      -- PV max de base (avant la race)
    origine_armuremax = 140,  -- armure max de base
    origine_marche = 160,     -- vitesse de marche de base
    origine_course = 240,     -- vitesse de course de base
})
```

Sans ces champs : `PVMaxDefaut` / `ArmureMaxDefaut` de la config (100), et les vitesses de DarkRP.

## Commandes

| Commande | Console | Qui | Effet |
|---|---|---|---|
| `!perso` | `origine_perso` | Tous | Changer de personnage (sauvegarde + nettoyage + menu) |
| `!origine` | `origine` | Permission ULX `origine_menu` | Menu staff |
| Sacoche clic gauche | | Tous | Range l'entité visée |
| Sacoche clic droit | | Tous | Ouvre l'inventaire |
| E sur un sac de mort | | Tous | Fouiller le sac |

La permission `origine_menu` est donnée aux superadmins par défaut et s'attribue à d'autres rangs
dans XGUI (onglet Groupes, catégorie « Origine »). Elle est vérifiée côté serveur à chaque action.

## Pour les autres addons

Seuls les points de reroll sont liés au compte ; tout le reste appartient au personnage.
Un addon qui sauvegarde par compte (banque, grades, whitelist…) doit sauvegarder par personnage :

```lua
ORIGINE.CleDePersonnage(ply)          -- "steamid64:slot" du personnage joué (nil dans le menu)
ORIGINE.PersoActuel(ply)              -- table du personnage joué
ORIGINE.AjouterRerolls(steamid64, n)  -- ajouter (ou retirer si n < 0) des points, joueur connecté ou non

hook.Add("origine_PersonnageCharge", "mon_addon", function(ply, perso) end)
hook.Add("origine_PersonnageDecharge", "mon_addon", function(ply, perso, options) end)
hook.Add("origine_SauvegardeGenerale", "mon_addon", function(synchrone) end)
hook.Add("origine_NettoyageMonde", "mon_addon", function(ply) end)
hook.Add("origine_ArmesExclues", "mon_addon", function(ply, set) end)
```

À prévoir sur ce serveur : les données wOS (compétences, niveaux ALCS) et l'inventaire wOS sont
enregistrés par compte. Ils ne sont pas encore séparés par personnage.

## Base de données

SQLite par défaut (`sv.db`, rien à installer). MySQL via MySQLOO : `BaseDeDonnees.Mode = "mysql"`.
Si la connexion MySQL échoue, le système repasse sur SQLite.

| Table | Contenu |
|---|---|
| `origine_comptes` | Une ligne par SteamID64 : rerolls, dernier slot, reroll gratuit donné, slot EVENT |
| `origine_personnages` | Une ligne par personnage (SteamID64 + slot) |
| `origine_inventaires` | Inventaire de chaque personnage |
| `origine_historique` | Actions staff, tirages de race et rerolls |
| `origine_copies` | Copie complète d'un personnage avant chaque CK ou RPK |

Sauvegarde au changement de personnage, à la déconnexion, toutes les 5 minutes, à l'arrêt du serveur
et à chaque modification d'inventaire (écritures regroupées). Copie complète des tables chaque jour
dans `garrysmod/data/origine/sauvegardes/`, gardée 7 jours.

Mise en place : les Covan qu'un joueur avait déjà dans DarkRP sont transférés sur son slot 1.

## Choix d'interprétation

- **`DarkRP_HUD` n'est pas masqué.** Dans DarkRP, cet élément englobe aussi l'arrestation, le couvre-feu,
  l'agenda et le chat vocal, que le cahier demande de conserver. La vie, l'argent, le salaire et le job
  (`DarkRP_LocalPlayerHUD`), la faim (`DarkRP_Hungermod`) et les infos au-dessus des joueurs
  (`DarkRP_EntityDisplay`) sont bien masqués et remplacés. Les infos des portes, qui étaient dans
  `DarkRP_EntityDisplay`, sont redessinées par `origine_hud`.
- **HUD sous la chatbox.** S'il n'y a pas assez de place sous la chatbox, le HUD est réduit ; s'il
  deviendrait trop petit, il se place à droite de la chatbox, en bas, pour ne jamais la chevaucher.
- **`sh_entites.lua`** garde le format du cahier (`ORIGINE_INV.EntitesAutorisees`). Au chargement la liste
  est recopiée dans `ORIGINE.Inv` et `ORIGINE_INV` est supprimée : il ne reste qu'une table globale, `ORIGINE`.
- **Création** : le tirage est enregistré en base avant l'animation. Un personnage tiré mais pas encore
  validé reste sur son slot (« Tirage à valider ») : se déconnecter ne relance rien.
- **Slots EVENT et Staff** : pas de tirage, le personnage est créé puis chargé directement. Le slot EVENT
  ne peut être créé qu'une fois sa race fixée par le staff.
- **CK / RPK** appliquent le tableau du cahier. Arrestation et avis de recherche sont aussi remis à zéro.
  L'annulation restaure la copie ; si le nom a été pris entre-temps, un nouveau nom est demandé.
- **Rerolls pour tous** (event) : donnés aux joueurs connectés.
- **Poche DarkRP** : désactivée par hook (`canPocket`) et retirée des armes par défaut. Vous pouvez aussi
  ajouter `["pocket"] = true` dans `darkrpmodification/lua/darkrp_config/disabled_defaults.lua`.
- **Sac de mort** : `dropweapondeath` de DarkRP est coupé, car les armes portées vont dans le sac.

## À définir plus tard (prévu dans le code, valeurs neutres)

- Valeurs chiffrées de chaque race (seule « Être Vivant » a sa vitesse ×0,9) : `C.Races[].Mod`.
- Effets du Sang Arcanique.
- SWEPs Vol (`C.SwepVol`) et Crachat de feu (`C.SwepCrachat`, dégâts et brûlure à 0) : dégâts, portée,
  recharge, durée de vol, zones interdites.
- Retours visuels des effets de race.
- Restrictions de jobs par race : `C.RestrictionsJobs`.
- Listes d'armes par catégorie (`C.CategoriesArmes`) et entités de l'inventaire (`sh_entites.lua`).
- Boutique de rerolls : non incluse, `ORIGINE.AjouterRerolls` est prête.
- Montant de départ : `C.MontantDepart` (nil = celui de DarkRP).
- Police et textures : mettre l'ID Workshop dans `C.WorkshopID` et le nom de la police dans `C.Charte`.

## Vérifications

Hors jeu (dans ce dépôt) :

```
pip install lupa luaparser
python3 tests/verifier_syntaxe.py     # syntaxe Lua de tous les fichiers (LuaJIT)
python3 tests/verifier_references.py  # chaque fonction ORIGINE.* appelée existe
python3 tests/verifier_globales.py    # aucune variable globale inconnue (fautes de frappe)
python3 tests/tests_logique.py        # noms, Covan, taux, tirage, piles d'inventaire
```

En jeu, les tests de validation du cahier des charges :

1. Passer du slot 1 au slot 2 puis revenir redonne exactement 120 / 200 PV, 13 / 140 d'armure,
   41 % de faim et le même job.
2. Un objet rangé sur le slot 1 n'apparaît pas dans l'inventaire du slot 2.
3. Se déconnecter pendant l'animation de tirage ne donne pas de nouveau tirage.
4. Un joueur sans la permission `origine_menu` ne peut déclencher aucune action staff, même en envoyant
   les messages réseau à la main.
5. Un crash serveur fait perdre au maximum les 5 dernières minutes.
6. « Tout transférer » vers un inventaire plein fait tomber le surplus au sol, sans rien dupliquer.
