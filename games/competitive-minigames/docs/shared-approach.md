# Shared Approach — To Discuss Later

## Core decision

**All competitive mini-games should use a common approach and compatible TrainerOS / Fluxer integration.** Avoid designing each game as an unrelated one-off solution.

## Intent captured so far

- Individual community per game.
- Automatic pre-fill of lobbies when context permits.
- Use Fluxer for relevant communication/data exchange wherever practical.
- In-game visibility of important social and competitive information, with no need to repeatedly open Social.
- Shared ability to support invitations, short matches, rematches, results, tournaments, rankings and leaderboards as relevant.
- Possibility of asynchronous competitions for games where that makes sense.

## Agreed simple results and ratings

The same result handling should serve all games. Once a match finishes, the game submits a small result record containing its game/match identity and stable participant IDs (not display names). Results are intended for a dedicated destination connected to the game/community, ideally using a permitted Fluxer route.

Track **total matches**, **all wins**, **all losses**, and **distinct opponents ever defeated** per game. Repeated wins against the same opponent still count as wins and played games, but do not add new unique opponents. A later revenge win is an ordinary new victory; it does not erase earlier match history or the opponent's historic unique-win record. Victories should raise a player's status; losses should lower it. The precise status/ranking formula has not been selected.

See [Results & Ratings](ratings.md) for the agreed example and open details.

## Deferred decisions

Architecture and APIs, division of responsibilities between TrainerOS / Fluxer / games, real-time P2P versus relayed networking, game states, persistence, result verification, precise rating/status formula, tournament structure, layouts, cross-device support and any common SDK are **not specified yet**.

The goal is one shared foundation, **not identical gameplay or compulsory features in every game**. Document and decide the common approach in a dedicated future discussion.
