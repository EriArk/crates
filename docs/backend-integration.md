# TrainerOS Backend — connection to Crates

**Discussed 19–20 October 2026. Status: documentation/planning only; no new API or server is deployed because of this note.**

The **canonical technical plan is in the main TrainerOS repository**:

- [TrainerOS Backend — shared server plan](https://github.com/EriArk/TrainerOS/blob/main/docs/TRAINEROS_BACKEND_PLAN_RU.md)
- [Crates — VPS data, install recipes and artifact hosting](https://github.com/EriArk/TrainerOS/blob/main/docs/CRATES_SERVER_STORAGE_RU.md)
- Existing Crates owners: [#144](https://github.com/EriArk/TrainerOS/issues/144), [#146](https://github.com/EriArk/TrainerOS/issues/146), [#147](https://github.com/EriArk/TrainerOS/issues/147), [#148](https://github.com/EriArk/TrainerOS/issues/148)

## What Crates may use

- A **small owner-hosted catalog**: stable project/version metadata, order/featured membership, release hashes, compatibility data, short descriptions, limited artwork and revision/delta feed.
- **Verified declarative installation recipes**, dependencies and bounded compatible configuration/profile files — no automatic execution of arbitrary network-supplied shell scripts.
- **GitHub Releases** for downloading executable archives, games, applications and large assets. Server catalogs link to verified allowed artifacts rather than mirroring binaries.
- Shared official game results, rankings, tournaments, Arcade Today, clans and possible prize metadata **only if/when those features are separately designed and implemented**. Do not send live gameplay frames through this server.

## Gameplay boundary

All 24+ competitive mini-games should use the same integration pattern, but **are not obligated to require an online Backend merely to run**. Fluxer retains friend/community identity and ordinary communication; GameHub Lobby retains sessions; a planned Backend may verify shared competition records. Host capabilities and actual network transport constraints determine what each game can use.

## Never on the VPS by default

User ROM/BIOS and saves, private conversations, media streams, account secrets, executable package mirrors and unchecked install scripts. Do not create a second social network, game launcher, package manager or reviews system.

## Planning note

A modest VPS with approximately 80–160 GB SSD was discussed as sufficient for an early lightweight API/catalog/competition metadata design. This is **not a tested capacity claim**, a finalized server order or a guarantee for 10,000 concurrent users. Verify real disk growth, traffic, API latency and backups before choosing a production plan.
