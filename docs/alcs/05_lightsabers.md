# ALCS — Lightsabers (armes-sabres)

Les armes-sabres sont dans `lua/weapons/weapon_lightsaber_*.lua` (voir aussi 01_general.md, sections 4 à 7).

## Creating A Lightsaber Weapon (kb/40)
1. Navigate to `lua/weapons`
2. Open any premade "weapon_lightsaber" file and copy its content
3. Make a new file called "weapon_lightsaber_whateveryouwanthere" and paste all the content
4. Edit any of the values below the dotted lines
5. Save the file and restart your server

## Adding A Force Power To A Lightsaber Weapon (kb/45)
In the lightsaber (`lua/weapons`), edit `SWEP.ForcePowerList` (comma between names in quotes):
```lua
SWEP.ForcePowerList = { "Force Leap", "Force Pull"}
```

## Adding Forms To Lightsaber Weapons (kb/39)
Edit `SWEP.UseForms` — this example adds Aggressive stances 1 and 3 and Defensive 2:
```lua
SWEP.UseForms = {

["Aggressive"] = { 1, 3 },

["Defensive"] = { 2 },

}
```

## Allow Moving While Attacking For A Lightsaber Weapon (kb/25)
`SWEP.CanMoveWhileAttacking` : false = disabled, true = enabled.
```lua
SWEP.CanMoveWhileAttacking = true
```

## Changing The Hilt Of A Lightsaber Weapon (kb/42)
Find `UseHilt` and set it to the hilt model path. Tip: models are in the Q menu; right click one to copy its model path.

## Changing The Max Force Of A Lightsaber Weapon (kb/43)
```lua
SWEP.MaxForce = 150
```

## How To Change A Lightsaber's Damage (kb/41)
`SaberDamage` = damage of a swing, `SaberBurnDamage` = damage when walking into the blade.
```lua
SWEP.SaberDamage = 500

SWEP.SaberBurnDamage = 25
```

## Changing What Usergroups Can Use Forms (kb/68)
Method 1 — usergroups allowed ALL forms, whatever the form files say: `lua/wos/advswl/config/general/sh_swlwos.lua`
```lua
wOS.ALCS.Config.AllAccessForms = { "owner", "developer", "superadmin" }
```
Method 2 — per form, in `lua/wos/advswl/forms/<form>.lua`, `FORM.UserGroups` (which stances each group can use):
```lua
FORM.UserGroups = {
  ["vip"] = { 1, 2 },
  ["vip+"] = { 1, 2, 3 },
}
```

## Changing Wield and Grip Choices (kb/177)
Since the Dark Ascension update, players choose in the Character Hub (Skill Station) their combat preferences:
dual wield or not, reversed grip… A preference is only selectable if the player has access to it.

Force a grip from the SWEP (also usable in default crafting options / personal sabers, and in skill tree
`OnSaberDeploy` functions with `SWEP` replaced by `wep`):
```lua
SWEP.UseGrip = "GRIP NAME HERE" //Change GRIP NAME HERE with the name of the GRIP as it appears in the preferences menu
```
Give access through skill trees [Warrior+]:
```lua
OnPlayerSpawn = function( ply )
       ply.WOS_AvailableGrips[ "GRIP NAME HERE" ] = true //Change GRIP NAME HERE with the name of the GRIP as it appears in the preferences menu
end
```
```lua
OnPlayerSpawn = function( ply )
       ply.CanUseDuals = true //Allows dual wielding
end
```
Free choice for everyone [Warrior+] in `wos/advswl/config/character/sv_config.lua` (only affects PERSONAL
LIGHTSABERS or SKILL TREE ENABLED LIGHTSABERS):
```lua
wOS.ALCS.Config.Character.FreeGripChoice = true //Allows a player to change their grips freely
```
```lua
wOS.ALCS.Config.Character.FreeWieldChoice = true //Allows a player to use dual wield freely
```

## Configure Hit Tracing (kb/75)
`lua/wos/advswl/config/lightsaber/sv_config.lua`, value `wOS.ALCS.Config.LightsaberTrace` :
- `WOS_ALCS.TRACE.CLASSIC` — Classic Rubat traces. Never stops tracing
- `WOS_ALCS.TRACE.MINIMAL` — Traces only when swinging/attacking; good for performance but removes burn damage and scorch
- `WOS_ALCS.TRACE.INTERP` — Trace travels the path of the lightsaber; precise but a little more intensive
- `WOS_ALCS.TRACE.MINIMALINTERP` — Same as INTERP, following MINIMAL rules; precision with a slightly reduced load
```lua
wOS.ALCS.Config.LightsaberTrace = WOS_ALCS.TRACE.CLASSIC
```

## Configuring Force Menu Visuals (kb/53)
`lua/wos/advswl/config/lightsaber/cl_config.lua`, value `wOS.ALCS.Config.LightsaberHUD` :
- `WOS_ALCS.HUD.NEWAGE` — "The newest standard. Circle Icons, slot-base, gradients, and more"
- `WOS_ALCS.HUD.CLASSIC` — Classic Rubat design with box focus
- `WOS_ALCS.HUD.FORCEMENU` — Simpler design with a force menu for changing force powers
- `WOS_ALCS.HUD.HYBRID` — "New age slot design with draggable force powers from the force menu"
```lua
wOS.ALCS.Config.LightsaberHUD = WOS_ALCS.HUD.NEWAGE
wOS.ALCS.Config.LightsaberHUD = WOS_ALCS.HUD.HYBRID
```
Max force slots (Hybrid only):
```lua
wOS.ALCS.Config.MaximumForceSlots = 9
```

