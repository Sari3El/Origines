# ALCS — fiches générales

Source : https://support.wiltostech.com/knowledgebase/15/Advanced-Lightsaber-Combat-System

---

## Controls (kb/55)

### Changing Stance
"To change stance, hold down your USE key and press PRIMARY FIRE. You will cycle through the stances you have available." Each stance provides its own directional attacks.

### Changing Form
"Each form has a unique play style described by it's name. To open the form menu, hold down your USE key and press RELOAD." Users can select from available forms via the menu.
Each form includes 3 stances and 1 unique heavy attack.

### Light Attacks
"Sabers have 3 directional attacks. Move left, right, or forward and press PRIMARY ATTACK to do a different directional attack."

### Heavy Attacks
"Hold down your USE key and press ( or hold ) ALTERNATE FIRE to perform a heavy attack." Increased damage, longer execution time (vulnerability).

### Blocking
"Hold down your WALK key ( ALT by default ) to shift to a blocking pose." Blocks saber damage and deflects projectiles when attacks come from the front.
"Blocking will drain your Force/Stamina after success. Heavy attacks may break your block if you do not have enough energy left to block it."

### Aerial Attacks
Jump while holding a directional key and attack. "You will have to regain your balance after landing from an attack."

### Parrying
Parry while blocking by pressing PRIMARY FIRE as an attack lands. Costs more energy; cannot defend against heavy attacks.

### Force Powers
- **Newage/Classic HUD** : F, then the number of the power
- **Force Menu** : F and click the power
- **Hybrid Menu** : Walk + F to configure active powers, then F + number keys

### Devastators
"Change devastators by holding your WALK (Default Left Alt) key and pressing RELOAD." Requires 100 % overcharge (Meditation or Channel Hatred), then WALK + SECONDARY FIRE while ignited.

---

## Force Powers (kb/178)

### Default force powers
| Name | Description |
|---|---|
| Force Leap | Jump longer and higher. Aim higher to jump higher/further. |
| Charge | Lunge at your enemy |
| Force Absorb | Hold Mouse 2 to protect yourself from harm |
| Saber Throw | Throws your lightsaber. It will return to you. |
| Force Heal | Heals your target. |
| Group Heal | Heals all around you. |
| Cloak | Shrowd yourself with the force for 10 seconds |
| Force Reflect | An eye for an eye |
| Rage | Unleash your anger |
| Shadow Strike | From the darkness it preys |
| Force Pull | Get over here! |
| Force Push | They are no harm at a distance |
| Lightning Strike | A focused charge of lightning |
| Advanced Cloak | Shrowd yourself with the force for 25 seconds |
| Force Lightning | Torture people ( and monsters ) at will. |
| Force Combust | Ignite stuff infront of you. |
| Force Repulse | Hold to charge for greater distance/damage. Push back everything near you. |
| Storm | Charge for 2 seconds, unleash a storm on your enemies |
| Meditate | Relax yourself and channel your energy |
| Channel Hatred | I can feel your anger |

### Dark Ascension Pack
| Name | Description |
|---|---|
| Overdrive Beam | Release your focused energy |
| Lightning Stream | An endless stream of lightning |
| Burn Out | Fire and flames engulf your victim |
| Vitriolic Discharge | Release their inner poisons onto them |
| Crippling Slam | Earth shattering slams immobilize those in your path |
| Blood Sacrifice | Focus your inner energy through blood |
| Energetic Shell | Convert their negativity into your power |
| Diamond Storm | Turn the air around you into shards of destruction |
| Attract | Let the world attack your enemy |

### Icefuse Pack
| Name | Description |
|---|---|
| Force Blind | Make your escape or final blow. |
| Adrenaline | Be quick to the draw |
| Force Slow | Cloud your victim's mind |
| Force Stasis | Let their fear stop them |
| Group Pull | Get over here! |
| Group Push | They are no harm at a distance |
| Group Lightning | Send a jolt to wake up groups of victims. |
| Electric Judgement | The truth can blind us all. |
| Force Whirlwind | That which you harness is all around you |
| Force Breach | Make a path |
| Teleport | Phase through to a new location. |
| Destruction | Hold to unleash true power on your enemies |
| Force Choke | I find your lack of faith disturbing |
| Group Choke | Choke them all |
| Saber Barrier | The ultimate defense. |

---

## How To Disable The WiltOS Chat Advertisement (kb/61)
1. Navigate to `lua/wos/advswl/config/general/sh_serverwos.lua`
2. Find the `wOS.ALCS.Config.AdvertTime` value
3. Set it equal to false

