# Pocket Golf

A small, standalone 3D minigolf game for TrainerOS, built with **Godot 4.7.2**.
Three greens: First Light, The Bank Shot, and Sand & Stone. Play a solo round,
pass a controller between two people, or play with a friend through TrainerOS Lobby.

**0.1.15 fixes the opponent while waiting for a putt.** Both visibility and
placement beside the active ball are independent of the local right to fire.
The real paired SDK/Godot test checks both during the opponent's aiming turn.
0.1.13 already proved Crates installation, cold startup, bidirectional putts and
return to the same Lobby on Odin/Flip. Updated device visual acceptance, a complete
device match, physical controls and different networks remain open.

Shots now scatter grass or sand, fast rolls leave a brief soft streak, wood and
stone contacts shed different chips, and cup entry lights a short ring above the
green. A hole-in-one receives a larger golden flourish. Effects follow exact
trajectory time, respect local pause and use a reusable pool capped at 128 meshes.
See [effects, screenshots and checks](docs/EFFECTS.md).

The rolling model now uses direction-independent deceleration, round corner
contacts, slower putts and a speed-sensitive cup with lip deflection and a visible
drop. Animation interpolates the 120 Hz integer trajectory and rolls the marked
ball. See [the rolling model](docs/PHYSICS.md).
All three greens now have playable slopes: uphill loss of speed, downhill
acceleration, lateral break and rollback on steep climbs. One triangle height
grid drives the actual green mesh and the rules. Sand follows that same surface;
the ball, aiming dots, golfer and cup sit at its height. The distance hint includes
signed rise/fall to the pin. See [slopes, screenshots and checks](docs/SLOPES.md).
The golfer loads the shared TrainerOS avatar from its external SDK cache.
Opponents exchange compact part/color recipes over the existing game channel;
TrainerOS assembles their models locally. No character art is bundled with Golf.
Standalone play and unsupported appearances retain an anonymous marker.

![Playable hills and compact golf HUD](docs/slopes-overview.png)

The field stays visible behind a compact floating HUD: hole/par, distance to the pin,
player stroke counts, running totals and a slim power gauge. Shot controls disappear
while the ball rolls or your friend aims. See [HUD references and checks](docs/HUD.md).

The greens sit on a small sandy island surrounded by animated turquoise water,
with rolling hills, a continuous short-grass meadow, bushes, low-poly palms,
flowers, rocks, a landing and boats. Grass and water reduce subpixel detail in
the distance. Warm sunlight, cool sky fill, filtered shadows, textured turf/sand/wood/stone
and subtle far depth of field give the island depth while keeping the course sharp.
See [lighting, materials and validation](docs/LIGHTING.md) and
[grass, distance rendering and checks](docs/MEADOW.md). Environment models
come from Kenney's free CC0 Nature, Pirate and Minigolf kits; see
[asset sources, licences and visual checks](docs/ISLAND.md).

## Play

- Left/right or stick/D-pad: aim in five-degree steps. Up/down: power in five-percent steps.
- Confirm (bottom face button; A on Xbox), Enter or Space: putt / accept handoff.
- Secondary face button (X on Xbox), Tab, or the camera icon: overview → shoulder → eyes.
- Right stick or WASD: rotate/look around; right trigger / E zooms in, left trigger /
  Q zooms out. R3 / R restores the selected view. Camera controls never change aim/power.
- Mouse: hold the right button to rotate; wheel to zoom. Touch: drag the green to
  rotate and spread/pinch two fingers to zoom. Drag the power gauge to select power;
  click **PUTT** to strike. Touches on the HUD do not also orbit the camera.
- Overview/shoulder zoom changes camera distance; eye zoom changes the field of view.
  Each view retains its own bounded zoom/rotation. A putt smoothly switches to ball
  follow and returns to the selected view for the next stroke. Pause freezes the camera.
- Back / Start / Escape: pause/menu. Confirm **Leave round** ends the round.
- Touch automatically reveals a horizontal aim gesture and one round **PUTT** target.
  Drag the aim control sideways; slide the power gauge; release **PUTT** to strike.
  Dragging off **PUTT** cancels it. Keyboard/controller input hides the touch controls.
  The two small corner icons provide camera and pause access with touch or mouse.
- Current player is ringed in the player list. `Σ` shows the running round total,
  including strokes on the current hole. Initial circles await the shared SDK portrait.
- Pause also shows the full control reference for the active input method.
- Each player uses their own ball; the other ball does not block a shot. Players
  alternate strokes, skipping anyone already in the cup. Eight strokes ends that
  player's hole. Lowest total across three holes wins; equal totals are a draw.
