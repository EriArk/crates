# Crates — Games and Apps for TrainerOS

Games, apps, widgets and extensions for TrainerOS. Most entries are currently
concepts; implementation and verification are recorded per project.

**Implemented projects:**

- [Session Timer](widgets/session-timer/) — a session stopwatch, Start widget and
  optional break reminders.
- [Pocket Artillery](games/competitive-minigames/pocket-artillery/) — a two-player
  duel with destructible terrain, local pass-controller play and optional TrainerOS Lobby integration.

Both are experimental desktop builds and are listed in the signed TrainerOS
catalogue (revision 4). Public download, installation and managed launch passed on
Linux x86_64 with updated TrainerOS helpers/SDK. Handheld acceptance and Pocket
Artillery's live internet checks remain open.

**New experimental desktop games:** [Pong](games/competitive-minigames/pong/),
[Snake Arena](games/competitive-minigames/snake-arena/) and
[Light Cycles](games/competitive-minigames/light-cycles/) add bot practice,
simultaneous local controls and matches through TrainerOS Lobby. Their separate
Linux packages are prepared; public catalogue publication, ARM and live internet
acceptance remain open.

**Experimental Linux x86_64 downloads:**
[Session Timer 0.1.0](https://github.com/EriArk/crates/releases/tag/session-timer-v0.1.0)
and [Pocket Artillery 0.1.0](https://github.com/EriArk/crates/releases/tag/pocket-artillery-v0.1.0).
Each release includes a binary package, matching source archive, installer record
and SHA256SUMS. Qt 6.4+ and SDL2 are required; TrainerOS integration requires a
compatible Platform SDK v1. ARM builds are not available yet.

## Catalog

- [Games](games/) — [24 competitive mini-games](games/competitive-minigames/) and [interactive game shows](games/game-shows/).
- [Widgets](widgets/) — Start Dashboard widgets, including [Music Radio](widgets/music-radio/).
- [Apps](apps/) — standalone applications.
- [Extensions](extensions/) — optional integrations and features, including [Ghost Racing](extensions/ghost-racing/).
- [Game Tools](game-tools/) — [Speedrun Timer](game-tools/speedrun-timer/) and [deferred ideas](game-tools/ideas-for-later.md).
- [Unclassified Concepts](concepts/) — early ideas such as [Fluxer clans](concepts/clan-battles/) and [achievement coins](concepts/achievement-coins/); final packaging and ownership undecided.

## Architecture notes

- [Competitive mini-game shared approach](games/competitive-minigames/docs/shared-approach.md)
- [Competitive mini-game results & ratings](games/competitive-minigames/docs/ratings.md)
- [Opt-in support in other Fluxer communities](games/competitive-minigames/docs/community-support.md), including a future [clan-battle concept](concepts/clan-battles/)
- [Selected TrainerOS core ideas (not Crates)](docs/traineros-core-proposals.md)
- [TrainerOS ecosystem: first-party exclusives, account & monetization](docs/traineros-ecosystem.md) — AbyssTail games rely on common TrainerOS services, one shared coin economy, open cosmetics shop, Patreon/Ko-fi earnings multiplier up to ×3 and optional dev/beta access; **concept, not shipped**.
- [TrainerOS Backend integration](docs/backend-integration.md) — hosting boundaries, trusted match results, shared wallet/identity and official Crates metadata/install recipe policy.

Not all brainstormed ideas are accepted; only explicitly selected projects are recorded here. There are **no approved game addon projects yet**, and proposed author-creation tools from the initial brainstorm have not been selected.

Documentation records intent, not a claim that the applications or platform integration already work.
