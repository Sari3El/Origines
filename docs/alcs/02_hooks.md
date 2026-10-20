# ALCS — Hook Manifest (kb/115)

Source : https://support.wiltostech.com/knowledgebase/115/Hook-Manifest.html
Aucun exemple de code n'est fourni sur la page. « BOOL_BLOCK » = renvoyer true pour bloquer.

| Hook | Realm | Arguments | Retour | Description (texte d'origine) |
|---|---|---|---|---|
| `wOS.ALCS.GetSequenceOverride` | SHARED | ENTITY_PLAYER, VECTOR_VELOCITY | INT_ACT, INT_SEQUENCE | Overwrites sequence being played on the player |
| `wOS.ALCS.Combat.PreProjectileBlock` | SERVER | ENTITY_WEAPON, ENTITY_PLAYER, DAMAGEINFO_DMG, INT_HITGROUP | BOOL_BLOCK | Return true to prevent stamina/force power check of blocking projectiles |
| `wOS.ALCS.Combat.ShouldProjectileBlock` | SERVER | ENTITY_WEAPON, ENTITY_PLAYER, DAMAGEINFO_DMG, INT_HITGROUP | BOOL_BLOCK | Return true to block projectile, no matter the type of projectile it is |
| `wOS.ALCS.Combat.PreProjectileDeflect` | SERVER | ENTITY_WEAPON, ENTITY_PLAYER, TABLE_BULLET, DAMAGEINFO_DMG | nothing | Called before a projectile is deflected |
| `wOS.ALCS.Combat.OnProjectileBlocked` | SERVER | ENTITY_WEAPON, ENTITY_PLAYER, DAMAGEINFO_DMG, INT_HITGROUP | BOOL_BLOCK | Return true to prevent force or stamina being taken for the successful block |
| `wOS.ALCS.Combat.PostProjectileBlocked` | SERVER | ENTITY_WEAPON, ENTITY_PLAYER, DAMAGEINFO_DMG, INT_HITGROUP | nothing | Called after a successful deflect, and after force/stamina is taken away |
| `wOS.ALCS.GetCharacterID` | SERVER | ENTITY_PLAYER | INT_CHARID | Called when the addon requests the player's character ID. Return the ID or 0 if it's not selected |
| `wOS.ALCS.GetPlayerCurrency` | SERVER | ENTITY_PLAYER | INT_MONEY | Called when the addon requests the player's currency. Return the amount of money they have |
| `wOS.ALCS.SetPlayerCurrency` | SERVER | ENTITY_PLAYER, INT_DELTA_AMOUNT | BOOL_BLOCK | Called when the addon changes the player's currency. Return true to block the default functionality |
| `wOS.ALCS.DrawLightsaberHUD` | CLIENT | ENTITY_WEAPON | BOOL_BLOCK | Called when the addon is creating the lightsaber HUD. Return true to block the default functionality |
| `wOS.ALCS.Combat.GetHeavyCoolDown` | SERVER | ENTITY_WEAPON, ENTITY_PLAYER | INT_COOLDOWN | Called when checking heavy cooldowns. Return the value as the cooldown between heavy attacks |
| `wOS.ALCS.Lightsaber.PreSettingsApply` | SERVER | ENTITY_WEAPON, ENTITY_PLAYER | nothing | Called before all the toolgun / skills / crafting data is applied to the lightsaber |
| `wOS.ALCS.Lightsaber.PostSettingsApply` | SERVER | ENTITY_WEAPON, ENTITY_PLAYER | nothing | Called after all the toolgun / crafting data is applied, but before the skills are applied |
| `wOS.ALCS.Lightsaber.PostSkillApply` | SERVER | ENTITY_WEAPON, ENTITY_PLAYER | nothing | Called after all the settings are applied to the lightsaber, including their skills |
| `wOS.ALCS.Skills.CanPurchaseSkill` | SERVER | ENTITY_PLAYER, TABLE_SKILLDATA, STRING_TREE, INT_TIER, INT_SKILL | BOOL_BLOCK | Called when the player purchases a skill. Return true to block the purchase |
| `wOS.ALCS.Combat.PreBladeBlock` | SERVER | ENTITY_WEAPON, ENTITY_ENEMY_WEAPON, ENTITY_ENEMY_PLAYER | BOOL_BLOCK | Return true to prevent stamina/force power check of blocking lightsabers |
| `wOS.ALCS.Combat.ShouldBladeParry` | SERVER | ENTITY_WEAPON, ENTITY_ENEMY_WEAPON, ENTITY_ENEMY_PLAYER, INT_PARRY_COST | BOOL_BLOCK | Return true to prevent stamina/force power check of parrying lightsabers |
| `wOS.ALCS.Combat.OnBladeParry` | SERVER | ENTITY_WEAPON, ENTITY_ENEMY_WEAPON, ENTITY_ENEMY_PLAYER, INT_PARRY_COST | BOOL_BLOCK | Called when an attack is successfully parried |
| `wOS.ALCS.Combat.OnBladeBlocked` | SERVER | ENTITY_WEAPON, ENTITY_ENEMY_WEAPON, ENTITY_ENEMY_PLAYER | BOOL_BLOCK | Return true to prevent stamina/force deduction when blocking lightsabers |
| `wOS.ALCS.Proficiency.ShouldGainXP` | SERVER | ENTITY_PLAYER, NUMBER_AMOUNT | BOOL_BLOCK | Can the player gain Crafting XP. Return true to prevent. If you add crafting XP here, add a player bool check so you don't crash your server! |
| `wOS.ALCS.Proficiency.GetNPCXP` | SERVER | ENTITY_PLAYER, ENTITY_NPC, NUMBER_AMOUNT | INT_XP | Crafting XP for an NPC kill. Return an XP number to award that amount instead |
| `wOS.ALCS.Proficiency.GetPlayerXP` | SERVER | ENTITY_PLAYER_ATTACKER, ENTITY_PLAYER_VICTIM, NUMBER_AMOUNT | INT_XP | Crafting XP for a player kill (the page says "NPC", copy error). Return an XP number to award that amount instead |
| `wOS.ALCS.Skill.ShouldGainXP` | SERVER | ENTITY_PLAYER, NUMBER_AMOUNT | BOOL_BLOCK | Can the player gain main Skill XP. Return true to prevent. If you add Skill XP here, add a player bool check so you don't crash your server! |
| `wOS.ALCS.Skill.GetNPCXP` | SERVER | ENTITY_PLAYER, ENTITY_NPC, NUMBER_AMOUNT | INT_XP | Skill XP for an NPC kill. Return an XP number to award that amount instead |
| `wOS.ALCS.Skill.GetPlayerXP` | SERVER | ENTITY_PLAYER_ATTACKER, ENTITY_PLAYER_VICTIM, NUMBER_AMOUNT | INT_XP | Skill XP for a player kill. Return an XP number to award that amount instead |
| `wOS.ALCS.CanUseForcepower` | SERVER | ENTITY_PLAYER, ENTITY_WEAPON, TABLE_FORCEPOWER_DATA | BOOL_BLOCK | Can the player use a force power. Return true to prevent |
| `wOS.ALCS.Admin.CanUseMenu` | SERVER | ENTITY_PLAYER | BOOL_BYPASS | Can the player open the admin menu. Return true to bypass any check |
| `wOS.ALCS.Dueling.BlockDuel` | SERVER | ENTITY_PLAYER_CHALLENGER, ENTITY_PLAYER_VICTIM, TABLE_DUEL_INFO | BOOL_BLOCK | Can the player challenge someone to a duel. Return true to block |
| `wOS.ALCS.Skill.OnLevelUp` | SERVER | ENTITY_PLAYER | nothing | The player has just received a Skill Level Up |
| `wOS.ALCS.Skill.OnSkillReset` | SERVER | ENTITY_PLAYER, INT_SKILLPOINT_REFUND | nothing | The player has just reset their skills |
| `wOS.ALCS.Proficiency.OnLevelUp` | SERVER | ENTITY_PLAYER | nothing | The player has just received a Crafting Level Up |
| `wOS.ALCS.Inventory.OnItemPickUp` | SERVER | ENTITY_PLAYER, STRING_ITEM_NAME, INT_SLOT, INT_AMOUNT | nothing | The player has just picked up an item |
| `wOS.ALCS.Inventory.OnItemDropped` | SERVER | ENTITY_PLAYER, STRING_ITEM_NAME, INT_AMOUNT, INT_SLOT | nothing | The player has just dropped an item |
| `wOS.ALCS.Admin.OnAddXP` | SERVER | ENTITY_PLAYER, ENTITY_TARGET_PLAYER, INT_AMOUNT | nothing | The player has just given another player XP |
| `wOS.ALCS.Admin.OnAddLevel` | SERVER | ENTITY_PLAYER, ENTITY_TARGET_PLAYER, INT_AMOUNT | nothing | The player has just given another player levels |
| `wOS.ALCS.Admin.OnAddSkillPoints` | SERVER | ENTITY_PLAYER, ENTITY_TARGET_PLAYER, INT_AMOUNT | nothing | The player has just given another player skill points |
| `wOS.ALCS.Admin.OnSetXP` | SERVER | ENTITY_PLAYER, ENTITY_TARGET_PLAYER, INT_AMOUNT | nothing | The player has just set another player's XP |
| `wOS.ALCS.Admin.OnSetLevel` | SERVER | ENTITY_PLAYER, ENTITY_TARGET_PLAYER, INT_AMOUNT | nothing | The player has just set another player's level |
| `wOS.ALCS.Admin.OnSetSkillPoints` | SERVER | ENTITY_PLAYER, ENTITY_TARGET_PLAYER, INT_AMOUNT | nothing | The player has just set another player's skill points |
| `wOS.ALCS.Admin.OnGiveMaterials` | SERVER | ENTITY_PLAYER, ENTITY_TARGET_PLAYER, STRING_ITEM_NAME, INT_AMOUNT | nothing | The player has just given another player materials |
| `wOS.ALCS.Admin.OnRemoveMaterials` | SERVER | ENTITY_PLAYER, ENTITY_TARGET_PLAYER, STRING_ITEM_NAME, INT_AMOUNT | nothing | Materials removed from a player's inventory |
| `wOS.ALCS.Admin.OnGiveItem` | SERVER | ENTITY_PLAYER, ENTITY_TARGET_PLAYER, STRING_ITEM_NAME | nothing | The player has just given another player an item |
| `wOS.ALCS.Admin.OnRemoveItem` | SERVER | ENTITY_PLAYER, ENTITY_TARGET_PLAYER, STRING_ITEM_NAME | nothing | Items removed from a player's inventory |
| `wOS.ALCS.Admin.OnSpawnItem` | SERVER | ENTITY_PLAYER, ENTITY_TARGET_PLAYER, STRING_ITEM_NAME | nothing | The player has spawned an item in |
| `wOS.ALCS.Crafting.CanEquipItem` | SERVER | ENTITY_PLAYER, TABLE_ITEM_DATA | BOOLEAN | Player tries to equip an item. Return true to allow, false to block, nil to continue through checks |
| `wOS.SkillTrees.OnMountToHud` | SERVER | ENTITY_PLAYER | BOOLEAN | Whenever the Level HUD would be drawn. Return true to prevent draw |
| `wOS.ALCS.Skill.CanViewTree` | SHARED | ENTITY_PLAYER, STRING_TREE_NAME, TABLE_TREE_DATA | BOOLEAN | Can a player view/apply a skill tree. Return true to allow, false to prevent |

## Utile pour Origine du monde (note)

- `wOS.ALCS.GetCharacterID` : c'est par ce hook que l'ALCS sépare ses données (compétences, niveaux,
  inventaire wOS) par personnage. Brancher `ORIGINE.CleDePersonnage(ply)` / le slot joué dessus
  permettrait d'avoir des compétences et un inventaire wOS différents pour chaque personnage.
- `wOS.ALCS.GetPlayerCurrency` / `wOS.ALCS.SetPlayerCurrency` : relier la monnaie wOS aux Covan.
- `wOS.ALCS.CanUseForcepower`, `wOS.ALCS.Combat.*` : utiles pour la mise à terre (bloquer la Force et
  les attaques d'un joueur à terre ou ligoté) et pour les futurs bonus de race / de nuit.
- `wOS.ALCS.DrawLightsaberHUD`, `wOS.SkillTrees.OnMountToHud` : masquer les HUD wOS pour garder la charte.
