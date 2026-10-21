# Competitive Mini-Games

A family of compact competitive multiplayer games for TrainerOS, closely integrated with Fluxer and Social.

## The shared foundation

**All games in this collection should work through one common integration approach.** Each game can keep its own gameplay while reusing consistent ways of joining, inviting friends, forming communities, displaying social activity inside the game, and participating in competitions.

- Each game has a default community; other Fluxer communities can optionally enable support and be selected for relevant game activities.
- Pre-fill lobbies automatically whenever possible.
- Exchange supported community, lobby, session, and other game-related information using Fluxer where practical.
- Show useful social, lobby, and competition information in-game rather than requiring regular trips to Social.
- Leave room for tournaments, rankings, leaderboards, and challenges.

**Detailed common architecture is deliberately postponed.** Fluxer integration does not yet determine gameplay networking, competitive rules, or whether all features apply to every game.

See [Shared Approach](docs/shared-approach.md), [Results & Ratings](docs/ratings.md), and [Optional Fluxer Community Support](docs/community-support.md).

## First six ideas

- [Falling Blocks](falling-blocks/) — Tetris-style competitive falling-block puzzles.
- [Pong](pong/) — Arcade paddle/tennis matches.
- [Tanks](tanks/) — Arcade tank battles.
- [Mini Racing](mini-racing/) — Compact racing games.
- [Block Breaker](block-breaker/) — Competitive brick-breaking.
- [Tower Climber](tower-climber/) — Vertical platform climbing inspired by Icy Tower.

## Additional ideas

- [Snake Arena](snake-arena/) — Multiplayer snake battles on one shared field.
- [Light Cycles](light-cycles/) — Last-survivor arena races with persistent trails.
- [Bomb Arena](bomb-arena/) — Compact bomb-based arena battles.
- [Pocket Artillery](pocket-artillery/) — Turn-based artillery duels with deformable terrain.
- [Disc Battle](disc-battle/) — Competitive disc sport with rebounds and special throws.
- [Bubble Duel](bubble-duel/) — Head-to-head bubble-matching puzzle battles.
- [Treasure Rush](treasure-rush/) — Competitive treasure races through compact platforming mazes.
- [Asteroid Arena](asteroid-arena/) — Small multiplayer spaceship skirmishes among asteroids.
- [Micro Rally](micro-rally/) — Single-screen top-down racing.
- [One Hit Arena](one-hit-arena/) — Fast elimination platform-arena duels.
- [Tiny Duel](tiny-duel/) — Minimal-control melee duels centered on timing.
- [Button Wars](button-wars/) — A series of ultra-short reaction and input challenges.
- [Arrow Arena](arrow-arena/) — Small competitive archery arenas.
- [Marble Rush](marble-rush/) — Marble races through obstacle mazes.
- [Minesweeper Race](minesweeper-race/) — Competitive Minesweeper speed challenges.
- [Territory Wars](territory-wars/) — Area-capture arcade competitions.
- [Sumo Bots](sumo-bots/) — Physics-based robot-pushing matches.
- [Chain Reaction](chain-reaction/) — Competitive chain-combo color puzzles.

**24 game ideas total** (6 initial + 18 additional). Names are working titles, not final product or brand names. Games may later merge, split, or move into standalone Crates.

**Status:** [Pocket Artillery](pocket-artillery/), [Pong](pong/),
[Snake Arena](snake-arena/), [Light Cycles](light-cycles/), [Falling Blocks](falling-blocks/),
[Minesweeper Race](minesweeper-race/) and [Chain Reaction](chain-reaction/) have experimental
two-player implementations. Six games share [controls and SDK integration](arcade-common/).
The puzzle trio is [prepared for publication and further acceptance](docs/puzzle-trio-preparation.md).
Other entries remain concepts. See [original idea](docs/idea.md) for the starting vision.
