# Constitutional Amendments
## Features
* Adds tracking of individual values for HP gained at each level, automated modifications of HP based on constitution changes, and tracking adjustments to maximum HP.
 * Values can be seen and edited in the Class & Level window.
 * Manually changed class levels take effect after the control loses focus.
* Added an option to indicate whether average hitpoints should be added when level or if they should be rolled.
* Added an option to toggle between displaying Wounds or Current Hit Points.
  * Inspired by the [Current HP](https://www.fantasygrounds.com/forums/showthread.php?44140-Current-HP-Extension-for-5E-Ruleset) extension created by Tielc and zuilin.
* Added an option to control whether NPCs have extra health fields for hit dice and death saving throws.
  * This may also be specified on a per-NPC basis for any combatant on the CT by right clicking on their NPC sheet.

* Adjustments to constitution, both permanent and via effect will accordingly adjust HP.
* Added a Heal action type to increase maximum HP.
* Added fields to NPC sheets on the combat tracker for Wounds, Temp HP, HP Adjustment, Hit Dice, and Death Saves. And added an option to disable showing them.

* Support has been added for six new special damage types:
  * maxhp: The target's maximum hitpoints are reduced by the damage dealt.
  * steal*: The attacker is healed for the damage dealt to the target.
  * hsteal: The attacker is healed for half of the damage dealt to the target.
  * stealtemp*: The attacker is gains temporary hitpoints equivalent to the damage dealt.
  * hstealtemp: The attacker is gains temporary hitpoints equivalent to half of the damage dealt.
  * transfer*: The damage is dealt to the attacker and the target is healed by the damage taken.

   *If one of these damage types is followed by a 'n' damage type, where n is any positive number, the secondary effect is scaled by n. E.g. `steal, '0.5'` is identical to `hsteal`.

   For example a vampire's bite can be fully automated by updating the damage entry to the following: [DMG: 1d6+4 piercing + 3d6 necrotic, max, steal]. And the Life Transference spell can be automated using: 4d6 necrotic, transfer, '2'.

* Support has been added for **MAXHP: x**, which will adjust the total maximum hit points of the bearer by x, which can dice and numbers.

* Support has been added for **SHAREDMG: n**, and **SHAREHEAL: n**, where n is any number.
  * Any damage or healing, respectively, that is received by a creature with one of these effects will be shared with another creature, in proportion with n.
  * When the effect is targeted, the target of the effect will receive the shared damage or healing.
  * Then the effect is not targeted, the applier of the effect will receive the shared damage or healing.

  The Warding Bond spell can be automated with: AC: 1; SAVE: 1; RESIST: all; SHAREDMG: 1.

* Support has been added the following effects which apply to rolling hit dice to recover hp:
  * **HD: x max** - Adds x when the hit die is rolled, where x can be dice and numbers. The descriptor max will maximize the die roll.
  * **HDMULT: n** - Causes the result of a hit die roll to be multiplied by n, where n is any number. Note: extra dice add by HD effects are not multiplied, but extra flat numbers are.
  * **HDRECOVERY: n** - N additional hit die will be recovered on long rest.

* Abilities, Class Features, Ancestral Traits, and Feats can all be configured to grant hit points (as the Tough feat, for example). Simply right click on the name of the ability's window to enable and set the desired value in the field that is shown.

![Preview](.resources/ConstitutionalAmendments.png)

## Installation
Download [ConstitutionalAmendments.ext](https://github.com/MeAndUnique/ConstitutionalAmendments/releases) and place in the extensions subfolder of the Fantasy Grounds data folder.

NOTE: Upon first loading, this extension will attempt to resolve each PC's current total hitpoints into individual rolls. If there is a discrepency detected a notification will be given upon opening the character sheet.

## Attribution
SmiteWorks owns rights to code sections copied from their rulesets by permission for Fantasy Grounds community development.
'Fantasy Grounds' is a trademark of SmiteWorks USA, LLC.
'Fantasy Grounds' is Copyright 2004-2021 SmiteWorks USA LLC.

<div>Icons made by <a href="https://www.freepik.com" title="Freepik">Freepik</a> from <a href="https://www.flaticon.com/" title="Flaticon">www.flaticon.com</a></div>
<div>Icons made by <a href="https://www.flaticon.com/authors/smashicons" title="Smashicons">Smashicons</a> from <a href="https://www.flaticon.com/" title="Flaticon">www.flaticon.com</a></div>