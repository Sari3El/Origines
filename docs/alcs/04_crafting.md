# ALCS — Crafting (objets, inventaire wOS)

## Change Item Spawn Rates, And Data Saving Occurency (kb/60)
File: `lua/wos/advswl/config/crafting/sv_craftwos.lua`
- `wOS.ALCS.Config.Crafting.CraftingDatabase.SaveFrequency` — how often inventories, spawn positions, etc. are saved, in SECONDS. Default 360
- `wOS.ALCS.Config.Crafting.ItemSpawnFrequency` — how often to try to respawn items, in SECONDS. Default 0.1 (there is never a 100 % chance of an item spawning)
- `wOS.ALCS.Config.Crafting.LootSpawnPercent` — share of item spawn points spawning items at once. Default 1 (100 %)
- `wOS.ALCS.Config.Crafting.ItemDespawnTime` — time after spawning before an item despawns. Default 600

Example (save every 3 min, try every 5 s, 80 % of spawns, despawn after 5 min):
```lua
wOS.ALCS.Config.Crafting.CraftingDatabase.SaveFrequency = 180

wOS.ALCS.Config.Crafting.ItemSpawnFrequency = 5

wOS.ALCS.Config.Crafting.LootSpawnPercent = 0.8

wOS.ALCS.Config.Crafting.ItemDespawnTime = 300
```

## Change Max Inventory Slots (kb/57)
1. `lua/wos/advswl/config/crafting/sh_craftwos.lua`
2. `wOS.ALCS.Config.Crafting.MaxInventorySlots`, near the end of the file
3. Any number; an even number is recommended so the page of slots isn't cut short
```lua
wOS.ALCS.Config.Crafting.MaxInventorySlots = 80
```

## Configure MySQL For Crafting (kb/70)
In `lua/wos/advswl/config/crafting/sv_craftwos.lua`, set `wOS.ALCS.Config.Crafting.ShouldCraftingUseMySQL` to `true`, then:
```lua
wOS.ALCS.Config.Crafting.CraftingDatabase = wOS.ALCS.Config.Crafting.CraftingDatabase or {}

wOS.ALCS.Config.Crafting.CraftingDatabase.Host = "localhost"

wOS.ALCS.Config.Crafting.CraftingDatabase.Port = 3306

wOS.ALCS.Config.Crafting.CraftingDatabase.Username = "root"

wOS.ALCS.Config.Crafting.CraftingDatabase.Password = ""

wOS.ALCS.Config.Crafting.CraftingDatabase.Database = "wos-crafting"

wOS.ALCS.Config.Crafting.CraftingDatabase.Socket = ""
```
- Host: domain, IP or web address of the database
- Port: usually 3306
- Username / Password: database credentials
- Database: name of the database

Example:
```lua
wOS.ALCS.Config.Crafting.CraftingDatabase.Host = "testwebsite.org"
wOS.ALCS.Config.Crafting.CraftingDatabase.Port = 3306
wOS.ALCS.Config.Crafting.CraftingDatabase.Username = "testwebsite_wos"
wOS.ALCS.Config.Crafting.CraftingDatabase.Password = "wostestingpass"
wOS.ALCS.Config.Crafting.CraftingDatabase.Database = "testwebsite_woscrafting"
wOS.ALCS.Config.Crafting.CraftingDatabase.Socket = ""
```

## Creating Your Own Item (kb/21)
Items live in `lua/wos/advswl/crafting/items`.
```lua
local ITEM = {}

ITEM.Name = "Enter Item Name"

ITEM.Description = "Description of Item"

ITEM.Type = Type

ITEM.UserGroups = {"usergroup1", "usergroup2"} or false

ITEM.BurnOnUse = true/false

ITEM.Model = "models/blue2/blue2.mdl"

ITEM.Rarity = 0

ITEM.OnEquip = function( wep )

end

wOS:RegisterItem( ITEM )
```
- `ITEM.Name` — name of the item (also the identifier for spawning it; make it unique)
- `ITEM.Description` — text under the name
- `ITEM.Type` — `WOSTYPE.BLUEPRINT`, `WOSTYPE.CRYSTAL`, `WOSTYPE.HILT`, `WOSTYPE.IDLE`, `WOSTYPE.IGNITER`, `WOSTYPE.VORTEX`
- `ITEM.UserGroups` — usergroups that can use it (false = everyone)
- `ITEM.BurnOnUse` — disappears when equipped/used
- `ITEM.Model` — world, inventory and crafting model
- `ITEM.Rarity` — 0 = cannot spawn, 100 = most common
- `ITEM.OnEquip` — what happens when equipped