```lua
wOS.ALCS.Config.AdvertTime = false
```

---

## Installation and Configuration (kb/9)

### Section One: Preparing Your Server
- Get the Advanced Lightsaber Content Package from the Steam Workshop
- Get all required content included in that addon (excluding gExplo, which is a client file)

### Section Two: Preparing Your Clients
Clients need the content package and all required items. If users see T-Pose, restart the game and check for conflicting animation addons.

### Section Three: Installing the Addon and Configuring Essentials
1. Download the DLL from the package page
2. Drag and drop the DLL to the server's root `lua/bin` folder (according to your OS)
3. Download and extract your package
4. Place the extracted folder into your addons folder
5. Navigate to `lua/wos/advswl/config` in the addon
6. Configure all files in the character, crafting, general, lightsaber and skills directories

Forms are in `lua/wos/advswl/forms`.

### Section Four: Creating Custom Lightsabers (Part A)
1. Copy any `weapon_lightsaber_***` lua file from the weapons folder
2. Paste it in the same folder with a unique name (e.g. `weapon_lightsaber_vanguard`)
3. Edit the entries below the "Things you will edit" line
4. Save and spawn it in-game (Lightsaber category)

| Entry | Meaning |
|---|---|
| `SWEP.PrintName = "STRING"` | Display name in weapon selection |
| `SWEP.Class = "STRING"` | File name of the weapon (e.g. "weapon_lightsaber_vanguard") |
| `SWEP.DualWielded = BOOLEAN` | Dual wielded (one in each hand) |
| `SWEP.CanMoveWhileAttacking = BOOLEAN` | Can move while swinging (default off) |
| `SWEP.SaberDamage = NUMBER` | Swing damage; heavy attacks do 1.5x this value |
| `SWEP.SaberBurnDamage = NUMBER` | Contact damage when running into the blade while idle |
| `SWEP.MaxForce = NUMBER` | Maximum force energy (blue bar) |
| `SWEP.RegenSpeed = NUMBER` | Force regen multiplier (0.5 = half, 2 = double) |
| `SWEP.CanKnockback = BOOLEAN` | Hits knock opponents back |
| `SWEP.ShouldStun = BOOLEAN` | Hits stun opponents momentarily |
| `SWEP.BlockDrainRate = NUMBER` | Force lost per tick while blocking (0.01–0.5); loss per second = NUMBER/TICKRATE |
| `SWEP.FirstPerson = BOOLEAN` | Starts in first person (toggle: `wos_togglefirstperson`) |
| `SWEP.ForcePowerList = { "STRING1", ... }` | Force powers (names in `lua/wos/advswl/forcepowers/wos_forcematerialbuilding.lua`) |
| `SWEP.DevestatorList = { "STRING1", ... }` | Devastators (names in `lua/wos/advswl/devestators/wos_devmaterialbuilding.lua`; needs Meditation/Channel Hatred) |
| `SWEP.UseSkills = BOOLEAN` | Inherits properties from the user's skill trees |
| `SWEP.PersonalLightsaber = BOOLEAN` | Inherits properties from the crafting bench (NOT RECOMMENDED) |

### Section Five: Creating Custom Lightsabers (Part B) — overriding tool gun settings
| Entry | Meaning |
|---|---|
| `SWEP.UseModel = "STRING" \|\| false` | Force a hilt model, or use tool gun option |
| `SWEP.UseLength = NUMBER \|\| false` | Blade length |
| `SWEP.UseWidth = NUMBER \|\| false` | Blade width |
| `SWEP.UseColor = Color( R, G, B ) \|\| false` | Blade color |
| `SWEP.UseDarkInner = NUMBER \|\| false` | Inner blade (1 = dark, 0 = white) |
| `SWEP.UseLoopSound = "STRING" \|\| false` | Humming sound path |
| `SWEP.UseSwingSound = "STRING" \|\| false` | Swing sound path |
| `SWEP.UseOnSound = "STRING" \|\| false` | Ignition sound path |
| `SWEP.UseOffSound = "STRING" \|\| false` | Extinguish sound path |
| `SWEP.UseSecHilt = "STRING" \|\| false` | Secondary hilt (dual wield off-hand) |
| `SWEP.UseSecLength = NUMBER \|\| false` | Secondary length |
| `SWEP.UseSecColor = Color( R, G, B ) \|\| false` | Secondary color |
| `SWEP.UseSecDarkInner = NUMBER \|\| false` | Secondary inner blade |

