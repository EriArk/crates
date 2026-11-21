# Bazaar 0.0.20 — Festival market

On a device with a running lab host, open the field menu and choose **Enter test
market**. Vale's park map shows the weekly rent. Choose a keeper and review the
full price in TrainerOS. At your counter select **List profile item**, pick the item in your bag,
then adjust the asking price with left/right or enter it directly. Another player
can see up to three goods on the counter before opening it. Move up/down to inspect the shelf. Press **A** on a row or tap it to
review the item and the price together. **Profile inventory** shows the delivered item. If a reply is lost,
choose **Resolve last checkout** at Vale's desk, also after restarting the game
or host. Ordinary visits and the personal-world previews use the normal profile.

## Voices of Festival Park

Walk up to a resident and press **A / E** to talk. At staffed counters **Y / T**
starts a conversation and **A / E** opens the service. Touch uses the on-screen
buttons. Reveal or advance with **A / E**, and leave with **B / Esc**.

The original *Awning Waltz* loops while exploring. The field menu remembers
Music, Effects and Fountain separately. Footsteps follow the actual surface and
animal calls come from nearby residents and birds. The score, footfalls, calls
and syllables can be regenerated with Python 3 and ffmpeg using
`python3 tools/compose_bazaar.py`.

## THREAD outfit sets

Choose Traveller, Mage or Merchant at THREAD to preview a complete four-piece
set. The four item buttons cycle the top, trousers, footwear and hat independently.
Own outfit restores the clothes from the active SDK profile.

Bazaar loads the active host avatar on entry and when its resolved model changes.
Revision 13 adds directional eyes and a head turn on top of locomotion. Approach
a merchant or a sign to see the effect. At THREAD the avatar follows the active
pattern or control and releases it when the curtain closes.

Open **Online → Bazaar → Festival Park** on Flip 2 or Odin 2. Visit Vale in the
Stall Office to select a numbered counter on the park map. Browse a counter in
person or visit Wisp at THREAD. Choose a pattern to see the outfit on your avatar;
the booth curtain closes while it changes. Turn the model to inspect the details,
select **Own outfit** to compare, or press **B** to return to the shop. Guests
preview on a wooden dress form. Trying on clothes is free.
[Service screens and checks](docs/counter-evidence/README.md).

Version 0.0.10 adds [two empty personal starting worlds](docs/personal-worlds/README.md):
Mika’s sea island and Ren’s orbital station under glass. The central square stays
clear for future paid facilities; no Sparks spending is enabled.

A standalone Godot 4.7.2 prototype of TrainerOS's first official fantasy Bazaar.
The island separates a **festival market in a park** from a **town square with
houses and shops**, connected by paths to gardens, a harbor terrace and room for
future districts. The park has twelve stalls, flowers, lantern strings and a
working fountain. Hills, a grassy meadow, clouds and distance haze use the same
lightweight approach as Pocket Golf. Four signed buildings have enterable rooms and exits, including the Stall Office.

People, rabbits, yetis, dino, frog and bird folk inhabit the island: twelve
merchants and seven pedestrians, with humans in the majority. Humans have five
skin tones and dark facial details. Six animated birds fly around the
districts and climb away from a nearby visitor. Residents greet, stroll, pause
at corners and stop for the player. [Appearances and animation checks](docs/RESIDENT_APPEARANCE.md).

The existing TrainerOS avatar SDK supplies the profile character. CC0 Quaternius
idle/walk/run/sprint/crouch/jump animations are retargeted by the optional shared
SDK helper; the donor model stays hidden.
Version 0.0.4 corrects the SDK arms-down / donor T-pose mismatch, shoulder helpers
and finger motion. [Deformation review and before/after](docs/ANIMATION_REPAIR.md).
Missing host/assets use a labelled guest capsule. Revocation or disconnection
removes profile identity and its retargeter. No personal model is bundled.
The public economy stays closed. Staffed rentals and profile loot trading are playable with the isolated test wallets.

[Rental office, NPC selection and trading preparation](docs/SERVICES.md): walk to
the office for twelve numbered places and native seller previews. NPCs cost 100
Sparks per rental; three planned new costumes are 50 each in alpha. The service
interfaces use TrainerOS to read the Backend and review supported checkouts.
The tailor continues to offer free previews.

## Run from source

```sh
godot --headless --path games/bazaar --editor --import --quit
godot --path games/bazaar
```

Use Godot **4.7.2 Standard**, with Compatibility rendering by default. Optional
`TRAINEROS_SDK_ENDPOINT` uses the normal SDK endpoint discovery; do not put a
credential, machine path or personal avatar in the game. Pause → Use my TrainerOS
character explicitly reconnects. Ordinary standalone walking works offline.

- **Keyboard:** WASD moves, Alt walks, Shift sprints, C toggles crouch, Space jumps;
  right-mouse drag or arrows rotates the camera.
- **Controller:** left stick moves (full run at 80% travel), LB/L3 sprints, R3
  toggles crouch, X jumps, right stick looks, A inspects a nearby
  sign or merchant, B/Start opens/closes the menu. The controller's ordinary UI navigation
  handles menu buttons.
- **Touch:** drag in the lower-left area to move, right side to look; tap the
  contextual inspect button or Menu. Opening a menu clears held touch input.
- **Menu:** field of view 75–105° (horizontal reference at 16:9, default 90°),
  fountain sound toggle. Choices persist locally.
- **Leave Bazaar** exits the ordinary game process. Losing window focus pauses
  movement. The third-person spring arm avoids clipping through world colliders.

## Implemented and still pending

Festival Park includes district navigation, local residents, a rental office,
shop entrances, the fitting room and player counters. Two handhelds can trade
profile items through their separate test hosts and a shared test Backend.
The installed shell opens the island from Online → Bazaar → Official Bazaar.

Live spending is closed. Multiplayer admission, host migration, parallel realms
and transfers from game saves are still pending.

Separate Crates branch `codex/bazaar-world-20261114`; no merge or public catalogue
release. The previous private 0.0.9 delivery is recorded separately. [Earlier polish/camera evidence](docs/POLISH.md).
The [island design report](docs/ISLAND.md) records version 0.0.2.
The [first square report](docs/FIRST_SQUARE.md) is historical version 0.0.1.

## Assets and code

- Residents/birds: [Quaternius Ultimate Monsters](https://quaternius.com/packs/ultimatemonsters.html)
  and [Ultimate Animated Character Pack](https://quaternius.com/packs/ultimatedanimatedcharacter.html),
  CC0; [animal provenance](assets/residents/provenance.json), [human provenance](assets/residents/humans-provenance.json).
  Original rigs and animations are used directly, without avatar retargeting.
- Nature assets: [Kenney Nature Kit](https://kenney.nl/assets/nature-kit), [provenance](assets/nature/provenance.json).
- Locomotion: [Quaternius](https://quaternius.itch.io/universal-animation-library), [provenance](addons/traineros/animations/provenance.json).
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

[0.0.8 shared movement, proportions and festival layout](docs/MOVEMENT_AND_MARKET.md).

The Egregore loading flight uses the OctoFox Ship Studio hull, drive exhaust and
sky from revision `37b4572e`. Steer with the left stick or arrow keys. The
arrival artwork is captured in this game.
