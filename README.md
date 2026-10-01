# Médiéval RP — Origine du monde

Addons Garry's Mod (DarkRP + ULX/ULib) réalisés d'après les cahiers des charges
« Médiéval RP : Origine du monde ».

| Dossier | Contenu | Dépend de |
|---|---|---|
| `origine_personnages` | Slots, menu et création de personnage, races, rerolls, SWEPs de race, sauvegarde SQL, intégration DarkRP | DarkRP, ULX |
| `origine_hud` | HUD compact sous la chatbox (PV, armure et faim sur une ligne), compteur de munitions, infos au-dessus de la tête (superadmins) | origine_personnages |
| `origine_inventaire` | SWEP Sacoche, inventaire par personnage, sac de mort, liste des entités autorisées | origine_personnages |
| `origine_staff` | Menu `!origine`, actions staff, historique, copies avant CK et RPK, logs du serveur | origine_personnages, origine_inventaire |
| `origine_chat` | Chatbox à la charte : un seul chat général, heure des messages, historique aux flèches, complétion | origine_personnages |
| `origine_selecteur` | Sélecteur d'armes en haut au centre, cartes avec icône, munitions et barres de cooldown | aucune (charte d'origine_personnages si présent) |
| `origine_cycle` | Cycle jour/nuit (15 min / 45 min), heure RP, pleine lune, éclairage, StormFox 2 facultatif | origine_personnages |
| `origine_banque` | Guichet, compte par personnage, virements, relevé, trésor, prêts, onglet Administration | origine_personnages, origine_staff |
| `origine_mise_a_terre` | Mise à terre à 15 PV ou moins, relever, ligoter, escorter, délier | origine_personnages, origine_inventaire |
| `origine_courrier` | Missives sur parchemin : personnages, faction, autres factions, tout le serveur | origine_personnages, origine_inventaire, origine_staff |
| `origine_tickets` | Tickets F6 : demandes au staff, file, historique, statistiques | origine_personnages |
| `origine_armes` | 4 armes wOS ALCS (Nuit, Empire, Consortium, Mage) : manche simple, lame invisible, saut de Force / tous les pouvoirs | wOS ALCS ; liens facultatifs avec les autres addons |
| `darkrpmodification/lua/darkrp_modules/origine_tab/` | Menu TAB qui remplace le scoreboard de FAdmin (pas un dossier d'addon) | DarkRP, ULX ; origine_personnages et origine_staff conseillés |

## Installation

1. Copier les **douze dossiers** de `addons/` dans `garrysmod/addons/` du serveur
   (un dossier par système, ne pas les fusionner).
2. Redémarrer le serveur. La console doit afficher :
   ```
   [Origine] origine_personnages chargé.
   [Origine] Base de données prête (sqlite).
   [Origine] origine_inventaire chargé.
   [Origine] origine_hud chargé.
   [Origine] origine_staff chargé.
   [Origine] origine_chat chargé.
   [Origine] origine_selecteur chargé.
   [Origine] origine_cycle chargé.
   [Origine] origine_banque chargé.
   [Origine] origine_mise_a_terre chargé.
   [Origine] origine_courrier chargé.
   [Origine] origine_tickets chargé.
   [Origine] origine_armes chargé.
   ```
   Copier aussi `darkrpmodification/lua/darkrp_modules/origine_tab/` dans le dossier `darkrpmodification`
   du serveur (menu TAB : DarkRP le charge tout seul).
   Si DarkRP n'est pas lancé, ou si son module faim est désactivé, la console le signale au démarrage.
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
- `origine_staff/lua/origine_staff/sh_config.lua` : permission, limites d'affichage, logs
  (rétention 14 jours, regroupement des dégâts, catégories désactivables).
- `origine_chat/lua/origine_chat/sh_config.lua` : taille, police, durée d'affichage, longueur maximum,
  anti-spam, commandes proposées.
- `origine_selecteur/lua/origine_selecteur/sh_config.lua` : fermeture automatique (3 s), seuil d'affichage
  des cooldowns (1 s), sons (désactivés par défaut), armes en tête du slot 1 (Sacoche).
- `origine_cycle/lua/origine_cycle/sh_config.lua` : durées (15 / 45 min, transitions 2 min), pleine lune
  (1 nuit sur 4), messages RP, éclairage par paliers, brouillard, ciel.
- `origine_banque/lua/origine_banque/sh_config.lua` : frais (0 / 2 / 2 %), portée du guichet, prêts
  (montant et taux maximum, échéance), jobs qui consultent le trésor, prêtent ou retirent.
- `origine_mise_a_terre/lua/origine_mise_a_terre/sh_config.lua` : seuil (15 PV), compte à rebours (3 min),
  guérisseurs, durées et PV de relevage, ligoter / délier, déconnexion = mort.
- `origine_courrier/lua/origine_courrier/sh_config.lua` : prix du parchemin, longueur (1 000), délais
  (30 s / 10 min), jobs autorisés pour les missives générales, taille du coffret (100), touche.
- `origine_tickets/lua/origine_tickets/sh_config.lua` : touche (F6), catégories, délai (2 min), rétention
  (90 jours), priorités, webhook Discord.
- `darkrpmodification/lua/darkrp_modules/origine_tab/sh_config.lua` : liens Discord / règlement / collection
  Workshop (**à remplir**), seuils du ping, actions staff et commandes ULX associées.

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
| Chat : ↑ / ↓ | | Tous | Revenir sur les messages déjà envoyés |
| Chat : Tab | | Tous | Compléter une commande (`/`, `!`) ou un nom de joueur |
| Chat : clic droit | | Tous | Copier, répondre en MP, ignorer un joueur, ouvrir un lien |
| E sur un guichet | | Tous | Menu de la banque |
| E sur un joueur à terre / ligoté | | Tous | Relever, ligoter / délier, escorter, lâcher |
| `!missives` | | Tous | Coffret de missives |
| `/parchemin` | | Tous | Acheter un parchemin vierge (aussi au F4, onglet Entités) |
| E sur un parchemin / une missive | | Tous | Écrire / lire |
| F6, `!tickets` | | Tous | Menu des tickets (file des tickets pour le staff) |
| `!report message` | | Tous | Ticket rapide |
| `!cycle jour`, `nuit`, `heure 23:40`, `pause`, `reprendre`, `lune oui/non/auto` | `origine_cycle …` | `origine_cycle_admin` | Régler le cycle jour/nuit |
| `!modeadmin` | `origine_modeadmin` | `origine_mode_admin` | Afficher / masquer les noms au-dessus des joueurs |
| `ulx relever <joueur>`, `ulx delier <joueur>` | | ULX (admins) | Relever / délier (aussi dans le TAB) |

La permission `origine_menu` est donnée aux superadmins par défaut et s'attribue à d'autres rangs
dans XGUI (onglet Groupes, catégorie « Origine »). Elle est vérifiée côté serveur à chaque action.

## Jobs DarkRP

`darkrpmodification/lua/darkrp_customthings/jobs.lua` : 52 jobs générés depuis les tables de hiérarchie
(Empire, Créatures de la nuit, Consortium) en 7 catégories, plus « Villageois », le job par défaut.
Chaque job n'a que le toolgun, le physics gun, le gravity gun, le SWEP `origine_mains` (mains vides, bras
le long du corps) et la sacoche. Pas de clés, rien de plus pour les admins. Uniques (max 1) : Capitaine de la Milice, L'Originel, Banquier.
Aucune police DarkRP (`C.DesactiverPolice` : avis de recherche, mandats, prison, couvre-feu, licences retirés). Chaque faction a son chat de groupe (`/g`).