OnEquip options:
```lua
wep.UseColor = Color( red, green, blue )                    -- color, 0 to 255
wep.CustomSettings[ "Blade" ] = "bladename"                 -- blade type
wep.UseHilt = "model path of hilt"                          -- hilt model
wep.UseLoopSound = "sound path"                             -- idle sound
wep.UseOnSound = "sound path"                               -- ignition sound
wep.UseOffSound = "sound path"                              -- de-ignition sound
wep.UseLength = wep.UseLength + wep.UseLength*0.25          -- length
wep.UseWidth = wep.UseWidth + wep.UseWidth*0.25             -- width
wep.UseSwingSound = "sound path"                            -- swing sound
```
Example:
```lua
local ITEM = {}
ITEM.Name = "Ultimate Crystal"
ITEM.Description = "Description of Item"
ITEM.Type = WOSTYPE.CRYSTAL
ITEM.UserGroups = false
ITEM.BurnOnUse = false
ITEM.Model = "models/blue2/blue2.mdl"
ITEM.Rarity = 0
ITEM.OnEquip = function( wep )
wep.UseColor = Color( 255, 255, 255 )
wep.CustomSettings[ "Blade" ] = "Saw Tooth"
wep.UseHilt = "models/days/days.mdl"
wep.UseLoopSound = "lightsaber/darksaber_loop.wav"
wep.UseOnSound = "lightsaber/darksaber_on.wav"
wep.UseOffSound = "lightsaber/darksaber_off.wav"
wep.UseLength = wep.UseLength + wep.UseLength*0.25
wep.UseWidth = wep.UseWidth + wep.UseWidth*0.25
wep.UseSwingSound = "lightsaber/darksaber_swing.wav"
end
wOS:RegisterItem( ITEM )
```

Blueprints:
```lua
local ITEM = {}
ITEM.Name = "Demo Blueprint"
ITEM.Description = "Demo Blueprint Description"
ITEM.Type = WOSTYPE.BLUEPRINT
ITEM.UserGroups = { "usergroup1", "usergroup2" }/false
ITEM.BurnOnUse = true/false
ITEM.Model = "model above the blueprint"
ITEM.Ingredients = {
    Material/Amount of materials used to craft it
}
ITEM.Result = "What it should give. The exact name of it as it is in ITEM.Name"
ITEM.OnCrafted = function( ply )
   Anything that should happen when you use the blueprint to craft something (Any GLua code)
end
wOS:RegisterItem( ITEM )
```
Default materials: Aluminum Alloy, Refined Steel, Glass.
```lua
local ITEM = {}
ITEM.Name = "Kylo Ren's Hilt Blueprint"
ITEM.Description = "To succeed, one must learn to create"
ITEM.Type = WOSTYPE.BLUEPRINT
ITEM.UserGroups = false
ITEM.BurnOnUse = true
ITEM.Model = "models/weapons/starwars/w_kr_hilt.mdl"
ITEM.Ingredients = {
    [ "Refined Steel" ] = 5,
    [ "Aluminum Alloy" ] = 2,
[ "Glass"] = 4,
}
ITEM.Result = "Kylo Ren's Hilt"
ITEM.OnCrafted = function( ply )
    ply:AddSkillXP( 100 )
end
wOS:RegisterItem( ITEM )
```

## Enable/Disable Zhrom/Clone Adventures Pack (kb/69)
`lua/wos/advswl/config/general/sh_serverwos.lua`
- `wOS.ALCS.Config.EnableZhromExtension` — true enables the pack in the toolgun and as crafting items. CRUCIAL: contains the required models for crystals, lightsaber crafting, character stations, etc. (and unique hilts)
- `wOS.ALCS.Config.EnableCloneAdventures` — true enables the Clone Wars Adventures hilts
```lua
wOS.ALCS.Config.EnableZhromExtension = true

wOS.ALCS.Config.EnableCloneAdventures = true
```

## How To Change The Color Of A Crystal Item (kb/72)
Open the item in `lua/wos/advswl/crafting/items`, find `ITEM.OnEquip`, edit (or add) `wep.UseColor`:
```lua
ITEM.OnEquip = function( wep )

wep.UseColor = Color( 0, 255, 0 )

end
```

## Setting Blade Type (kb/51) / Setting The Blade Type Of An Item (kb/73)
Method 1 — a weapon (`lua/weapons/`): add or edit
```lua
SWEP.CustomSettings =
{
Blade = "Corrupted",
}
```
Method 2 — an item (`lua/wos/advswl/crafting/items`), inside `OnEquip`:
```lua
ITEM.OnEquip = function( wep )
wep.CustomSettings[ "Blade" ] = "Corrupted"
wep.UseColor = Color( 0, 0, 255 )
end
```
Blade types: Standard, Unstable, Corrupted, Pulsed, Pervasive, Saw Tooth, Mastered, Smithed, Dark Saber, Cyclic Invert, Swirl.
