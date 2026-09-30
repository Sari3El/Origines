# ALCS — Skills (arbres de compétences, niveaux, XP)

## Configure Max Level (kb/67)
`lua/wos/advswl/config/skills/sh_skillwos.lua` — `SkillMaxLevel` = max level (false = infinite):
```lua
wOS.ALCS.Config.Skills.SkillMaxLevel = 150
```

## Configure Skill Point Gain (kb/66)
`lua/wos/advswl/config/skills/sv_skillwos.lua`
- `LevelsPerSkillPoint` — levels needed before getting skill points
- `SkillPointPerLevel` — skill points received each time
```lua
wOS.ALCS.Config.Skills.LevelsPerSkillPoint = 1

wOS.ALCS.Config.Skills.SkillPointPerLevel = 2
```

## How To Configure XP Gain (kb/65)
`lua/wos/advswl/config/skills/sv_skillwos.lua`, paste at the bottom (one block per usergroup):
```lua
wOS.ALCS.Config.Skills.ExperienceTable[ "RankHere" ] = {

Meditation = 0,

PlayerKill = 0,

NPCKill = 0,

XPPerInt = 0,

XPPerHeal = 0,

}
```
- Meditation — XP each time the player meditates
- PlayerKill — XP for killing a player
- NPCKill — XP for killing an NPC
- XPPerInt — XP for playing; interval = `wOS.ALCS.Config.Skills.TimeBetweenXP` (seconds)
- XPPerHeal — XP each time the player heals another player
```lua
wOS.ALCS.Config.Skills.ExperienceTable[ "vip" ] = {

Meditation = 15,

PlayerKill = 50,

NPCKill = 10,

XPPerInt = 150,

XPPerHeal = 2,

}
```
Give XP by code: `ply:AddSkillXP( number )` (see 03_administration.md).

## Changing Proficiency XP Gained From Killing Players And NPCS (kb/59)
File given as `lua/advswl/config/crafting/sv_craftwos.lua` (en pratique `lua/wos/advswl/config/crafting/sv_craftwos.lua`).
Near the bottom (copy one block per usergroup):
```lua
wOS.ALCS.Config.Crafting.SaberExperienceTable[ "superadmin" ] = {

PlayerKill = 60,

NPCKill = 15,

}
```
```lua
wOS.ALCS.Config.Crafting.SaberExperienceTable[ "owner" ] = {

PlayerKill = 120,

NPCKill = 10,

}
```

## Configure Proficiency Leveling (kb/64)
`lua/wos/advswl/config/crafting/sh_craftwos.lua`
- `SaberMaxLevel` — max proficiency level (default false = infinite)
- `LevelPerSlot` — proficiency levels needed for each misc item slot on the saber (default 1)
```lua
wOS.ALCS.Config.Crafting.SaberMaxLevel = 25

wOS.ALCS.Config.Crafting.LevelPerSlot = 5
```

## Disabling Level HUD (kb/20)
`lua/wos/advswl/config/skills/sh_skillwos.lua`
```lua
wOS.ALCS.Config.Skills.MountLevelToHUD = false      -- XP/Level bar on your own screen
wOS.ALCS.Config.Skills.MountLevelToPlayer = false   -- "Combat Level" above other players' heads
```

## Skill Tree Template File (kb/8)
"Create a lua file with the name of your skill tree" in `lua/wos/advswl/skills/trees`. "NAMES MUST BE UNIQUE!"
"entries and functions may be added later, but these are options that are set in stone."
Template: https://pastebin.com/QnUBqCtt (copie : `modele_arbre_competences_ancien.lua`, ancien format des Requirements).

## Creating A Skill Tree (kb/54)
Part 1: create a `.lua` file in `lua/wos/advswl/skills/trees` (e.g. `exampletree.lua`) and paste
https://pastebin.com/Ny76FhpP (copie : `modele_arbre_competences.lua`).

Part 2: basic config
```lua
local TREE = {}

--Name of the skill tree
TREE.Name = "Ravager"

--Description of the skill tree
TREE.Description = "Master the blade, not the mind"

--Icon for the skill tree ( Appears in category menu and above the skills )
TREE.TreeIcon = "wos/skilltrees/ravager/main.png"

--What is the color for the background of skill icons
TREE.BackgroundColor = Color( 255, 0, 0 )

--How many tiers of skills are there?
TREE.MaxTiers = 3

--Add user groups that are allowed to use this tree. If anyone is allowed, set this to FALSE ( TREE.UserGroups = false )
TREE.UserGroups = { "vip", "superadmin" }

--Add user groups that are allowed to use this tree. If anyone is allowed, set this to FALSE ( TREE.UserGroups = false )
TREE.JobRestricted = { "TEAM_ONE", "TEAM_TWO" }

TREE.Tier = {}
```
- `TREE.Name` — unique (otherwise errors); shown in the Character Skill Station
- `TREE.Description` — sub-text under the name (not unique)
- `TREE.TreeIcon` — icon shown on the 3D cube
- `TREE.BackgroundColor` — RGB background of the tree
- `TREE.MaxTiers` — number of tiers (rows); update it if you add tiers
- `TREE.UserGroups` — allowed usergroups; false = everyone
- `TREE.JobRestricted` — allowed DarkRP jobs; false = everyone

