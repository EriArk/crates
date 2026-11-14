# Bazaar 0.0.8 validation

14 November 2026. [Scope and research](../MOVEMENT_AND_MARKET.md).

Host checks: [seven animation states](animation.json), [NPC population/routes](population.json),
[world walkthrough](world.json). [Counter/visitor/NPC proportions](counter-proportions.png)
use a synthetic SDK avatar, not a personal profile. SDK-native project checks and
14 movement/collision assertions passed separately in the OctoFox SDK evidence.
The 12 slot approaches, clear cross route and 19 resident heights were checked.
Service menus retain the correct slot and disabled spending.

## Delivered on both handhelds

Bazaar 0.0.8 source `020635ada03063e8826c671fa190954815bc686b` is installed on
Flip 2 and Odin 2, opened through **Online → Bazaar → Festival Park** in shell
Software 45. [Export/package fingerprints](package.json). Linux ARM64/x86_64
and Windows exports passed; Windows gameplay was not tested.

The final [layout check](layout.txt) verifies all twelve counter fronts (+X),
seller fronts (+Z), approaches, spacing and NPC heights. Prop yaw is distinct
from actor yaw; the previous shared yaw was incorrect. The committed proportions
image reflects the corrected final layout.

Both devices showed their own avatar, corrected stalls and compact HUD. Remote
keyboard/pointer checks covered running, crouching, jumping, menu and normal
Leave back to the selected card. Odin additionally sampled sprint. Normal-exit
logs had no errors/warnings and no live game process remained. Forced host export
shutdown did produce fountain-audio resource warnings; that is not a normal-exit
acceptance result. Preferences were unchanged; old 0.0.7 remains for rollback.
Task staging and capture caches were cleaned. Personal captures remain private.
[Full shell/device record](https://github.com/EriArk/OctoFox-OS/blob/codex/bazaar-entry-device-20261114/docs/evidence/2026-11-14-bazaar-movement/README.md).

No merge, public release or spending activation.
Physical controls and sustained performance are not established by these checks.