## Configuring Stamina (kb/38)
`lua/wos/advswl/config/lightsaber/cl_config.lua` — disabled by default:
```lua
wOS.ALCS.Config.EnableStamina = false
wOS.ALCS.Config.StaminaAttackCost = 15
wOS.ALCS.Config.StaminaHeavyCost = 35
```
Example enabled: each normal swing costs 30, each heavy attack (hold USE + right click, then release) costs 50:
```lua
wOS.ALCS.Config.EnableStamina = true
wOS.ALCS.Config.StaminaAttackCost = 30
wOS.ALCS.Config.StaminaHeavyCost = 50
```

## How Do I Create My Own Blade Types (kb/58)
Add at the bottom of `lua/wos/advswl/lightsaber/blades/default_blades.lua`:
```lua
wOS.ALCS.LightsaberBase:AddBlade({

Name = "",

InnerMaterial = "",

EnvelopeMaterial = "",

UseParticle = false,

DrawTrail = false,

QuillonParticle = "",

QuillonInnerMaterial = "",

QuillonEnvelopeMaterial = "",

})
```
- Name — identifier, used when applying the blade to weapons or items
- InnerMaterial — inner core look
- EnvelopeMaterial — outer glow
- UseParticle — effect from `lua/effects`; false for none
- DrawTrail — blur trail when moving (true/false only)
- QuillonParticle — particles of quillon blades (aesthetic only, no damage); blank to disable
- QuillonInnerMaterial / QuillonEnvelopeMaterial — inner look / glow of quillon blades
```lua
wOS.ALCS.LightsaberBase:AddBlade({

Name = "Test Blade",

InnerMaterial = "wos/lightsabers/blades/cult",

EnvelopeMaterial = "wos/lightsabers/blades/cult_glow",

UseParticle = "wos_corrupted_burn",

DrawTrail = false,

QuillonParticle = "wos_unstable_discharge",

QuillonInnerMaterial = "wos/lightsabers/blades/cult",

QuillonEnvelopeMaterial = "wos/lightsabers/blades/cult_glow",

})
```

## How To Disable Force Power Icons (kb/71)
May give players a few extra frames (minimal). `lua/wos/advswl/config/general/sh_serverwos.lua`:
```lua
wOS.ALCS.Config.DisableForceIcons = true
```

## How To Disable Lunge (kb/62)
`lua/wos/advswl/config/general/sh_serverwos.lua`:
```lua
wOS.ALCS.Config.EnableLunge = false
```

## Setting Base Stats For Personal Lightsabers (kb/56)
File given as `lua/advswl/config/crafting/sh_craftwos.lua` (en pratique `lua/wos/advswl/config/crafting/sh_craftwos.lua`).
Right hand:
```lua
wOS.ALCS.Config.Crafting.DefaultPersonalSaber = {}
wOS.ALCS.Config.Crafting.DefaultPersonalSaber.UseHilt = "models/sgg/starwars/weapons/w_common_jedi_saber_hilt.mdl"
wOS.ALCS.Config.Crafting.DefaultPersonalSaber.UseLength = 32
wOS.ALCS.Config.Crafting.DefaultPersonalSaber.UseWidth = 2
wOS.ALCS.Config.Crafting.DefaultPersonalSaber.UseColor = Color( 255, 0, 0 )
wOS.ALCS.Config.Crafting.DefaultPersonalSaber.UseDarkInner = 0
wOS.ALCS.Config.Crafting.DefaultPersonalSaber.SaberDamage = 50
wOS.ALCS.Config.Crafting.DefaultPersonalSaber.SaberBurnDamage = 5
wOS.ALCS.Config.Crafting.DefaultPersonalSaber.UseInnerColor = color_white
wOS.ALCS.Config.Crafting.DefaultPersonalSaber.CustomSettings = {}
```
Left hand:
```lua
wOS.ALCS.Config.Crafting.DefaultSecPersonalSaber = {}
wOS.ALCS.Config.Crafting.DefaultSecPersonalSaber.UseHilt = "models/sgg/starwars/weapons/w_common_jedi_saber_hilt.mdl"
wOS.ALCS.Config.Crafting.DefaultSecPersonalSaber.UseLength = 32
wOS.ALCS.Config.Crafting.DefaultSecPersonalSaber.UseWidth = 2
wOS.ALCS.Config.Crafting.DefaultSecPersonalSaber.UseColor = Color( 255, 0, 0 )
wOS.ALCS.Config.Crafting.DefaultSecPersonalSaber.UseDarkInner = 0
wOS.ALCS.Config.Crafting.DefaultSecPersonalSaber.UseInnerColor = color_white
wOS.ALCS.Config.Crafting.DefaultSecPersonalSaber.SaberDamage = 50
wOS.ALCS.Config.Crafting.DefaultSecPersonalSaber.SaberBurnDamage = 5
wOS.ALCS.Config.Crafting.DefaultSecPersonalSaber.CustomSettings = {}
```
"These will be either changed completely, or modified whenever using items, skill tree upgrades, etc."

## Setting The Blade Type Of A Weapon (kb/74) / Setting Blade Type (kb/51)
In the weapon file:
```lua
SWEP.CustomSettings =
{
Blade = "Corrupted",
}
```
Blade types: Standard, Unstable, Corrupted, Pulsed, Pervasive, Saw Tooth, Mastered, Smithed, Dark Saber, Cyclic Invert, Swirl.