Part 3: skills and tiers
```lua
TREE.Tier[1] = {}
TREE.Tier[1][1] = {
    Name = "Strength",
    Description = "+50 Max Health",
    Icon = "wos/skilltrees/ravager/aid.png",
    PointsRequired = 1,
    Requirements = {},
    LockOuts = {
        [1] = { 2 }
    },
    OnPlayerSpawn = function( ply )
        ply:SetMaxHealth( ply:GetMaxHealth() + 50 )
    end,
    OnPlayerDeath = function( ply ) end,
    OnSaberDeploy = function( wep ) end,
}

TREE.Tier[1][2] = {
    Name = "Combatant",
    Description = "Adds 30 base damage to your lightsaber",
    Icon = "wos/skilltrees/ravager/comb.png",
    PointsRequired = 1,
    Requirements = {},
    OnPlayerSpawn = function( ply ) end,
    OnPlayerDeath = function( ply ) end,
    OnSaberDeploy = function( wep )
        wep.SaberDamage = wep.SaberDamage + 30
    end,
}

TREE.Tier[2] = {}
TREE.Tier[2][1] = {
    Name = "Tormented Soul",
    Description = "Learn to use your rage as a weapon",
    Icon = "wos/skilltrees/ravager/tormented_soul.png",
    PointsRequired = 1,
    Requirements = {
        [1] = { 2 },
    },
    OnPlayerSpawn = function( ply ) end,
    OnPlayerDeath = function( ply ) end,
    OnSaberDeploy = function( wep )
        wep:AddForcePower( "Rage" )
    end,
}

TREE.Tier[3] = {}
TREE.Tier[3][1] = {
    Name = "Final Blow",
    Description = "Release an explosion when you die",
    Icon = "wos/skilltrees/ravager/phoenix.png",
    PointsRequired = 1,
    Requirements = {
        [2] = { 1 },
    },
    OnPlayerSpawn = function( ply ) end,
    OnPlayerDeath = function( ply )
        util.BlastDamage( ply:GetActiveWeapon(), ply, ply:GetPos(), 25, 100 )
    end,
    OnSaberDeploy = function( wep ) end,
}
```
(le fichier se termine par `wOS:RegisterSkillTree( TREE )`)

- `TREE.Tier[N] = {}` is required before each tier, otherwise it errors
- `TREE.Tier[tier][slot]` — the skill created first in a tier is further left
- `Name`, `Description` — shown when the skill is clicked
- `PointsRequired` — skill points taken on purchase (nothing taken if not enough)
- `Requirements` — skills needed first: `[tier] = { skill }` (e.g. `[2] = { 1 }` requires "Tormented Soul" before "Final Blow")
- `LockOuts` — skills locked after buying this one (buying "Strength" locks "Combatant")
- `OnPlayerSpawn`, `OnPlayerDeath`, `OnSaberDeploy` — run on these events if the player has the skill
  (`OnSaberDeploy` needs a skill-enabled saber: `SWEP.UseSkills = true`; the template says `SWEP.UsePlayerSkills`)

Effect examples (verbatim):
```lua
OnPlayerSpawn = function( ply ) ply:SetMaxHealth( ply:GetMaxHealth() + 50 ) ply:SetHealth(ply:Health() + 50) end,
OnPlayerSpawn = function( ply ) ply:SetArmor( ply:Armor() + 25 ) end,
OnPlayerSpawn = function( ply ) ply:SetRunSpeed( ply:GetRunSpeed() + 50 ) end,
OnSaberDeploy = function( wep ) wep:SetMaxForce( wep:GetMaxForce() + 5 ) end,
OnSaberDeploy = function( wep ) wep.SaberDamage = wep.SaberDamage + 10 end,
OnSaberDeploy = function( wep ) wep.SaberBurnDamage = wep.SaberBurnDamage + 10 end,
OnSaberDeploy = function( wep ) wep:AddForm( "Aggressive", 1 ) end,
OnSaberDeploy = function( wep ) wep:AddForcePower( "Force Pull" ) end,
OnSaberDeploy = function( wep ) wep.BlockDrainRate = wep.BlockDrainRate*0.75 end,
OnPlayerDeath = function( ply ) local effectdata = EffectData() effectdata:SetOrigin( ply:GetPos() ) util.Effect( "HelicopterMegaBomb", effectdata ) ply:EmitSound( "weapons/explode3.wav" ) util.BlastDamage( ply, ply, ply:GetPos(), 50, 100 )  end,
OnPlayerSpawn = function( ply) ply.CanUseDuals = true end,
OnPlayerSpawn = function( ply) ply:Give("weapon_stunstick") end,
```
