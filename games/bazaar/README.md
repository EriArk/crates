# Bazaar 0.0.3 — island walkthrough

A standalone Godot 4.7.2 prototype of TrainerOS's first official fantasy Bazaar.
The island separates a **festival market in a park** from a **town square with
houses and shops**, connected by paths to gardens, a harbor terrace and room for
future districts. The park has twelve stalls, flowers, lantern strings and a
working fountain. Hills, a grassy meadow, clouds and distance haze use the same
lightweight approach as Pocket Golf. Three signed shops have enterable preview rooms and exits.

The existing TrainerOS avatar SDK supplies the profile character. CC0 Quaternius
idle/walk/jog animations are retargeted in the game; the donor model stays hidden.
Missing host/assets use a labelled guest capsule. Revocation or disconnection
removes profile identity and its retargeter. No personal model is bundled.
No trading, multiplayer, purchases or Sparks spending are enabled.

## Run from source

```sh
godot --headless --path games/bazaar --editor --import --quit
godot --path games/bazaar
```

Use Godot **4.7.2 Standard**, with Compatibility rendering by default. Optional
`TRAINEROS_SDK_ENDPOINT` uses the normal SDK endpoint discovery; do not put a
credential, machine path or personal avatar in the game. Pause → Use my TrainerOS
character explicitly reconnects. Ordinary standalone walking works offline.

- **Keyboard:** WASD moves, Shift runs; right-mouse drag or arrows rotates the camera.
- **Controller:** left stick moves, LB runs, right stick looks, A inspects a nearby
  sign, B/Start opens/closes the menu. The controller's ordinary UI navigation
  handles menu buttons.
- **Touch:** drag in the lower-left area to move, right side to look; tap the
  contextual inspect button or Menu. Opening a menu clears held touch input.
- **Menu:** field of view 75–105° (horizontal reference at 16:9, default 90°),
  fountain sound toggle. Choices persist locally.
- **Leave Bazaar** exits the ordinary game process. Losing window focus pauses
  movement. The third-person spring arm avoids clipping through world colliders.

## Implemented and still pending

This is an actual local walkthrough with collision, district navigation, shop
entry/return, pause, animated water and locomotion. Shop displays remain scenery;
there are no fabricated visitors, stock, occupancy counts or successful trades.

Multiplayer, host migration, parallel-realm selection, real shops/inventory
transfers and catalogue-managed Crate launch/return are **not implemented**.
The TrainerOS catalogue remains on its explicit placeholder until a real package
and admission path is connected. This world does not unlock Bazaar spending.

Separate Crates branch `codex/bazaar-world-20261114`; no merge, catalogue release
or handheld install. [Current polish/camera evidence](docs/POLISH.md).
The [island design report](docs/ISLAND.md) records version 0.0.2.
The [first square report](docs/FIRST_SQUARE.md) is historical version 0.0.1.

## Assets and code

- Nature assets: [Kenney Nature Kit](https://kenney.nl/assets/nature-kit), [provenance](assets/nature/provenance.json).
- Locomotion: [Quaternius](https://quaternius.itch.io/universal-animation-library), [provenance](assets/animations/provenance.json).
- Environment models and palette: [Kenney](https://kenney.nl/assets/fantasy-town-kit),
  [original CC0 notice](licenses/Kenney-Fantasy-Town-CC0.txt),
  [source archive and file hashes](assets/town/provenance.json).
- Fountain bed: original procedural audio, reproducible with
  `python3 games/bazaar/tools/generate_water.py`; GPL-3.0-or-later.
- Game/SDK code: GPL-3.0-or-later; see [LICENSE](LICENSE).
- The unmodified SDK client/presenter are copied from TrainerOS;
  [source commit/hashes](addons/traineros/SOURCE.json). Update both together.
- Generated import caches, local endpoints, test descriptors and binary builds
  are not source assets and are not committed.
