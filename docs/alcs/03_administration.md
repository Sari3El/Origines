# ALCS — Administration

## Console Commands (kb/16)
- **wos_openadminmenu** — Opens a menu to set people's level, set xp, add levels, add xp, modify inventories, etc. "It is your mega admin menu." Configure it in the `config/admin` folder.
- **wos_lootspawn_start** — Gives you an item spawn tool to set up item spawns on your map
- **wos_lootspawn_end** — Saves all the spawns you have placed
- **wos_openinventory** — Opens inventory
- **wos_duelplacer_start** — Start creating a dueling arena
- **wos_duelplacer_end** — Finish creating a dueling arena
- (vu dans d'autres fiches) **wos_listitems** — console client : liste les objets et leur id
- (vu dans d'autres fiches) **wos_togglefirstperson** — bascule la vue première personne du sabre

## Set Permissions For wOS Admin Commands (kb/63)
"Admin Commands" = the console command `wos_openadminmenu`.
1. Navigate to `lua/wos/advswl/config/general/sv_adminsettings.lua`
2. Find the `wOS.ALCS.Config.CanAccessAdminMenu` value
3. Add a rank to the table and set it equal to true

Only the listed ranks can use the admin commands:
```lua
wOS.ALCS.Config.CanAccessAdminMenu = {

["owner"] = true,

["developer"] = true,

}
```

## Item Giving Function (kb/19)
Method 1 — by item id (find ids with `wos_listitems` in the client console):
```lua
local item = wOS:GetItemData( itemno )
wOS:HandleItemPickup( ply, item.Name )
```
If the player's inventory is full, the item is not given.
Several items:
```lua
local item1 = wOS:GetItemData( item1no )
local item2 = wOS:GetItemData( item2no )

wOS:HandleItemPickup( ply, item1.Name )
wOS:HandleItemPickup( ply, item2.Name )
```
Method 2 — by item name (exact name, keep the quotes):
```lua
wOS:HandleItemPickup( ply, "(Name of Item)")
wOS:HandleItemPickup( ply, "Crystal ( Green )")
```

## Item Spawning Function (kb/50)
Method 1 — by id:
```lua
local item = wOS:GetItemData( itemno )

wOS:CreateSaberItem( ply:GetPos(), item )
```
Several items:
```lua
local item1 = wOS:GetItemData( item1no )
local item2 = wOS:GetItemData( item2no )

wOS:CreateSaberItem( ply:GetPos(), item1)

wOS:CreateSaberItem( ply:GetPos(), item2)
```
Method 2 — by name:
```lua
wOS:CreateSaberItem( ply:GetPos(), "(Name of Item)")
wOS:CreateSaberItem( ply:GetPos(), "Crystal ( Green )" )
```
Spawn somewhere else: replace `ply:GetPos()` by a Vector. `getpos` in console returns e.g.
`setpos 704.666809 -380.561432 -79.968750;setang 14.683965 -63.647835 0.000000` → take the first three numbers:
```lua
wOS:CreateSaberItem(Vector(704, -380, -79), "Crystal ( Green )" )
```

## XP Giving Function (kb/48)
```lua
ply:AddSkillXP( number )
ply:AddSkillXP( 10000 )
```
Only for the base leveling system XP, not proficiency.
