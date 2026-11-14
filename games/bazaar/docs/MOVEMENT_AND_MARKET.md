# Bazaar 0.0.8 — shared locomotion and festival rows

14 November 2026. This increment replaces the game-owned retargeter with the
optional Godot SDK motor/animation module. `addons/traineros/SOURCE.json` pins its
upstream source and file hashes; `scripts/locomotion.gd` is only a compatibility
path for earlier review scripts. The player identity still comes from the local
host. The profile, bind matrices, skin weights and clothing assets are unchanged.

## Movement and proportions

The visitor uses a 1.8× world anchor, with matching 1.8 m standing collision and
camera framing. Each NPC is scaled uniformly by its original model bounds to
roughly 1.41–1.66 m. Their native rigs, colours and animation clips are preserved.
The stall canopy is 2.23 m high; its counter stays around waist level. The player
is taller than the counter, below the canopy, and slightly taller than residents.

Default full movement runs at 4.4 m/s. Light left-stick travel or Alt walks;
Shift/LB sprints at 6.2 m/s; C/R3 toggles crouch (Ctrl also holds it); Space/X
jumps. A/E still interacts and B/Esc opens the menu. Touch has movement/look
pads plus Run/Crouch/Jump actions. Input revocation clears pending jumping.

Animation uses collision-resolved speed and a stride calibration for the actual
avatar, including uniform scale. Idle, walk, run, sprint, crouch idle/walk and
jump share the approved reference-pose repair. AnimationPlayer supplies the blend;
the former second temporal filter is removed. Crouch lowers the pelvis fully,
without the previous 10 cm vertical clamp. Support height is corrected without
changing bones, and standing checks headroom before expanding the capsule.
This is not two-foot terrain IK or network prediction.

## Festival layout research

References, inspected 14 November 2026:

- [Saitama Tourism and International Relations Bureau, Iwatsuki Cultural Park festival photographs](https://www.stib.jp/mogitate/2019/08): close rows of counters facing the path, continuous awnings/signage and vendors behind the counters.
- [Higashi-Omiya Summer Festival official site/map](https://h-omiya-sf.org/map/): numbered booth groups, separate eat-in area and multiple entrances.

The game adaptation is a design choice, not a claim that all Japanese festivals
have one required layout. Twelve existing slots now form four compact groups of
three on two sides of the park promenade. Stalls are 2.8 m wide on 3.05 m centres;
canopy/counter height is unchanged. The open fountain court provides a cross
route, with smaller side rest pockets for tables and stools. Storage stays behind
stalls; fabric valances, counter skirts and lanterns make the front obvious.
Homes remain in the separate town district.

`Square.stall_layout(slot)` owns each physical slot's prop, seller and approach
positions. A four-sided model inspection confirmed Kenney’s counter faces +X,
whereas the avatar/NPC front is +Z. Prop yaw and seller yaw are therefore distinct;
the earlier shared yaw incorrectly presented the side post to the aisle.
Rental IDs and server slot numbers do not change with scenery moves.
NPC routes follow the clear aisle. The catalogue cover is an actual render of
this scene; no web photograph is bundled. The screenshots use a synthetic avatar,
not a personal profile. Decorative folded cloth is not saleable inventory.

## Validation and delivery

Source checks cover the motor, seven retargeted states, complete world movement,
NPC routes/appearances and service interactions. Render review includes standing
next to a merchant/counter, crouch and all movement states. Exact reports and the
installed-device result are recorded in `movement-evidence/README.md` after the
candidate is verified. A rendered pose is not a physical gamepad test or an FPS
benchmark. Spending, multiplayer and the public release remain unchanged.
