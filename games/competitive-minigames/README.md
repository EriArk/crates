# Competitive Mini-Games

A family of small competitive multiplayer games for TrainerOS, tightly integrated with Fluxer and the TrainerOS Social experience.

## Shared concept

- Each game gets its own community.
- Game lobbies should be pre-filled automatically using available context whenever possible.
- Use Fluxer to exchange supported lobby, community, session, and other game-related data wherever practical.
- Friends, invitations, multiplayer activity, competitions, and community information can appear **inside the game**, instead of constantly switching to the Social screen.
- The common ecosystem can grow into tournaments, rankings, leaderboards, and similar competitive features.

Networking architecture, data transport for real-time gameplay, ranking rules, and UI details are **not decided yet**. Do not assume all frame-by-frame gameplay traffic must flow through Fluxer.

## Initial game ideas

- [Falling Blocks](falling-blocks/) — competitive Tetris-style falling-block puzzles.
- [Pong](pong/) — competitive table-tennis/arcade paddle game.
- [Tanks](tanks/) — small multiplayer tank battles.
- [Mini Racing](mini-racing/) — compact competitive racing games.
- [Block Breaker](block-breaker/) — competitive brick-breaking.
- [Tower Climber](tower-climber/) — competitive vertical climbing, inspired by Icy Tower.

Working project names only. Each game may evolve into its own independent Crate.

**Status:** Idea collection; detailed design later.

See [docs/idea.md](docs/idea.md) for the scope originally proposed.
