# Constitutional Amendments
## Features
* Adds tracking of individual values for HP gained at each level, automated modifications of HP based on constitution changes, and tracking adjustments to maximum HP.

* Added an option to indicate whether average hitpoints should be added when level or if they should be rolled.
* Added an option to toggle between displaying Wounds or Current Hit Points.
  * Inspired by the [Current HP](https://www.fantasygrounds.com/forums/showthread.php?44140-Current-HP-Extension-for-5E-Ruleset) extension created by Tielc and zuilin.

* Added a Heal action type to increase maximum HP.

* 6 new damage types have been added:
  * max: The target's maximum hitpoints are reduced by the damage dealt.
  * steal*: The attacker is healed for the damage dealt to the target.
  * hsteal: The attacker is healed for half of the damage dealt to the target.
  * stealtemp*: The attacker is gains temporary hitpoints equivalent to the damage dealt.
  * hstealtemp: The attacker is gains temporary hitpoints equivalent to half of the damage dealt.
  * transfer*: The damage is dealt to the attacker and the target is healed by the damage taken.
  * *If one of these damage types is followed by a [n] damage type, where n is any positive number, the secondary effect is scaled by n. E.g. steal, [0.5] is identical to hsteal.

* 2 new effects have been added: SHAREDMG: n, and SHAREHEAL: n, where n is any number.
  * Any damage or healing, respectively, that is recieved by a creature with one of these effects will be shared with another creature, in proportion with n.
  * When the effect is targeted, the target of the effect will receive the shared damage or healing.
  * Then the effect is not targeted, the applier of the effect will receive the shared damage or healing.

![Preview](images/ConstitutionalAmendments.png)

## Installation
Download [ConstitutionalAmendments.ext](https://github.com/MeAndUnique/ConstitutionalAmendments/raw/main/ConstitutionalAmendments.ext) and place in the extensions subfolder of the Fantasy Grounds data folder.

NOTE: Upon first loading, this extension will attempt to resolve each PC's current total hitpoints into individual rolls. If there is a discrepency detected a notification will be given upon opening the character sheet.
