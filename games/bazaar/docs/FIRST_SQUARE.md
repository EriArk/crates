# First official square — 14 November 2026

## Scope and layout

A standalone **local playable prototype**, not a mock webpage and not a network
instance. Eight modular houses frame one plaza, with a central fountain, four
market stalls, benches, carts, lanterns and trees. Visitors can circle the fountain
and walk up to three signs. A closed gate marks the future garden court. The
market and personal-space signs explain planned functions without changing items
or spending Sparks. Buildings have collision but their interiors are not open.

The world is a separate Crates game. TrainerOS still owns the catalogue, account,
SDK avatar, inventory and future admission/launch/return. No duplicate room manager,
wallet, user identity, dedicated multiplayer server or fabricated population has
been introduced. Official capacity, named parallel worlds, peer hosting and host
migration remain subsequent work; their existing product decisions are preserved.

The initial art uses 30 GLBs and one palette from Kenney Fantasy Town Kit 2.0.
Original models/textures are unmodified, with CC0 license and hashes retained.
Layout, paving shader, colliders, controls and UI are authored in this project.
The square echoes the approved warm-town/teal-roof concept. It remains an early
layout and lighting pass; an overview capture is a review camera, not a world map UI.

## Avatar and controls

The copied TrainerOS SDK is unchanged and pinned by commit/hash. Only the game's
stable app ID is supplied. The current profile's shared GLB/TAV1 descriptor is
verified by that presenter. No model cache, profile token or resolved personal
model is committed/bundled. Missing host/assets use a labelled anonymous capsule.
Reconnecting clears the old identity before beginning, and revocation or socket
loss clears it immediately. No wardrobe editing lives in the game.

A CharacterBody3D supplies movement and collides independently of the avatar.
A SpringArm3D follows the visitor and excludes that body from camera collision.
The profile model faces travel direction. Its SDK Step gesture is sampled as a
**temporary** movement animation; it is not a complete walk/run cycle. Pause and
focus loss stop movement and clear held touch. Source keyboard, controller and
touch paths share this movement owner.

## Verification

The headless walkthrough and the real loopback SDK socket checks passed.
[Log](headless-sdk.txt). The complete Xvfb/OpenGL walkthrough at **800×450** also
passed: [report](report.json), [renderer log](opengl.txt). Checks cover movement,
floor/fountain/perimeter collision, walking around the obstruction, pause,
touch reset, sign interaction, panel bounds, actual asset palette imports,
shared-avatar load and identity revocation. The render and SDK fixtures are
synthetic; keyboard/touch events are injected. Physical controller/touch and
internet multiplayer are not certified. Final logs contain no script errors or
resource leaks; container-root and unavailable V-Sync warnings are retained.

The exported Linux x86_64 binary booted and exited successfully without the editor.
[Boot log](export-boot.txt), [exported binary hashes](build-manifest.json),
[source/asset hashes matching the remote inputs](source-sha256.json).
No target execution claim is made for Windows/ARM64.

Reviewed screenshots:

- [Shared character on the square](shared-avatar.png)
- [Stall inspection panel](stall-info.png)
- [World overview](overview.png)

The checks run in
isolated server tooling, using a synthetic resolved SDK avatar. No real user's
account/save is needed. The socket fixture implements the documented local hello /
subscribe / context-revoked exchange; it is not a live public-backend test.

Builds export with pinned Godot 4.7.2 official templates for Linux x86_64, ARM64
and Windows x86_64. Export success is not device acceptance. The x86_64 binary is
boot-checked; Windows and ARM64 binaries are not executed on their target systems.
No release/catalogue publication, handheld installation or merging is performed.

## Remaining

- Connect the official catalogue card to the installed Crate through the existing
  managed lifecycle and proper destination/return contract.
- Add real admission, population, named parallel realities and peer synchronization;
  then host migration and capacity/performance measurements on devices.
- Connect actual inventory custody and trading after protected save transfer exists.
- Add the other functional squares, proper walk/run clips, ambience and art polish.
- Physically test controller/touch and graphics performance on Odin/Flip and Windows.
