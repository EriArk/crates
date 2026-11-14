# Bazaar 0.0.4 — character deformation repair

**Superseded implementation location:** 0.0.8 moves this repair into the shared
SDK and adds calibrated locomotion/crouch. See [movement and market](MOVEMENT_AND_MARKET.md).
The historical measurements below describe 0.0.4, not the new cadence.

14 November 2026. The owner correctly identified broken anatomy in the 0.0.2/0.0.3
screenshots. Previous tests proved that animation played and a leg moved; they did
**not** establish correct deformation. That earlier animation acceptance is withdrawn.

## Cause and repair

UAL's bind silhouette is a T-pose. The SDK character rests with its arms down.
The old world-space delta transfer accounted for bone axes but preserved the wrong
reference silhouette. It therefore lowered already-lowered arms across the torso.
A second error mapped SDK `shoulder_blend` helpers as full upper arms; native SDK
clips rotate those sibling helpers by half of the upper arm's local rest-relative
rotation. Fingers were left in the target rest pose despite animated hands.

The game now aligns arm/hand/finger reference directions once at bind time before
applying donor motion. Body bind transforms, skin weights, vertex buffers and joint
lengths remain unchanged. Shoulder helpers use the SDK's half-rotation behavior;
finger joints follow the donor. Initial playback starts directly in the chosen clip,
while later clip changes keep their crossfade. Hip bob uses pelvis-height scaling,
so the chibi's large head does not determine the body's translation scale.
Required body bones are validated individually; optional finger joints are mapped
only when present. This is a bounded game-side fix, not a new profile/SDK skeleton.
The imported source assets and shared SDK files are unchanged.

[Godot's retargeting guide](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html)
explains why matching names/axes alone is insufficient and why differing rest
silhouettes need correction. We preserve the externally supplied bind pose rather
than rewrite it. Shoulder behavior was additionally measured in the SDK's own clips.

## Measured regression

The same synthetic resolved SDK character and source clips were used before/after.
The old implementation is reproducible from Crates commit `f70e151`, not a modified
or exaggerated baseline. Each clip settles for 90 steps and is then measured over
360 steps at 60 Hz: six seconds, covering multiple complete idle/walk/jog cycles.

| Clip | Old maximum arm direction error | Corrected maximum | Old minimum signed wrist side | Corrected |
|---|---:|---:|---:|---:|
| Idle | 76.27° | 0.41° | −9.14 cm | +14.14 cm |
| Walk | 77.10° | 2.70° | −9.45 cm | +14.39 cm |
| Jog | 77.52° | 7.81° | −5.00 cm | +17.88 cm |

Direction error compares upper-arm/forearm/hand direction against the aligned donor;
the remaining moving-pose error includes the deliberate temporal smoothing.
Negative wrist side means the wrist crossed the torso midline to the wrong side.
The regression also checks helper half-rotation, finite rotations, unchanged bind
transforms, joint offsets and scale. Old code fails all nine motion/side/helper
checks; corrected code passes them. This is not a body-surface intersection or
wardrobe-wide proof. [Before measurements](animation-evidence/checks-before.json),
[after measurements](animation-evidence/checks.json), [SDK shoulder reference](animation-evidence/sdk-shoulder-reference.txt).

The [headless world walkthrough](animation-evidence/headless.txt) and
[SDK subscribe/revoke check](animation-evidence/sdk-socket.txt) also passed.
[OpenGL studio/world review](animation-evidence/render.txt) completed without script,
shader or resource-leak errors. The [exported Linux window and menu exit](animation-evidence/export-boot.txt)
passed; Windows/ARM64 were exported only. [Build hashes](animation-evidence/build-manifest.json),
[verified archives](animation-evidence/package-sha256.json), [matched source inputs](animation-evidence/source-sha256.json).

## Visual review and scope

The studio review shows unanimated SDK rest beside Idle, Walk and Jog, using one
camera/lighting setup and the same avatar. Front, side and rear views expose the
previous collapsed shoulders and crossed arms. A further 24 phase samples cover
whole clips. These phase comparisons synchronize normalized clip progress;
they are not a measurement of in-game cadence or handheld FPS.
A separate capture uses the actual Bazaar camera and world.

- Front: [before](animation-evidence/before-front.png) / [after](animation-evidence/after-front.png).
- Side: [before](animation-evidence/before-side.png) / [after](animation-evidence/after-side.png).
- Back: [before](animation-evidence/before-back.png) / [after](animation-evidence/after-back.png).
- [Looping cycle review video](animation-evidence/cycles.mp4), 24 phases at 12 fps, repeated three times.
- [Actual Bazaar view](animation-evidence/in-world.png).

Reproduce using `tests/animation_checks.gd` and `tests/animation_review.gd`, supplying
`--descriptor=/absolute/path/to/synthetic-descriptor.json` and a writable `--output`.
The checks write a JSON file; the visual review writes a directory of PNGs and
requires a real renderer. Add `--world` for the actual-world capture. For the rejected
control, extract `f70e151:games/bazaar/scripts/locomotion.gd` to an isolated test copy's
`tests/legacy_locomotion.gd`, then pass `--legacy`. Do not put a profile model in source.

No personal avatar is committed or bundled. Descriptors/models used here are the
existing synthetic QA fixture. Real wardrobe combinations, terrain foot IK,
pose-driven corrective morph coverage and handheld runtime acceptance remain open.
The fix does not enable catalogue launch, network rooms, trading or Sparks spending.
Separate branches, no merge or handheld installation.
