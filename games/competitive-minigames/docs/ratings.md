# Results & Ratings — Simple Shared Model

**Status:** product behavior agreed; implementation details deferred.

## One small result record per finished match

The game emits a compact result into a dedicated results destination, ideally using a **supported and permitted** Fluxer/TrainerOS route.

Illustrative 1-vs-1 record (field names are provisional, not an API contract):

```json
{
  "game_id": "tanks",
  "match_id": "8f21",
  "winner_id": "user_123",
  "loser_id": "user_456"
}
```

This is conceptually "Nikolai defeated Vasya", resolved by stable user IDs, not changeable names. A unique match ID helps ensure the same result is not counted twice on redelivery. Other match formats (teams, free-for-all, ties) remain to be defined.

## What each game tracks per player

- **Matches played:** every completed match.
- **Wins:** all wins, including repeated victories against the same person.
- **Losses:** all defeats, including repeat defeats.
- **Unique defeated opponents:** the number of distinct player IDs the player has **ever** beaten, not a count of their wins or a "latest head-to-head result" graph.
- **Status/rank:** increases with wins and decreases with losses; the exact formula is intentionally undecided. Matches played and unique defeated opponents are essential visible ranking context.

### Rematches

If Nikolai defeats Vasya five times, that means **five wins but one uniquely defeated opponent**. If Vasya wins the sixth match, Vasya receives one win and Nikolai receives a loss and a reduction in status. Historical wins and unique-opponent records stay intact; nothing is silently undone.

This counts **all** games and their outcomes, while distinguishing repeated wins from unique defeated players. Do not switch to a "only the latest win for each pair counts" system.

## Shared integration

- One shared mechanism for all 24+ competitive mini-games, not a dedicated ratings backend per game.
- Short match-result records keyed by stable game, match and user IDs.
- Suitable dedicated results destination; avoid flooding ordinary user chats.
- In-game access to relevant scores, standings and tournament context without constantly switching to Social.
- Storage and verification, trusted result submission/confirmation, provider limitations, exact rank calculation and tournament rules will be decided later.
- Fluxer is intended as reusable social/delivery infrastructure, **not assumed to be an unlimited or authoritative game database or approved real-time data relay**. Confirm its specific transport and usage limits before implementing.

Keep the implementation lightweight; do not invent a heavyweight federation, global profile economy, or mandatory game-specific server.
