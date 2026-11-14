# Bazaar — first walkable square

A standalone Godot 4.7.2 prototype of TrainerOS's first official fantasy Bazaar.
This is an actual 3D local walkthrough: move around the fountain, browse market
scenery and inspect signs for the future spaces. Buildings, stalls, trees and
lanterns use **Kenney Fantasy Town Kit 2.0 (CC0)**. No payment is involved.

The player uses the shared TrainerOS avatar SDK. With a running local shell and
selected profile, the existing client resolves and validates the character;
profile revocation/disconnection removes that identity immediately. Without it,
the game uses an explicitly anonymous capsule. No character art is bundled.
The supported SDK `step` gesture supplies provisional motion; a proper walking /
running animation set is still needed. Physics never depends on the avatar mesh.

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
- **Leave Bazaar** exits the ordinary game process. Losing window focus pauses
  movement. The third-person spring arm avoids clipping through world colliders.

## Implemented and still pending

The square has a continuous walkable route around its fountain, static collision
for buildings/stalls/trees and closed world boundaries. Signs identify the market,
a future garden court and personal bazaars. These are previews of functions;
there are no fabricated visitors, occupancy counts, shop goods or successful trades.

Multiplayer, host migration, parallel-realm selection, linked secondary plazas,
real shops/inventory transfers and the catalogue → installed Crate launch/return
integration are **not implemented** in this first world increment. The TrainerOS
catalogue remains on its explicit placeholder until a real package/admission path
is connected. Creating this prototype does not unlock Bazaar spending.

This lives on a separate Crates branch (`codex/bazaar-world-20261114`) alongside
the separate TrainerOS Bazaar branch. It is not merged, published to the catalogue
or installed on handhelds. [Evidence](docs/FIRST_SQUARE.md).

## Assets and code

- Environment models and palette: [Kenney](https://kenney.nl/assets/fantasy-town-kit),
  [original CC0 notice](licenses/Kenney-Fantasy-Town-CC0.txt),
  [source archive and file hashes](assets/town/provenance.json).
- Game/SDK code: GPL-3.0-or-later; see [LICENSE](LICENSE).
- The unmodified SDK client/presenter are copied from TrainerOS;
  [source commit/hashes](addons/traineros/SOURCE.json). Update both together.
- Generated import caches, local endpoints, test descriptors and binary builds
  are not source assets and are not committed.
