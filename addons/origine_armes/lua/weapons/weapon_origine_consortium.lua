--[[-------------------------------------------------------------------
	Origine du monde — Lame du Consortium (Consortium (banquiers, courtiers, Lames))

	Copie du sabre wOS « weapon_lightsaber_wos.lua » (dossier lua/weapons/ d'ALCS),
	sur la base wOS Lightsaber (Robotboy655 + King David, wiltOS Technologies).
	Manche simple, lame invisible qui garde sa portée, aucun effet de sabre laser.

	Nom d'affichage provisoire : il se change ci-dessous (SWEP.PrintName).
	Pour la remplacer par une vraie épée : voir LISEZMOI.txt (point d'attache blade1).
---------------------------------------------------------------------]]

AddCSLuaFile()

SWEP.Author = "Origine du monde (base wOS ALCS)"
SWEP.Category = "Origine Consortium Weapon"
SWEP.Contact = ""
SWEP.RenderGroup = RENDERGROUP_BOTH
SWEP.Slot = 0
SWEP.SlotPos = 5
SWEP.Spawnable = true
SWEP.AdminOnly = true
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.DrawWeaponInfoBox = false
SWEP.ViewModel = "models/weapons/v_crowbar.mdl"
SWEP.WorldModel = "models/sgg/starwars/weapons/w_common_jedi_saber_hilt.mdl"
SWEP.ViewModelFOV = 55
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = true
SWEP.Secondary.Ammo = "none"

------------------------------------------------------------ RÉGLAGES DE L'ARME -------------------------------------------------------------
SWEP.PrintName = "Lame du Consortium" -- Nom affiché (provisoire)
SWEP.Class = "weapon_origine_consortium" -- Nom du fichier de l'arme
SWEP.DualWielded = false -- Une seule arme en main
SWEP.CanMoveWhileAttacking = false -- Peut-on bouger en frappant ?

-- Combat (valeurs à équilibrer plus tard)
SWEP.SaberDamage = 60 -- Dégâts d'un coup (un coup lourd fait 1,5 fois plus)
SWEP.SaberBurnDamage = 0 -- Pas de brûlure au simple contact, comme une vraie lame
SWEP.CanKnockback = true -- Les coups repoussent l'adversaire
SWEP.ShouldStun = false -- Pas d'étourdissement : sa fenêtre d'invincibilité gênerait la mise à terre et les captures

-- Force (barre bleue de wOS) : réserve, recharge, perte en bloquant (valeurs à équilibrer plus tard)
SWEP.MaxForce = 100
SWEP.RegenSpeed = 1 -- Multiplicateur de recharge (0.5 = moitié, 2 = double)
SWEP.BlockDrainRate = 0.1 -- Force perdue par tick en bloquant

-- Pouvoirs
SWEP.ForcePowerList = { "Force Leap" } -- Saut de Force uniquement
SWEP.DevestatorList = {} -- Aucun ultime (pas de méditation)

-- Formes et postures : celles de la config wOS actuelle (en attendant un choix par faction)
SWEP.UseForms = false

-- Les arbres de compétences et l'atelier d'ALCS ne modifient pas cette arme
SWEP.UseSkills = false
SWEP.PersonalLightsaber = false

-- Manche (le même modèle simple pour les 4 armes) et lame
SWEP.UseHilt = "models/sgg/starwars/weapons/w_common_jedi_saber_hilt.mdl" -- Modèle du manche
SWEP.UseLength = 42 -- Longueur de la lame : invisible, mais la portée et les touches restent
SWEP.UseWidth = 1
SWEP.UseColor = Color( 0, 0, 0 ) -- Noir : la lumière dynamique de la lame n'éclaire rien
SWEP.UseDarkInner = 1
SWEP.CustomSettings = {}
SWEP.CustomSettings[ "Blade" ] = "Invisible" -- Type de lame créé par origine_armes (voir LISEZMOI.txt)

-- Sons : pas de bourdonnement, d'allumage ni d'extinction ; un son d'épée quand on frappe
SWEP.UseLoopSound = "origine_armes/silence.wav"
SWEP.UseOnSound = "origine_armes/silence.wav"
SWEP.UseOffSound = "origine_armes/silence.wav"
SWEP.UseSwingSound = "origine_armes/epee_swing.wav"

-- Seconde arme (double maniement) : non utilisée
SWEP.UseSecHilt = false
SWEP.UseSecLength = false
SWEP.UseSecWidth = false
SWEP.UseSecColor = false
SWEP.UseSecDarkInner = false
------------------------------------------------------------ FIN DES RÉGLAGES -------------------------------------------------------------

if not SWEP.DualWielded then
	SWEP.Base = "wos_adv_single_lightsaber_base"
else
	SWEP.Base = "wos_adv_dual_lightsaber_base"
end

-- Commun aux armes Origine : cooldown pour le sélecteur, pas d'icône de sabre laser
if ORIGINE and ORIGINE.Armes then ORIGINE.Armes.Preparer(SWEP) end

if CLIENT then
	killicon.Add( SWEP.Class, "lightsaber/lightsaber_killicon", color_white )
end
