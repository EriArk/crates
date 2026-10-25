# Pocket Golf 0.1.21: teams and island rival

Prepared 25 October 2026. Publication, handheld installation and physical-device
checks are explicitly deferred by the owner. Lobby UI/source is maintained in
another workspace and is not changed here.

## Player rules

- Individual matches: 2 or 4 people, one ball per person.
- Team matches: 4–8 people, 2 or 3 per team, at least two teams. Examples:
  2+2, 2+3, 3+3, 2+2+2, 2+2+3, 2+3+3, 2+2+2+2.
- One ball, eight-stroke limit and score per team. Teams alternate turns;
  teammates alternate within their team, carrying that rotation across holes.
  A sunk ball finishes the whole team's hole. Larger teams receive no extra shots.
- Local match setup supports controller, keyboard and pointer/touch. Press a
  participant's tile to cycle their team. Invalid partial edits disable Start.
  The online host chooses the same arrangement after SDK admission.
- Every participant votes for a rematch. Its starting side rotates. Lobby remains
  available after leaving; interrupted rounds are not resumed.

The maximum is eight participants and four balls, not sixteen. Three participants
cannot start this ruleset; the game explains the supported combinations.

## Solo rival and shared appearance

Solo creates a human-versus-computer match. The rival searches actual course
trajectories on one worker thread, with a minimum preparation time. It cannot
strike during local pause/focus loss; leaving cancels its work. It uses the same
terrain, collisions and stroke limits as a human. There is no difficulty selector
in this increment.

Each new solo round/rematch chooses standard hair, eyes, skin and clothing colours
and sends a recipe to the existing SDK `avatar.resolve`. A repeated complete recipe
is avoided. It changes no owner profile or wardrobe. The resolved character uses
the existing golfer rig, turn stepping and three celebrations. No GLB/model pack
is bundled or copied into the game. Without TrainerOS and its compatible standard
avatar pack, play remains available with the anonymous marker.

The SDK keeps only the latest resolved model **per connection**. The game therefore
uses one read-only avatar resolver per admitted remote participant (at most seven),
plus the usual local-avatar and game connections: at most nine connections in an
eight-player match, within the host's existing limit of sixteen. Solo needs one
extra resolver. Closing the match releases these connections and the SDK's temporary
model caches. Appearance replacements wait for a safe presentation boundary;
profile/context revocation clears identity immediately. Only recipes and admitted
member IDs cross the existing game channel, never model files or local paths.

## Networking and dependency

Protocol is now **`pocket-golf.7`**, package activity capacity **8**. It requires
the prepared SDK `network.group: 1` implementation (SDK preparation commit
`59755fc1e1a72372a7eacbc4d439452781fcab70` or its integrated successor).
The official vendored avatar SDK is unchanged. There are no new wire methods,
Lobby changes, servers, relays or transports.

The SDK grants a host/client star of reliable ordered channels. Golf validates
each admitted sender and current participant. Host-ordered putts carry integer aim
and before/after hashes; each peer independently simulates the candidate before
committing it. The immutable roster and teammate rotation participate in the hash.
JSON numeric roster values are normalized to integers before hashing.

After each shot, every participant acknowledges completion of its presentation
before the next turn opens. Aim previews remain cosmetic and coalesced at 15 Hz.
Heartbeats detect a stopped game; membership or context loss ends the match.
Outgoing records are queued (maximum 256), with at most 24 unacknowledged records
per channel. Incoming consumption acknowledgements drain first; local RPC requests
retain headroom below the client's 64-request limit. Cosmetic updates can be
coalesced away under pressure. This prevents a simultaneous seven-way avatar
fan-out from losing a required acknowledgement and breaking subsequent sequences.
Host migration, mid-round joins, round restoration and anti-cheat certification
are outside this increment. Same-machine TLS checks do not prove internet/NAT
connectivity, performance on eight physical devices or handheld acceptance.

## Checks

- `tests/teams_test.gd`: full rounds for 2/4/5/6/7/8, shared-ball cap, teammate
  rotation, sunk-team skip, malformed rosters, JSON normalization, actual bot
  completion of all three courses and main-thread planning-call timing.
- `tests/teams_ui_test.gd`: menu entry, 2+2 / 2+3 / four-pair setup, invalid edits,
  960×540 fit, team score rows, active teammate and bot control exclusion.
- `tests/protocol_test.gd`: malformed/forged commits, sender/turn authorization,
  independent replay, incompatible old protocol and context revocation.
- `tests/HostIntegration.cpp`: real SDK/secure helper/Godot processes for
  2/4/5/8, complete rounds, matching scores, all-player rematch and retained Lobby;
  group avatar attribution/lifetime and random stock rival assembly are separate
  checks. Configure against the matching prepared SDK core.
  The final maximum-avatar fixture pre-registers eight desktop engines before
  admission; it does not measure eight simultaneous cold starts or physical FPS.
- Analog, HUD, camera, audio/motion and effects regressions remain in the project.

Current evidence and artifact locations are in
[`POCKET_GOLF_TEAMS_HANDOFF.md`](../../../docs/POCKET_GOLF_TEAMS_HANDOFF.md).
