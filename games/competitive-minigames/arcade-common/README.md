# Crates arcade integration

**0.1.2** migrates all eight games to Lobby-first launch. Each package includes
`traineros-activity.json`; the game attaches to the SDK after its first frame.
Registration keeps the solo menu intact, and only an admitted `network.ready`
starts the online match. Protocols and game rules are unchanged.
The earlier 0.1.1 repair is recorded in [controls and presentation](../docs/controls-and-presentation.md).
All eight arcade games and Pocket Artillery use `ControllerInput.h`: left stick,
D-pad, semantic actions, focus neutralisation and stable controller seats.
The touch panel is optional and returns on touch; hardware input hides it.
Virtual SDL-device tests exercise this path; physical handheld acceptance remains separate.

Shared support for **Pong**, **Snake Arena**, **Light Cycles**, **Falling Blocks**,
**Minesweeper Race**, **Chain Reaction**, **Brick Racing** and **Brick Tanks**. Each game owns
its rules in `src/`, its board in `ui/`, and its own icon and package. The common
code supplies the menu, two-player controls, SDK connection and match lifecycle.
Pocket Artillery retains its own rules and SDK client; `ArcadeBridge` reuses its GPL SDK client with
parameterized game identity. This is application-side support, not a new TrainerOS API.

## Player journey

- **Practice with bot:** offline, one human against a simple local bot.
- **Two on this device:** simultaneous independent controls. Mint uses WASD or
  controller 1; Coral uses arrows or controller 2. Each has visible touch buttons.
- **Online:** install the game on both devices, then use **GameHub → Lobby**:
  choose the installed game, prepare, both Ready, organizer Start. TrainerOS
  launches both clients and attaches them to the admitted session. Opening the
  game first is unnecessary; the solo menu has no multiplayer entry button.
- Each match starts with a two-second countdown. Back/Escape opens the leave
  confirmation. Local play pauses for the dialog or loss of focus and resumes
  explicitly. An online match continues while a player opens the menu or loses focus;
  held controls are released. Leaving ends the match for both while retaining Lobby.
- **Play again:** immediate offline; both players must agree online. A connection
  failure requires the ordinary Lobby preparation/Ready/Start for a fresh match.
  Neither a disconnect nor a profile change awards a victory.

D-pad, Confirm and Back work through SDL2's controller mapping. Controller slots
remain independent on removal/addition. Paddle controls are held; Snake/Cycles keep
moving in their last direction and reject reversal. Puzzle directions repeat while
held; primary/secondary actions use separate ordered records and a bounded queue.
The game README lists its keyboard, touch and two-controller action mapping. Both
players can hold separate touch controls at once. Desktop keyboard and synthetic
pointer/touch checks do not establish physical controller or handheld acceptance.

## Network contract

Requires SDK v1 `lobby.activity` and `network.records`. App IDs are
`art.abysstail.<game-id>` and protocols `<game-id>.2`; game IDs are `pong`,
`snake-arena`, `light-cycles`, `falling-blocks`, `minesweeper-race`, `chain-reaction`, `mini-racing`, `tanks`. Missing capabilities return to the menu with a
readable explanation and leave offline modes available.

The organizer computes the authoritative match at approximately 30 ticks/second.
The guest sends direction changes and, for puzzles, discrete actions. The organizer sends bounded snapshots
every two ticks (approximately 15/second) plus the final result. Pong interpolates
ball rendering between snapshots. This uses the existing reliable ordered SDK
channel, not a new UDP/relay/provider implementation. Guest input waits for the
organizer's next snapshot; network latency and head-of-line blocking can affect
responsiveness. This first version does not promise twitch-game internet quality.

Round identity, roles, input sequence and state shape are checked. A guest cannot
submit a host snapshot or choose the result. Both peers observe the organizer's
result; the organizer is trusted for casual play. This is **not** authoritative
server validation or cheat resistance. No ranked results, currency or backend
reward submissions are implemented.

Handshake and live-session watchdogs close stalled matches. SDK disconnect,
profile revocation, player exit and transport failure preserve room membership
where the SDK contract does; they do not restore the interrupted round.
No game saves, chat history, microphone or external media are accessed.

The SDK's existing secure helper and provider requirements apply. The games add no
owner-hosted realtime relay. Offline bot/couch play needs neither SDK nor an account.
Different-network, NAT, live Fluxer signaling and ARM delivery remain separate checks.

## Build and package

C++20, CMake 3.24+, Qt 6.4+ Core/Gui/Qml/Quick/Network, SDL2; Qt Test for tests.
Linux also needs the QtQuick/Window/WorkerScript QML modules. Windows development
uses the matching TrainerOS UCRT64 toolchain.

