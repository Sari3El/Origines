--[[-------------------------------------------------------------------
	Skill Tree Template:
		Create your own trees for a unique roleplaying experience!
			Powered by
						  _ _ _    ___  ____  
				__      _(_) | |_ / _ \/ ___| 
				\ \ /\ / / | | __| | | \___ \ 
				 \ V  V /| | | |_| |_| |___) |
				  \_/\_/ |_|_|\__|\___/|____/ 
											  
 _____         _                 _             _           
|_   _|__  ___| |__  _ __   ___ | | ___   __ _(_) ___  ___ 
  | |/ _ \/ __| '_ \| '_ \ / _ \| |/ _ \ / _` | |/ _ \/ __|
  | |  __/ (__| | | | | | | (_) | | (_) | (_| | |  __/\__ \
  |_|\___|\___|_| |_|_| |_|\___/|_|\___/ \__, |_|\___||___/
                                         |___/             
----------------------------- Copyright 2017, David "King David" Wiltos ]]--[[
							  
	Lua Developer: King David
	Contact: http://steamcommunity.com/groups/wiltostech
		
-- Copyright 2017, David "King David" Wiltos ]]--

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

TREE.Tier = {}

--Tier format is as follows:
--To create the TIER Table, do the following
--TREE.Tier[ TIER NUMBER ] = {} 
--To populate it with data, the format follows this
--TREE.Tier[ TIER NUMBER ][ SKILL NUMBER ] = DATA
--Name, description, and icon are exactly the same as before
--PointsRequired is for how many skill points are needed to unlock this particular skill
--Requirements prevent you from unlocking this skill unless you have the pre-requisite skills from the last tiers. If you are on tier 1, this should be {}
--OnPlayerSpawn is a function called when the player just spawns
--OnPlayerDeath is a function called when the player has just died
--OnSaberDeploy is a function called when the player has just pulled out their lightsaber ( assuming you have SWEP.UsePlayerSkills = true )


TREE.Tier[1] = {}
TREE.Tier[1][1] = {
	Name = "Strength",
	Description = "+50 Max Health",
	Icon = "wos/skilltrees/ravager/aid.png",
	PointsRequired = 1,
	Requirements = {},
	OnPlayerSpawn = function( ply ) ply:SetMaxHealth( ply:GetMaxHealth() + 50 ) end,
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
	OnSaberDeploy = function( wep ) wep.SaberDamage = wep.SaberDamage + 30 end,
	}

TREE.Tier[2] = {}
TREE.Tier[2][1] = {
	Name = "Tormented Soul",
	Description = "Learn to use your rage as a weapon",
	Icon = "wos/skilltrees/ravager/tormented_soul.png",
	PointsRequired = 1,
	Requirements = { 1, 2 },
	OnPlayerSpawn = function( ply ) end,
	OnPlayerDeath = function( ply ) end,
	OnSaberDeploy = function( wep ) wep:AddForcePower( "Rage" ) end,
	}

TREE.Tier[3] = {}
TREE.Tier[3][1] = {
	Name = "Final Blow",
	Description = "Release an explosion when you die",
	Icon = "wos/skilltrees/ravager/phoenix.png",
	PointsRequired = 1,
	Requirements = { 1 },
	OnPlayerSpawn = function( ply ) end,
	OnPlayerDeath = function( ply ) util.BlastDamage( ply:GetActiveWeapon(), ply, ply:GetPos(), 25, 100 )  end,
	OnSaberDeploy = function( wep ) end,
}

wOS:RegisterSkillTree( TREE )