# Bazaar island — 14 November 2026

Historical 0.0.2 report. See [0.0.3 polish and camera](POLISH.md) for current evidence.

This replaces the enclosed first-square layout. The owner's correction separates
**the festival market in a park** from **the town square with houses and shops**.
Both belong to one local island. No network room or commerce is created here.

## Places

- The island is roughly 170 metres across, with an irregular cliff edge, animated
  ocean and a visible stone shore barrier. Its center remains walkable, with roads
  connecting each district. The coast and unused land remain an early landscape pass, now with actual
  walkable hills, sloping shoreline and flat road/building pads.
- Festival Park has twelve stalls in two inward-facing rows. A broad central
  promenade, fountain crossing and gaps between stalls keep the walking route open.
  Paper lantern strings, flowers, shrubs and trees replace the surrounding houses.
- Town Square is east of the park. Three signed shops — MOSS & TEA, THREAD, CURIOS —
  each have an interactable entrance, a furnished preview room and a return exit.
  Rooms are separate local spaces on the same map; no goods, NPCs or sales exist.
- Garden Court provides a quieter landscaped space. Harbor Terrace and Workshop
  Court reserve distinct locations for future functions. Their signs describe
  the intent; they do not report services or multiplayer admission as working.
- The fountain has eight animated parabolic jets; the basin/ocean ripple, hanging
  cloth moves, and decorative lanterns glow. This is not a fluid simulation.

## Relief and atmosphere — reused from Pocket Golf

The owner's terrain correction explicitly recalls Pocket Golf. Its `MEADOW.md`,
`RELIEF.md` and `LIGHTING.md` were reviewed before this change. We reuse its actual
GPL meadow shader and adapt its sea shader to the new coastline, with source
commit/hashes in `shaders/SOURCE.json`. No second renderer or terrain plugin.

The ground is a subdivided mesh with several broad hills, smooth clearances around
roads and districts, a sloping shore and matching static collision. Grass and trees
sample the actual triangles rather than an approximate height curve. Grass uses
small opaque blades in 12-metre MultiMesh cells, with no shadows or alpha cards.
Cells stop drawing at 42 metres; screen-size vertex shrink and filtered material
details suppress subpixel shimmer. Imported static props are also batched per cell.

The sky uses a color gradient and 48 low-poly cloud puffs in a single MultiMesh.
Depth fog begins at 65 m and reaches its end at 230 m. There are no volumetric
clouds/fog, SSAO, realtime GI or screen-space water effects. Warm sun/cool fill are
configured for Compatibility. There is no claim of handheld FPS until device tests.

References: [Godot MultiMesh](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html),
[visibility ranges](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html),
[renderer capabilities](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html).

## Animation source and retargeting

Downloaded **Universal Animation Library Standard v3.0** from Quaternius's own
itch.io page. It contains 43 clips, not the full paid pack. The unchanged, non-root-
motion GLB and original CC0 notice are included, with archive/file hashes.
Godot's importer removes `_Loop` from names. The game selects `Idle`, `Walk` and
`Jog_Fwd`, crossfades them, and transfers rotations onto the existing SDK rig.

The donor character is hidden. World-space rest-rotation deltas, a left/right hip
alignment and target bone lengths account for different rest axes and proportions.
Pelvis bob is scaled and bounded. CharacterBody movement remains authoritative:
animation cannot move the capsule, cross a wall, or change profile appearance.
Unmapped fingers retain their rest pose. This is a locomotion pass, not full hand
posing, terrain foot IK or a wardrobe-wide animation acceptance claim.

The SDK client/presenter are unchanged. Revocation destroys the game-side retargeter
and its donor together with the resolved profile model. Guest fallback remains a
labelled capsule; it does not borrow a human avatar or the donor's identity.

## Verification and remaining work

The final [headless walkthrough](island-evidence/headless.txt) and full **800×450
OpenGL walkthrough** passed ([report](island-evidence/report.json),
[log](island-evidence/opengl.txt)). They cover movement, collision, pause/touch reset,
shop entry/return, loaded avatar and retargeted leg motion, real hill collision,
chunked grass bounds/clear routes and fountain time advancement. The
[loopback SDK subscribe/revoke test](island-evidence/sdk-socket.txt) also passed.
The SDK fixtures are synthetic; no account/save or personal model is committed.

The [review render](island-evidence/render.txt) includes park, town, interior,
meadow, coast and locomotion captures. Counter values are draw calls, not FPS.
Wide review cameras explicitly disable distance culling to show the island layout;
normal gameplay retains it. Final runs contain no script/shader errors or resource
leaks. Container-root and unavailable V-Sync warnings are retained.

Linux x86_64 was [boot-checked as an exported game](island-evidence/export-boot.txt).
Windows x86_64 and Linux ARM64 were exported, **not run on target hardware**.
Physical controls, handheld performance and live shell pairing remain unverified.
[Binary hashes](island-evidence/build-manifest.json),
[archive hashes](island-evidence/package-sha256.json),
[source inputs matched to the server](island-evidence/source-sha256.json).

- [Festival market in the park](island-evidence/park-arrival.png)
- [Separate town shops](island-evidence/town.png)
- [Enterable tea shop preview](island-evidence/tea-interior.png)
- [Walkable hills and grass](island-evidence/meadow-hills.png)
- [Island layout](island-evidence/island.png)
- [Market layout](island-evidence/park-layout.png)
- [Retargeted walking pose](island-evidence/avatar-walk-1.png)
- [Inspection menu at 800×450](island-evidence/stall-info.png)

Next: catalogue-managed launch/return, named multiplayer realities and host
migration, real protected inventory transfers/trading, richer interiors and
landscape art, environmental audio, physical controls and device performance.
All Sparks purchases remain closed. Separate branches, no merge, no installation
or publication in the Crates catalogue.

## Third-party assets

- [Quaternius Universal Animation Library](https://quaternius.itch.io/universal-animation-library):
  `assets/animations/provenance.json`, `licenses/Quaternius-UAL-CC0.txt`.
- [Kenney Nature Kit](https://kenney.nl/assets/nature-kit): flowers, trees, bushes and
  grass; `assets/nature/provenance.json`, `licenses/Kenney-Nature-CC0.txt`.
- [Kenney Fantasy Town Kit](https://kenney.nl/assets/fantasy-town-kit): retained
  modular buildings, stalls and props; `assets/town/provenance.json`.

All three art sources are CC0. Original source files are unmodified. Layout,
physics, animation retargeting, water effects and scene assembly are game code.