Dans `darkrpmodification/lua/darkrp_config/disabled_defaults.lua` :
- `["f4menu"] = true` pour couper le menu F4 (l'addon le bloque aussi : `C.DesactiverF4`) ;
- les jobs de base de DarkRP (`citizen`, `cp`, `mayor`, `gangster`, `mobboss`, `gundealer`, `medic`,
  `chief`, `hobo`) à `true`, pour ne garder que ceux de ce fichier.

## Menu staff `!origine`

- **Joueurs** : recherche (connectés et hors ligne), fiche du compte et des 5 personnages, actions
  (race, rerolls, nom, forcer un slot, slot EVENT, **déblocage du slot 3**, inventaire, CK / RPK, annulation).
  Le slot 3 est accessible aux groupes VIP **ou** aux joueurs débloqués par le staff.
- **Logs** : un sous-onglet par catégorie, avec filtres par joueur, par texte et par période, et pagination.
  Un clic sur une ligne affiche le détail et ouvre la fiche de l'auteur ou de la cible.

| Sous-onglet | Contenu |
|---|---|
| Dégâts | Quand, attaquant, victime, arme, dégâts, type (balle, feu, chute…), PV restants ; coups en rafale regroupés |
| Morts | Tueur, victime, arme, distance ; PNJ tués |
| Personnages | Création, tirage, reroll, chargement d'un slot, retour au menu, nouveau nom |
| Chat | Chaque message avec son canal (local, OOC, action, MP, commande…) |
| Connexions | Connexion, arrivée en jeu, déconnexion avec raison et durée de session (pas d'IP) |
| Props / entités | Props, entités, véhicules, PNJ, ragdolls, effets, armes, outils utilisés |
| Économie | Covan jetés, ramassés, donnés, chèques, achats DarkRP, portes (salaires en option) |
| Inventaire | Ranger, équiper, déposer, détruire, sacs de mort créés, fouillés, vidés |
| Jobs | Changements de métier |
| Police | Arrestations, libérations, avis de recherche, mandats |
| Staff | Historique des actions staff (qui, quoi, quand, sur qui, avant / après, raison) |

Les logs sont écrits par lots toutes les 5 secondes (table `origine_logs`) et supprimés après 14 jours.

## Menu TAB

Maintenir TAB ouvre le menu, relâcher le ferme ; il ne s'ouvre pas pendant le menu personnage.
Joueurs rangés par catégorie de job (ordre du F4), puis par métier et par nom ; les joueurs qui choisissent
leur personnage sont tout en bas. Cliquer sur une ligne ouvre la fiche (aperçu 3D, race, métier, badge,
couper sa voix pour soi).

Permissions ULX (XGUI > Groupes, catégorie « Origine TAB », données par défaut aux admins) :

| Permission | Effet |
|---|---|
| `origine_tab_staff` | Voir le nom Steam, le SteamID, le slot, les kills/morts, les PV et les Covan ; chercher par nom Steam / SteamID |
| `origine_tab_job` | Bouton « Changer le job » (pas d'équivalent ULX) |
| `origine_menu` | Bouton « Ouvrir dans !origine » (fiche du joueur dans le menu staff) |

Les autres boutons lancent les commandes ULX (`ulx kick`, `ulx ban`, `ulx jail`, `ulx freeze`, `ulx goto`,
`ulx bring`, `ulx return`, `ulx spectate`, `ulx gag`, `ulx mute`, `ulx strip`, `ulx cloak`, `ulx god`,
`ulx ignite`, `ulx psay`, `ulx slap`, `ulx ragdoll`, `ulx noclip`, `ulx hp`, `ulx armor`, et pour le
bouton « Serveur » : `ulx map`, `ulx stopsounds`, `ulx cleanup`, `ulx csay`). Un bouton n'apparaît que si
le staff a la permission de la commande ; ULX revérifie tout côté serveur.

## Sélecteur d'armes

Une colonne par slot (1 à 6), la Sacoche toujours en tête du slot 1. Molette, touches 1 à 6, clic gauche
pour équiper, clic droit pour fermer, `lastinv` et `hud_fastswitch 1` fonctionnent comme dans GMod.
Les cooldowns sont lus sur `NextPrimaryFire` / `NextSecondaryFire` (aucun SWEP à modifier) ; un SWEP peut
aussi donner les siens :

```lua
function SWEP:OrigineCooldowns()
	return {
		primaire   = { fin = self:GetNextPrimaryFire(),   duree = 30 },
		secondaire = { fin = self:GetNextSecondaryFire(), duree = 10 },
	}
end
```

Le sélecteur est silencieux (sons désactivables / remplaçables dans sa config).

## Permissions ULX des nouveaux systèmes

Toutes dans XGUI > Groupes, catégorie « Origine » (sauf `ulx relever` / `ulx delier`, catégorie ULX « Origine »).

| Permission | Par défaut | Effet |
|---|---|---|
| `origine_cycle_admin` | admins | `!cycle` : phase, heure, pause, pleine lune |
| `origine_banque_admin` | superadmins | Onglet Administration du guichet ; placer et déplacer les guichets |
| `origine_courrier_admin` | superadmins | Onglet Missives de `!origine` (avec `origine_menu`) : lire et supprimer |
| `origine_tickets_staff` | admins | Traiter les tickets (F6) ; nombre de tickets en attente dans le TAB |
| `origine_tickets_admin` | superadmins | Statistiques, réattribution et suppression des tickets |

## Cycle jour/nuit

15 minutes de jour (6 h → 18 h RP) puis 45 minutes de nuit (18 h → 6 h), aube et crépuscule de 2 minutes
compris. Le HUD affiche « Nuit · 23:40 » sous les Covan. Message RP à l'aube et au crépuscule ; une nuit sur 4
est une nuit de pleine lune (annoncée, sans effet pour l'instant). La position dans le cycle est gardée dans
`data/origine/cycle.json` : après un redémarrage, le cycle reprend là où il en était.
L'éclairage de la map change par paliers (chaque palier recharge l'éclairage chez les clients).
Avec StormFox 2, le cycle lui donne l'heure RP et ne fait plus son propre rendu.

Pour les bonus et malus à venir (vampires, lycans…) :

```lua
ORIGINE.EstNuit()  ORIGINE.HeureRP() --> 23, 40  ORIGINE.EstPleineLune()  ORIGINE.PhaseCycle()
hook.Add("OrigineDebutJour", …)  hook.Add("OrigineDebutNuit", …)  hook.Add("OrigineChangementPhase", …)
```

## Banque

Le staff (`origine_banque_admin`) place le guichet depuis le menu des entités (catégorie Origine) ; il reste au
même endroit après un redémarrage (`data/origine/guichets/<map>.json`). E sur le guichet :

- **Mon compte** : bourse (Covan portés) et compte, déposer, retirer, virement vers le personnage d'un autre
  joueur (par son nom, connecté ou non ; refusé vers ses propres personnages), relevé des 50 dernières opérations.
- **Prêt** : accepter / refuser une proposition, rembourser en une ou plusieurs fois. Les banquiers proposent
  un prêt (montant, taux, échéance en jours réels, jamais plus que le trésor) et voient les débiteurs en retard.
- **Trésor** (jobs de la banque) : solde, mouvements (qui, combien, pourquoi), retrait vers la bourse (dirigeant).
- **Administration** (`origine_banque_admin`) : recherche d'un joueur (connecté ou non), ses 5 slots
  (bourse, compte, prêt, total), ajout / retrait de Covan avec raison obligatoire, correction du trésor,
  annulation d'un prêt. Tout est écrit dans l'historique de `!origine`.

Chaque opération (bourse, compte, relevé, trésor) est écrite en une seule transaction SQL. Un CK ou un RPK
remet le compte à 0 et annule le prêt ; la copie d'avant le CK inclut le compte et le prêt.

## Mise à terre et captures

Un coup d'arme (joueur ou PNJ) qui laisse 15 PV ou moins met à terre ; un coup qui amène à 0 PV tue. Chutes,
feu, noyade suivent les règles normales. À terre : ni mouvement, ni arme, ni inventaire, ni sélecteur ;
voix et chat possibles ; écran assombri, « Vous êtes à terre » et 3 minutes avant la mort (le sac de mort
tombe). Les autres voient « À terre » au-dessus de lui ; la régénération de race est en pause.

E sur lui : **Relever** (guérisseur : 5 s, 25 PV ; n'importe qui s'il n'y a aucun guérisseur connecté : 10 s,
20 PV) ou **Ligoter** (3 s). Ligoté : ni arme, ni inventaire, ni course ; son ravisseur peut l'**Escorter**
(il le suit) puis le **Lâcher** ; n'importe qui le **Délie** en 5 s. La distance est vérifiée pendant toute
l'action. Impossible de changer de personnage ou d'utiliser `kill` à terre ou ligoté ; se déconnecter compte
comme une mort. L'arrestation DarkRP délie le captif.

## Missives

Parchemin vierge : F4 (onglet Entités, catégorie Origine) ou `/parchemin`, rangeable dans l'inventaire.
Écrire consomme un parchemin (E sur un parchemin posé, ou « Écrire » du coffret s'il y en a un dans
l'inventaire). Destinataires : un ou plusieurs personnages (connectés ou non), sa faction, d'autres factions
(copie dans le registre de la sienne), ou tout le serveur. Signature automatique, 1 000 caractères.

`!missives` : coffret à trois onglets (Personnelles, Faction, Général) ; lire, répondre, sortir en papier
(entité que tout le monde peut lire, ranger, voler ou détruire), supprimer. Le registre d'une faction n'est
lisible que par ses membres actuels. 30 s entre deux missives, 10 min entre deux missives générales,
100 missives personnelles gardées. Un CK ou un RPK vide le coffret du personnage.

## Tickets

F6 (ou `!tickets`) : le joueur ouvre un ticket (catégorie, description, joueurs concernés ; personnage,
job, position et heure joints), suit la discussion, voit le statut et le staff qui s'en occupe, ferme
son ticket avec une note de 1 à 5. Un ticket ouvert à la fois, 2 minutes entre deux tickets.
`!report message` ouvre un ticket rapide. Les tickets sont liés au compte.

Staff (`origine_tickets_staff`) : file triée par ancienneté (filtres catégorie, statut, staff), historique
(joueur, staff, catégorie, date), prendre en charge, répondre, note interne, attendre le joueur, priorité,
transférer, fermer avec une note de résolution, rouvrir, actions ULX rapides (aller vers, ramener, renvoyer,
observer, geler) et « Ouvrir dans !origine ». Son et notification à chaque nouveau ticket ; le nombre de
tickets en attente est affiché dans F6 et dans l'en-tête du TAB. Statistiques (`origine_tickets_admin`) :
tickets traités, temps moyen avant la première réponse, note moyenne par staff.
Les tickets ouverts restent après un redémarrage ; les fermés sont gardés 90 jours. Option Discord :
`Discord.Webhook` dans la config (envoyé quand aucun staff n'est connecté).

## Armes wOS de base

Quatre copies de sabres wOS ALCS dans `origine_armes/lua/weapons/` (voir `origine_armes/LISEZMOI.txt`) :
Lame de la Nuit, de l'Empire et du Consortium (saut de Force uniquement), Lame du Mage (tous les pouvoirs et
ultimes installés, listes construites depuis wOS). Manche simple, lame « Invisible » qui garde sa portée
(`SWEP.UseLength = 42`), aucun son ni effet de sabre laser, pas de brûlure ni d'étourdissement, arbres de
compétences et atelier wOS sans effet. Catégories « Origine [Faction] Weapon » du menu des armes.
Données par les jobs de leur faction (`jobs.lua`) ; avec `C.ArmesDuJob = true`, le loadout strict
d'origine_personnages donne les armes du job (sauf police et clés DarkRP). Aucun job « Mage » n'existe encore.
Intégration : sélecteur (nom seul, cooldown du pouvoir choisi), inventaire (rangeables), mise à terre (aucun
pouvoir à terre ou ligoté), races (les 4 lames en « mêlée », les pouvoirs offensifs du Mage en « magie »).
Comportement d'épée (`origine_armes/sh_epee.lua`) : tous les sons de sabre laser coupés (allumage, bourdonnement,
balancement, impacts, chocs entre lames ; les sons des pouvoirs restent), plus de brûlure ni d'étincelles sur
les murs, et la lame ne blesse que pendant un vrai coup (pas au simple contact d'une lame immobile).
La trace wOS est réglée sur `MINIMALINTERP` (à reporter aussi dans le `sv_config.lua` de wOS).
Modèle d'épée `models/peanut/templarsword.mdl` (`origine_armes/sh_modele.lua`) : placé dans la main s'il n'est pas préparé
comme une arme ; réglage en jeu avec `origine_epee_debug 1` et `origine_epee_placer` (voir le LISEZMOI).

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
hook.Add("origine_ChatMessage", "mon_addon", function(message) end)  -- client, chaque message du chat
ORIGINE.Logs.Ajouter("categorie", acteur, cible, "texte", { details })  -- serveur, ajouter un log
hook.Add("origine_PeutChangerPerso", "mon_addon", function(ply) return false, "raison" end)  -- bloquer !perso
hook.Add("origine_RegenBloquee", "mon_addon", function(ply) return true end)               -- suspendre la régénération
hook.Add("origine_CategorieDegats", "mon_addon", function(dmg, attaquant, cat) return "magie" end) -- catégorie d'un coup (races)
ORIGINE.DB.Transaction({ { sql, params }, … }, function(ok) end)  -- plusieurs écritures, tout ou rien
ORIGINE.Staff.AjouterExtensionCK({ nom, lire, vider, restaurer })  -- données remises à zéro au CK / RPK
ORIGINE.Inv.Autoriser(classe)  ORIGINE.Inv.AjouterActionObjet(classe, id, nom, icone, fn)
ORIGINE.EstATerre(ply)  ORIGINE.EstLigote(ply)  ORIGINE.EstImmobilise(ply)
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
| `origine_logs` | Logs du serveur (dégâts, chat, connexions…) |
| `origine_banque_*` | Comptes, opérations (relevé), trésor, mouvements du trésor, prêts |
| `origine_missives*` | Missives, coffrets personnels, registres de faction, missives masquées |
| `origine_tickets`, `origine_tickets_messages` | Tickets et leurs fils de discussion |

Sauvegarde au changement de personnage, à la déconnexion, toutes les 5 minutes, à l'arrêt du serveur
et à chaque modification d'inventaire (écritures regroupées). Un personnage n'est réécrit que s'il a
changé depuis la dernière écriture. Les colonnes ajoutées par les mises à jour sont créées automatiquement
sur une base existante. Copie complète des tables chaque jour
dans `garrysmod/data/origine/sauvegardes/`, gardée 7 jours.

Mise en place : les Covan qu'un joueur avait déjà dans DarkRP sont transférés sur son slot 1.

## Choix d'interprétation

- **`DarkRP_HUD` n'est pas masqué.** Dans DarkRP, cet élément englobe aussi l'arrestation, le couvre-feu,
  l'agenda et le chat vocal, que le cahier demande de conserver. La vie, l'argent, le salaire et le job
  (`DarkRP_LocalPlayerHUD`), la faim (`DarkRP_Hungermod`) et les infos au-dessus des joueurs
  (`DarkRP_EntityDisplay`) sont bien masqués et remplacés. Les infos des portes, qui étaient dans
  `DarkRP_EntityDisplay`, sont redessinées par `origine_hud`.
- **HUD sous la chatbox.** Avec `origine_chat`, le chat se place en laissant la place au HUD dessous.
  Sans lui, s'il n'y a pas assez de place sous la chatbox, le HUD est réduit ; s'il deviendrait trop petit,
  il se place à droite de la chatbox, en bas, pour ne jamais la chevaucher. La jauge de faim est masquée
  si le module faim de DarkRP est désactivé, et le métier n'est pas affiché tant que le joueur n'en a pas.
- **Chat.** Un seul chat général. Les messages partent avec `say` / `say_team` : DarkRP, ULX et les autres
  addons les traitent comme avant. Pour écrire hors RP : `/ooc message` ou `// message`. Pendant le menu
  personnage, seul l'OOC reste disponible (règle du cahier). Les joueurs ignorés et les préférences sont gardés sur le PC du joueur.
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
- **Mort** : pour l'instant, rien ne tombe à la mort sauf la moitié des Covan portés (`CovanPerdusMort = 0.5`).
  Le sac de mort est codé mais désactivé (`Sac.Actif = false` dans la config d'origine_inventaire).
  `dropweapondeath` et `dropmoneyondeath` de DarkRP sont coupés.

- **Menu TAB — qui voit quoi.** Les joueurs ne voient que le nom Steam, le SteamID, l'avatar et le ping
  de chacun (une seule liste, sans catégories de job). Le staff (`origine_tab_staff`) voit en plus le nom
  du personnage, la race, le métier, le badge Staff/EVENT, le slot, les kills/morts, les PV et les Covan,
  avec la liste rangée par catégorie de job.
- **Infos au-dessus des joueurs** : visibles automatiquement sur le slot Staff, ou en « mode admin »
  (`!modeadmin`, permission `origine_mode_admin`, superadmins par défaut). `InfosTete.Tous = true` dans la
  config d'origine_hud pour les montrer à tout le monde. Les infos des portes restent visibles par tous.

- **Parchemin au F4** : le menu F4 est désactivé sur ce serveur (`C.DesactiverF4`) ; le parchemin est donc
  aussi en vente avec `/parchemin`.
- **Guérisseurs** : aucun job guérisseur n'existe encore ; la liste `Relever.Guerisseurs` est vide, donc tout le
  monde relève en 10 s. Ajoutez la commande du job quand il existera.
- **Arrestation d'un captif** : `GAMEMODE.CivilProtection` est vide (police DarkRP coupée), il n'y a donc pas
  de bâton d'arrestation. Tout addon qui appelle `ply:arrest()` fonctionne sur un captif (il est délié).
- **Réponse à une missive** : envoyée aux mêmes destinataires ; elle consomme un parchemin de l'inventaire.
- **Missive supprimée ou sortie en papier depuis Faction / Général** : masquée pour ce personnage seulement.
- **Prêt** : les intérêts (taux) s'appliquent une fois sur le montant ; le remboursement se fait depuis le compte.
- **Frais** : prélevés sur le montant (un retrait de 1 000 à 2 % donne 980 dans la bourse).

## À définir plus tard (prévu dans le code, valeurs neutres)

- Bonus et malus du jour, de la nuit et de la pleine lune (les fonctions et hooks du cycle sont prêts).

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
python3 tests/tester_jobs.py          # jobs.lua : commandes uniques, catégories, armes
python3 tests/tester_selecteur.py     # sélecteur : cooldowns, Sacoche en tête, fastswitch, fermeture
python3 tests/tester_cycle_banque.py  # cycle 15/45 min, heure RP, reprise ; frais, montants, virements
python3 tests/tester_armes.py         # armes wOS : réglages, listes du Mage avec / sans packs, cooldown, magie
```

À vérifier en jeu (points que les tests hors jeu ne couvrent pas) : la séquence au sol
(`Sequence = "zombie_slump_idle_02"`) sur vos playermodels, l'API StormFox 2 (`StormFox2.Time.Set`),
et l'envoi du webhook Discord depuis votre hébergeur.

En jeu, les tests de validation du cahier des charges :

1. Passer du slot 1 au slot 2 puis revenir redonne exactement 120 / 200 PV, 13 / 140 d'armure,
   41 % de faim et le même job.
2. Un objet rangé sur le slot 1 n'apparaît pas dans l'inventaire du slot 2.
3. Se déconnecter pendant l'animation de tirage ne donne pas de nouveau tirage.
4. Un joueur sans la permission `origine_menu` ne peut déclencher aucune action staff, même en envoyant
   les messages réseau à la main.
5. Un crash serveur fait perdre au maximum les 5 dernières minutes.
6. « Tout transférer » vers un inventaire plein fait tomber le surplus au sol, sans rien dupliquer.
