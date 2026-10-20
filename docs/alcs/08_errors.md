# ALCS — Errors (erreurs connues)

## Character/Saber Crafting Station Menus Don't Work (kb/52)
Mount these addons on the server:
- [wOS] Advanced Lightsaber Combat (Content Pack) — https://steamcommunity.com/sharedfiles/filedetails/?id=1102570708
- [wOS] Animation Extension - Base — https://steamcommunity.com/sharedfiles/filedetails/?id=757604550
- [wOS] Animation Extension - Blade Symphony — https://steamcommunity.com/sharedfiles/filedetails/?id=848953359
- [wOS] Animation Extension - Riddick — https://steamcommunity.com/sharedfiles/filedetails/?id=1125980817
- Star Wars Lightsabers — https://steamcommunity.com/sharedfiles/filedetails/?id=111412589
- Star Wars Lightsabers Extension — https://steamcommunity.com/sharedfiles/filedetails/?id=671544612
- Star Wars Prop Pack — https://steamcommunity.com/sharedfiles/filedetails/?id=742660522
- Clone Wars Adventures: Lightsabers — https://steamcommunity.com/sharedfiles/filedetails/?id=866341452
- gExplo — https://steamcommunity.com/sharedfiles/filedetails/?id=871426788
- Placeable Particle Effects — https://steamcommunity.com/sharedfiles/filedetails/?id=1551310214
- Revan Dark Lightsaber Pack — https://steamcommunity.com/sharedfiles/filedetails/?id=106798118
- zz [SL] Anti Adware — https://steamcommunity.com/sharedfiles/filedetails/?id=1881093005
- Inquisitor Saber [Model] — https://steamcommunity.com/sharedfiles/filedetails/?id=1333011098
- [wOS] Inquisitor Hilt Ability Extension — https://steamcommunity.com/sharedfiles/filedetails/?id=2089095556
- Gargantuan SWTOR Prop Pack — https://steamcommunity.com/sharedfiles/filedetails/?id=2102911039

## I Rubberband When Swinging My Lightsaber (kb/5)
"Your server's tickrate is below the recommended amount of 33 with saber lunging enabled, raise the server's
tickrate, or see the following article to disable lunging" (kb/62 : `wOS.ALCS.Config.EnableLunge = false`).

## I Still T-Pose After Getting The Content (kb/2)
Conflicting iAnim addon, most commonly Prone Mod. Disable all iAnim addons and reboot the server.

## Incorrect Lightsaber Animations Playing (kb/3)
"You have other animation extensions interfering with the original anim packs, try uninstalling extra content packs".

## My Force Powers Don't Work! (kb/11)
"There is usually only one problem here." — image "Do you have force power icons?" (i.e. if the force icons are
missing, it's a DRM / whitelist problem: the DLL is missing or the server IP isn't whitelisted). Links: submit a
ticket (https://wiltostech.com/secure/submitticket.php) and Whitelisting Issues (kb/12).

## Some Players Have Animations, And Some Don't! (kb/6)
1. The owner did not give form permissions to that rank (kb/68).
2. Personal lightsabers have no forms: set them in the personal lightsaber weapon file or unlock them through the
   skill tree (kb/54).

## Whitelisting Issues (kb/12)
Check whitelisted IPs: client area → Services (http://wiltostech.com/secure/clientarea.php?action=services) →
your package → Additional Information. To change IPs: submit a support ticket
(http://wiltostech.com/secure/submitticket.php) and wait for a response.

## Why Do I Crouch When Swinging My Lightsaber (kb/4)
The default RobotBoy lightsabers are installed: uninstall them and restart.

## Why Do I T-Pose When I Ignite My Lightsaber (kb/1)
Missing content files: subscribe to everything in Required Content (kb/10, collection 1730294988).

## Why Can't I Open My Force Menu (kb/18)
1. The lightsaber has no force powers attached (no force meter either).
2. A conflicting addon overwrites the hook, usually the old "Advanced Lightsaber Attack System"
   (http://steamcommunity.com/sharedfiles/filedetails/?id=919270611): remove it.
