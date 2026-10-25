# Pocket Golf — shared results

Prepared 0.1.22, 25 October 2026. Requires the combined TrainerOS SDK capabilities
`network.group:1`, `account.identity:1`, `play.scorecards:1`. Gameplay protocol is
`pocket-golf.8`; older `.7` clients cannot join this session.

## Player journey

Sign in through Fluxer in TrainerOS. Golf never receives account or grant tokens.
The existing Lobby admits the group; the host chooses the existing individual or
shared-ball team mode. Everyone joins the server match themselves, with the same
immutable sides. The host checks the complete set of Player IDs before Start.
An arbitrary host team is mapped to server side zero without changing team colour,
turn order or the game's score display.

Two/four individual players and 4–8 participants in teams of two or three are
supported by the game. The underlying SDK/backend limit of 16 is not a Golf limit
increase. Teams share one ball, eight strokes per hole and a continuous teammate
rotation. Rematch creates a new server match after everyone agrees.

After the third hole, every participant submits the entire identical card. Intake
alone is pending. Only a confirmed server decision adds it to the shared records
and wins tables. Draws do not add a win. Teams are identified by their exact members;
individual and team tables are separate. Solo/bot/pass-controller rounds remain
outside these tables. A missing login/service falls back to a casual online round;
it does not award a server result or break the network game.

Shared tables are available from the main menu and round result. Five rows per
page, previous/next, individual/team and records/wins work through the same touch,
keyboard and controller actions. A changed table revision restarts pagination.
This preview requires host login for the in-game SDK table route. The public HTTP
table is readable without login. Public profile names are not supplied yet: the
game shows `You` and shortened Player IDs, never an unverified Fluxer display name.

## Recovery and ownership

`scorecards.gd` owns game orchestration; `client.gd` owns local SDK framing; the
existing host owns credentials and HTTP; Backend owns validation, decisions and
derived tables. No new Lobby, signalling service or avatar store is introduced.
Backend RPC errors/timeouts do not close the gameplay channel. Late responses are
discarded through bounded request tombstones. Changing context fences callbacks.

Before every mutation, the game atomically stores its UUID and exact payload in
owner game data, `scorecard-journal.json`. It contains no credentials. Up to 128
entries are retained; unresolved scorecards are never evicted to make room.
If storage fails, no new mutation is sent. `Retry result` explicitly retries the
latest pending card for the currently verified Player and ruleset, preserving its
operation ID. It can recover after restarting the game; a different Player cannot
submit the previous owner's card. Terminal decisions stop polling. Pending cards
poll at most once per three seconds for one minute, then require an explicit retry.
This is result recovery, not restoration of interrupted gameplay.

## Immutable competition

Ruleset: `pocket-golf.island.analog5.v1`. Three island greens, one to eight strokes
per hole, ascending total, `peer_confirmed` trust. The content ID and normalized
SHA-256 of all five simulation/content files are in [scorecard-sources.json](scorecard-sources.json).
The build verifies this binding and all transitive preloads; changing the physics,
course or score rules requires a new immutable competition registration.

The scorecard validator checks complete sides, integer bounds, sums and unanimous
confirmation. It does **not** replay the physical shots, attest the executable,
prove independent human players or grant trusted rewards. Disagreement/void removes
the result. No new Elo, seasons, tournament, economy, training or replay UI is added.

## Verification

- `tests/scorecards_test.gd`: JSON numeric boundaries, side mapping, persistence,
  same-operation retry, account isolation, late callbacks and nonfatal RPC errors.
- `tests/scorecards_ui_test.gd`: controller focus, table/result geometry at 960×540,
  pending submission barrier and Back. `tools/check_presentation.py` also renders it.
- `tools/check_backend_chain.py GOLF_WORKSPACE NATIVE_WORKSPACE BACKEND_SOURCE GODOT`:
  isolated real Golf processes → native PlatformHost/group TLS → HTTP → PostgreSQL
  worker, complete rounds, confirmation/table, distinct rematch and owner revocation
  on 2/4/5/8. Provider/vault identities and signalling are test fixtures. No live
  production results are generated. Each process has its own game-data directory.

Builds/checks run on the server. Prepared packages, not a GitHub release, catalogue
publication or handheld delivery. Different-network, physical input, portable FPS,
owner visual/audio acceptance and real-player login/gameplay remain separate checks.
