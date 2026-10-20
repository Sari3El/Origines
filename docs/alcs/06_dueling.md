# ALCS — Dueling Spirits and Artifacts (esprits de duel et artefacts)

## General Information (kb/104, kb/106)
**Dueling Spirit** : "an item you can earn by sacrificing items or dueling opponents. Your spirit can earn
Sacrifice (similar to experience) which can eventually let you earn an Artifact."

Earning Sacrifice:
1. Duel opponents while the Dueling Spirit is active — most efficient; winning increases Sacrifice, losing can decrease it.
2. Sacrifice collected items — the rarer the item, the more Sacrifice.

**Artifacts** : "rewards obtained from levelling your Dueling Spirit. They can reward you with various bonuses,
such as skill tree passives, force powers, stat bonuses, and more."
Once the spirit has enough Sacrifice, you can ascend it. "Artifacts can be obtained once reaching the required
Ascension level with your Dueling Spirit." "When you ascend your spirit, you have a random chance to gain an
artifact. This chance is increased in relation to the amount of surplus energy you have stored in the spirit."
Example: a spirit needing 1 000 energy gives better odds if ascended at 1 200 (200 surplus).

Console: `wos_duelplacer_start` / `wos_duelplacer_end` to create a dueling arena.
Hook: `wOS.ALCS.Dueling.BlockDuel( challenger, victim, duelInfo )` → true to block a duel.

## Creating a Dueling Spirit (kb/107)
Defaults in `dueling/spirits/default_spirits.lua`; create yours in a new file under `/spirits/`.
```lua
wOS.ALCS.Dueling:RegisterSpirit({
    Name = "Soul of Lexia Z'oe", -- The name of the dueling spirit
    Description = "Once a noble fighter, the wisdom of Lexia Z'oe lives on and guides you towards greatness", -- The description of the dueling spirit
    RarityName = "Legendary", -- The spirit's rarity name
    RarityColor = Color( 150, 0, 250 ), -- The RGB color of the rarity
    SpiritModel = "models/spirits/lexia_zoe", -- Model path of the spirit
    DuelTitle = "Awakened", -- The title when player enters a duel
    TagLine = "Enlightened by the past", -- The tagline when player enters a duel
    Sequence = "Animation of the dueling spirit",
    ChallengeSound = "sounds/dueling/lexia_zoe_challenge", -- The sound that is played when player initiates a duel.
    VictorySound = "sounds/dueling/lexia_zoe_victory", -- The sound that is played when player wins a duel.
    MaxEnergy = 1000, -- The amount of energy needed to ascend this spirit
    StartingRoll = 25, -- The base number an artifact roll will start from
    PassiveLevel = 30, -- Level of spirit before the function effects apply (OnSpawn, OnThink, etc.)
    Rarity = 25, -- Rarity of Spirit
    DroppableArtifacts = {
        [ "Sigma's Superiority" ] = 100, -- Name of the artifact, and the number required to roll
    },
    OnDuelStart = function( ply ) end, -- Function to run when a duel has started.
    OnSpawn = function( ply ) end, -- Function to run when player spawns
    OnThink = function( ply ) end, -- Function to run each server tick
    OnDeath = function( ply ) end, -- Function to run when player dies
})
```

## Creating an Artifact (kb/108)
Defaults in `dueling/artifacts/default_artifacts.lua`; create yours in a new file under `/artifacts/`.
```lua
wOS.ALCS.Dueling.Artifact:RegisterArtifact({
    Name = "Sigma's Superiority", -- Name of the artifact
    Description = "Bask in the glory of the almighty Sigma", -- Description of the artifact
    RarityName = "Legendary", -- Rarity Name
    RarityColor = Color( 255, 125, 0 ), -- Rarity Color
    Model = "models/artifacts/sigmassuperiority", -- Artifact ModelID
    DropRequirement = 5, -- Ascension level required to drop this artifact
    OnSpawn = function( ply ) --
        ply:AddArtifactSkill( "Combat", 1, 1 ) -- Give a skill tree perk
        ply:SetMaxHealth( ply:GetMaxHealth() * 1.2 ) -- Increase their max health by 20%
        ply:SetHealth( ply:GetMaxHealth() ) -- Restore them to full health
    end,
})
```