### Section Six: Creating Custom Lightsabers (Part C) — forms
`SWEP.UseForms = { [ "STRING FORM NAME 1" ] = { NUMBER_STANCE1, NUMBER_STANCE2, ... }, ... }` — forms and stances available regardless of usergroup (form names in `sh_swlwos.lua`); `false` = default restrictions.

```lua
SWEP.UseForms = { [ "Defensive" ] = { 2, 3 }, }
SWEP.UseForms = { [ "Defensive" ] = { 1, 2, 3 }, [ "Aggressive" ] = { 1, 3 }, }
```
Dual wield forms won't work on single lightsabers and vice versa.

### Section Seven: Creating Custom Forms and Stances
Form files go in `lua/wos/advswl/forms/` (e.g. `addons/ADDON_FOLDER_NAME/lua/wos/advswl/forms/EXAMPLE_FORM.lua`).

```lua
local FORM = {}

FORM.Name = "EXAMPLE FORM"

-- Who does this form belong to? Options: FORM_SINGLE, FORM_DUAL, FORM_BOTH
-- FORM_SINGLE: single wielded sabers only
-- FORM_DUAL: dual wielded sabers only (one in each hand)
-- FORM_BOTH: either wielding technique
FORM.Type = FORM_SINGLE

-- What user groups can use this form and which stances?
-- FORMAT: ["USERGROUP NAME"] = { STANCE1, STANCE2, STANCE3, ... },
-- DO NOT FORGET COMMAS AFTER EACH USERGROUP ENTRY!
FORM.UserGroups = {
    ["superadmin"] = { 1, 2, 3 },
}

FORM.Stances = {}
FORM.Stances[1] = {
    [ "run" ] = "",
    [ "idle" ] = "",
    [ "light_left" ] = {
        Sequence = "",
        Time = nil,
        Rate = nil,
    },
    [ "light_right" ] = {
        Sequence = "",
        Time = nil,
        Rate = nil,
    },
    [ "light_forward" ] = {
        Sequence = "",
        Time = nil,
        Rate = nil,
    },
    [ "air_left" ] = {
        Sequence = "",
        Time = nil,
        Rate = nil,
    },
    [ "air_right" ] = {
        Sequence = "",
        Time = nil,
        Rate = nil,
    },
    [ "air_forward" ] = {
        Sequence = "",
        Time = nil,
        Rate = nil,
    },
    [ "heavy" ] = {
        Sequence = "",
        Time = nil,
        Rate = nil,
    },
    [ "heavy_charge" ] = "",
}

wOS:RegisterNewForm( FORM )
```

- `FORM.Name` : display name, unique across all forms
- `FORM.Type` : FORM_SINGLE / FORM_DUAL / FORM_BOTH
- `FORM.UserGroups` : usergroups (case-sensitive) and the stances they can use; only list stances that exist
- `FORM.Stances[N]` : one table per stance, numbered from 1. Per attack type:

```
[ "TYPE OF ATTACK" ] = {
    Sequence = "SEQUENCE STRING",
    Time = TIME THE ANIMATION WILL PLAY,
    Rate = HOW FAST THE ANIMATION WILL PLAY,
},
```
- Sequence : from the wiltOS Viewer widget (wiltOS Animation Base)
- Time : seconds; nil = sequence default
- Rate : 0.5 = half, 2 = double; nil = sequence default
- Do NOT add new attack types: only the entries above, or errors will occur.