```sh
cmake -S games/competitive-minigames -B build/arcade -DCMAKE_BUILD_TYPE=Release
cmake --build build/arcade --parallel 3
ctest --test-dir build/arcade --output-on-failure
./build/arcade/pong --windowed
python3 games/competitive-minigames/arcade-common/package.py pong build/arcade/pong dist/pong
```

Repeat packaging with the desired game ID. Each package contains a
separate executable, icon, instructions and screenshot. The matching source archive
contains the common code plus all eight rule implementations and can be rebuilt
with `cmake -S arcade -B build -DARCADE_GAMES=pong` (or another game ID). Native Linux
ELF x86_64/aarch64 is supported by the packager; it does not cross-compile or certify ARM.
Packages reuse host Qt/SDL. `Experimental` / `untested` records contain future release
URLs; generating them publishes neither a GitHub Release nor a catalogue entry.

For real-host tests, configure `TRAINEROS_SOURCE` to a matching SDK checkout and
`TRAINEROS_CORE` to its `libtrainer_core.a`. Set `TRAINEROS_TEST_RECORD_PYTHON` to the
SDK secure-helper venv interpreter. The optional `arcade_host` target runs two real
PlatformHosts and separate TLS helper processes, substituting only provider signaling.
The two game clients live in the test process; this is not a two-device test.

An installed package can be checked with:

```sh
python3 games/competitive-minigames/arcade-common/tests/verify_package.py TRAINEROS_CHECKOUT RECORD_JSON PACKAGE_TAR_GZ
```

Game binaries also support `--endpoint PATH` for isolated SDK discovery and
`--screenshot PATH` for a menu capture. Default launch is fullscreen.

Original code and SVG/canvas artwork: GPL-3.0-or-later. See [LICENSE](LICENSE).

## Verification — 21 October 2026

- Windows UCRT64 / Qt 6.11 and Linux x86_64 / Qt 6.4: paddle collisions, scoring,
  snake growth/reversal/body collisions, permanent trails, simultaneous crashes,
  terminal-state preservation and invalid snapshot rejection passed. Bot-driven
  matches with three fixed seeds completed for each game with equal results on
  both builds.
- Real QML checks covered all three menus, couch selection, keyboard and pointer
  controls, two simultaneous touch points in Pong, pause/cancel/leave and bot mode.
  Menu/board captures were inspected at 640×480 and 960×640. Synthetic input does
  not certify physical pads, fingers, device focus routing or ARM performance.
- For each game, two real SDK hosts and separate TLS helper processes completed
  a match with both input owners, equal final state, mutual rematch, exit/rejoin
  in the same room, profile revocation and rejection of a guest-supplied result.
  Only provider signaling was substituted; this is loopback evidence, not live
  Fluxer or different-network gameplay. The final host suite passed all three games.
- A regression test delivers an old channel's delayed error after a new channel
  has opened: it no longer revokes the new match. The common application event loop
  also handles SDL's quit event so managed termination actually closes the process.
- Each Linux Release package passed actual installation, managed launch, busy
  removal protection, termination, removal and data-preserving reinstallation in
  disposable storage. Host libraries are required; packages are not portable AppImages.
- Subsequent native ARM64 build on Odin (Fedora 44 / Qt 6.11.2 / GCC 16.2.1) and
  CTest passed. All three 0.1.0 releases now contain x86_64/aarch64 packages from
  `68e0943`, source archives, records and checksums. Signed catalogue revision 9
  serves them; six public binary downloads matched their recorded sizes/hashes.
- All three installed through normal Crates Download on both Odin and Flip with
  the updated shell/SDK. Pong and Snake bot games rendered on Odin; Light Cycles
  reached a result on Flip. System Home/Exit returned to Crates for each, using
  remote synthetic input. Physical controllers/touch, live account invitation,
  paired internet play, latency/NAT and full-session acceptance remain open.

## Puzzle preparation — 21 October 2026

The next three games and the preparation/publication split are recorded in
[the handoff document](../docs/puzzle-trio-preparation.md). This adds application-side
actions to the existing channel; no TrainerOS runtime changes or new transport.

## Brick-game preparation

[Brick Racing and Brick Tanks](../docs/brick-duo-preparation.md) add a shared-road
race with drafting/overtaking and a shared destructible-cover duel. Both retain
practice, couch and Lobby modes. Only their primary action is shown; older puzzle
games retain both actions. Publication and installed acceptance remain separate.