- The scorecard shows strokes per hole and the total. Rematches alternate the
  starting player. Local handoffs require explicit confirmation.
- A lost controller or window focus opens the pause menu. Local rolling pauses;
  online presentation continues to receive/process the match while local controls
  remain paused. Returning focus does not automatically putt or resume.

## TrainerOS

Select installed Pocket Golf in GameHub Lobby, mark Ready and let the organizer
Start. TrainerOS launches both games and the SDK supplies their admitted session.
No preliminary game launch or "Meet in Lobby" menu is needed. The game uses
Platform API v1 `lobby.activity` and `network.records`, app ID
`art.abysstail.pocket-golf`, protocol `pocket-golf.5` (scaled physics and avatar recipes).
The package includes `traineros-activity.json` for discovery while the game is closed.

Retroid Pocket Flip2 uses OpenGL Compatibility because Godot 4.7.2 / Turnip
Adreno 650 repeatedly lost the Vulkan device in the menu. Other devices retain
Vulkan Mobile. `POCKET_GOLF_RENDERER=mobile` or `gl_compatibility` overrides the
package launcher for diagnosis. These are standard
[Godot renderer arguments](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html).
Both players need 0.1.8 or a compatible physics revision. The former
`pocket-golf.1` and `pocket-golf.2` routes are deliberately incompatible; the state hash also includes
the physics revision, so mixed rules cannot silently share a round.

The GDScript client in `addons/traineros/client.gd` uses the existing local JSON-lines
SDK contract. It has no separate login, room service, IP entry, or new relay. Shots
carry angle, power, turn and pre/post-state hashes. Both sides calculate integer
rules; rendering and engine physics never decide the result. Hash agreement detects
divergence, not cheating or eligibility for official rewards.

An unavailable/revoked host returns to the menu and leaves solo/local play available.
Exit or connection loss ends the game session while retaining Lobby membership.
Reconnect requires the normal preparation/Ready/Start flow; unfinished rounds are
not restored. A friend rematch requires both players' votes. The current SDK route
is two players and reliable ordered records; live provider/NAT acceptance is separate.

The avatar seam and remaining integration work are described in
[AVATAR_INTEGRATION.md](docs/AVATAR_INTEGRATION.md). Clothing, appearance selection,
inventory and identity persistence belong to TrainerOS/SDK, never to this game.

## Build and check

Use the official **Godot 4.7.2 standard editor** and its matching export templates.
No .NET, Blender, asset-store downloads or external runtime plugins are required.
The default renderer is Mobile/Vulkan. OpenGL Compatibility can be selected with
`--rendering-method gl_compatibility`; visuals differ and handheld performance still
needs checking. The game has no audio track in this preparation.

```sh
godot --path games/pocket-golf --editor
godot --headless --path games/pocket-golf --script tests/rules_test.gd
godot --headless --path games/pocket-golf --script tests/physics_test.gd
godot --headless --path games/pocket-golf --script tests/slopes_test.gd
godot --path games/pocket-golf --script tests/slopes_presentation.gd
godot --path games/pocket-golf --script tests/physics_presentation.gd
godot --headless --path games/pocket-golf --script tests/protocol_test.gd
godot --headless --path games/pocket-golf --script tests/presentation.gd
godot --headless --path games/pocket-golf --script tests/camera_test.gd
godot --path games/pocket-golf --script tests/island_test.gd
python3 games/pocket-golf/build.py --godot /path/to/godot --templates /path/to/templates --output /path/to/build
python3 games/pocket-golf/package.py /path/to/build /path/to/fresh-output
```

`build.py` stages a disposable copy, verifies the pinned engine version, and exports
Linux x86_64, Linux ARM64 and a Windows preview without modifying the source project.
`package.py` creates Crates archives/records, a Windows zip, complete source archive
and checksums. It never publishes. Records remain Experimental / untested; their
release URLs are future destinations. Builds require an editor: official 4.7.2
release templates disable `--script` path overrides, so source tests must use the
editor binary. `tests/HostIntegration.cpp` launches two actual Godot processes against
two real PlatformHosts; see [the preparation record](docs/PREPARATION.md).

Original game/client/procedural environment: GPL-3.0-or-later, see [LICENSE](LICENSE).
Kenney models/textures retain CC0-1.0; their original notices and source hashes
are included in `assets/kenney/` and under `licenses/` in the binary packages.
The unmodified Godot engine is MIT; its notices and bundled third-party licenses
are included under `licenses/`. No model, rig or clothing from the other chat is copied.