Example — Aggressive form:
```lua
local FORM = {}

FORM.Name = "Aggressive"

FORM.Type = FORM_SINGLE

FORM.UserGroups = {
    ["user"] = { 1 },
    ["jedi"] = { 1, 2, 3 },
}

FORM.Stances = {}

FORM.Stances[1] = {
    [ "run" ] = "phalanx_r_run",
    [ "idle" ] = "phalanx_r_idle",
    [ "light_left" ] = { Sequence = "phalanx_r_left_t3", Time = 0.5, Rate = nil, },
    [ "light_right" ] = { Sequence = "phalanx_r_right_t3", Time = 0.7, Rate = nil, },
    [ "light_forward" ] = { Sequence = "phalanx_r_s1_t2", Time = nil, Rate = nil, },
    [ "air_left" ] = { Sequence = "phalanx_a_left_t1", Time = 0.6, Rate = 1.6, },
    [ "air_right" ] = { Sequence = "phalanx_a_right_t1", Time = 0.6, Rate = 1.7, },
    [ "air_forward" ] = { Sequence = "phalanx_a_s1_t1", Time = 0.6, Rate = 1.2, },
    [ "heavy" ] = { Sequence = "phalanx_b_s1_t1", Time = 2.0, Rate = 0.5, },
    [ "heavy_charge" ] = "phalanx_b_s4_charge",
}

FORM.Stances[2] = {
    [ "run" ] = "phalanx_b_run",
    [ "idle" ] = "phalanx_b_idle",
    [ "light_left" ] = { Sequence = "phalanx_b_left_t3", Time = 1.0, Rate = nil, },
    [ "light_right" ] = { Sequence = "phalanx_b_right_t2", Time = 0.7, Rate = nil, },
    [ "light_forward" ] = { Sequence = "phalanx_b_s2_t3", Time = 0.8, Rate = nil, },
    [ "air_left" ] = { Sequence = "phalanx_a_left_t1", Time = 0.6, Rate = 1.6, },
    [ "air_right" ] = { Sequence = "phalanx_a_right_t1", Time = 0.6, Rate = 1.7, },
    [ "air_forward" ] = { Sequence = "phalanx_a_s1_t1", Time = 0.6, Rate = 1.2, },
    [ "heavy" ] = { Sequence = "phalanx_b_s1_t1", Time = 2.0, Rate = 0.5, },
    [ "heavy_charge" ] = "phalanx_b_s4_charge",
}

FORM.Stances[3] = {
    [ "run" ] = "phalanx_h_run",
    [ "idle" ] = "phalanx_h_idle",
    [ "light_left" ] = { Sequence = "phalanx_b_s2_t1", Time = nil, Rate = nil, },
    [ "light_right" ] = { Sequence = "phalanx_h_right_t1", Time = nil, Rate = nil, },
    [ "light_forward" ] = { Sequence = "phalanx_h_s1_t1", Time = 1.2, Rate = nil, },
    [ "air_left" ] = { Sequence = "phalanx_a_left_t1", Time = 0.6, Rate = 1.6, },
    [ "air_right" ] = { Sequence = "phalanx_a_right_t1", Time = 0.6, Rate = 1.7, },
    [ "air_forward" ] = { Sequence = "phalanx_a_s1_t1", Time = 0.6, Rate = 1.2, },
    [ "heavy" ] = { Sequence = "phalanx_b_s1_t1", Time = 2.0, Rate = 0.5, },
    [ "heavy_charge" ] = "phalanx_b_s4_charge",
}

wOS:RegisterNewForm( FORM )
```

---

## New DRM Info (kb/47)
The DLLs are required for the system to work at all.
1. Go to the server's main directory (the one with addons, backgrounds, bin, cfg, data…)
2. Go to `lua/bin` (create `bin` if it does not exist)
3. Drop the DLL for your OS: `gmsv_wos_crypt_win32.dll` (Windows), `gmsv_wos_crypt_linux.dll` (Linux). If unsure, put both.

---

## New Wiki! (kb/181)
"Checkout the New Wiki for Up To Date articles! https://wiki.wiltostech.com/3/ALCS"

---

## Packages (kb/17)
**Padawan ($50)** : custom animation framework synced server/client (better hitboxes/prediction), wiltOS animation extensions, Blade Symphony support; 3 forms (1 heavy, 3 aerial, 3 stances × 3 directional = 39 attacks); directional blocking and bullet deflection; dual wield with per-blade/hilt customization; optional stamina; optional hilt restriction by usergroup and team/DarkRP job; reactive animations; force powers (Group Heal, Cloaking, Charge, Shadow Strike, Meditation, Storm, Lightning Strike, Force Push, Force Pull, Saber Throw, Rage, Force Reflect); SWTOR icons; force selection menu (> 11 powers); modular base; hilt-on-belt for several sabers; basic crafting bench.
**Warrior ($80)** : everything above + first person combat; Versatile form (staffsaber); Devastator system (Kyber Slam, Sonic Discharge, Lightning Coil); parry / counter attack by timing; charged heavy attacks (break parries); Channel Hatred; per-limb reactive animations; form creation system; minimalism mode for high capacity servers; more config.
**Sentinel ($130)** : everything above + lifetime support; "Calm of Fate" update: skill tree system (3 trees + template), combat leveling, crafting system (items, lightsaber creation/upgrade), inventory with MySQL, proficiency system (saber levels, attachment slots).
Upgrades : Padawan → Sentinel $80, Warrior → Sentinel $50.

---

## Required Content (kb/10)
Mount all addons of this collection on the server: https://steamcommunity.com/sharedfiles/filedetails/?id=1730294988
(or add it to the server's collection so it updates automatically).
