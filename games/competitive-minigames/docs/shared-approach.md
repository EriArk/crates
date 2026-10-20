# Shared Approach — To Discuss Later

## Core decision

**All competitive mini-games should use a common approach and compatible TrainerOS / Fluxer integration.** Avoid designing each game as an unrelated one-off solution.

First-party AbyssTail games are designed as **TrainerOS-integrated exclusives**, relying on shared Social, Lobby, account/economy and SDK services rather than artificial DRM; individual games implement only what they actually need. This is an approved **direction**, not a finished dependency/API. See [TrainerOS Ecosystem](../../../docs/traineros-ecosystem.md). Verified competitive results and currency rewards are separate from the rank/status formula; supporter earning multipliers must not alter match results.

## Intent captured so far

- A default community per game, plus optional support inside other Fluxer communities enabled by their authorized admins (see [community support](community-support.md)).
- Automatic pre-fill of lobbies when context permits.
- Use Fluxer for relevant communication/data exchange wherever practical.
- In-game visibility of important social and competitive information, with no need to repeatedly open Social.
- Shared ability to support invitations, short matches, rematches, results, tournaments, rankings and leaderboards as relevant.
- Possibility of asynchronous competitions for games where that makes sense.

## Community choice and opt-in

A player should be able to use the official/default game community or choose another participating Fluxer community. A community can enable support for the competitive games; suitable supporting subchannels/categories are then created **only with valid community permissions**, reusing the same TrainerOS Lobby and competition foundations.

The exact channel template, whether enablement is per-game or collection-wide, and local/global leaderboard scope remain open. See [Optional Fluxer Community Support](community-support.md).


## Future clan battles (idea only)

Clans using Fluxer communities may someday challenge each other through the common mini-game/lobby/results integration. Clan membership rules, eligibility and scoring are not defined yet. See [Fluxer Clans & Clan Battles](../../../concepts/clan-battles/).

## Agreed simple results and ratings

The same result handling should serve all games. Once a match finishes, the game submits a small result record containing its game/match identity and stable participant IDs (not display names). Results are intended for a dedicated destination connected to the game/community, ideally using a permitted Fluxer route.

Track **total matches**, **all wins**, **all losses**, and **distinct opponents ever defeated** per game. Repeated wins against the same opponent still count as wins and played games, but do not add new unique opponents. A later revenge win is an ordinary new victory; it does not erase earlier match history or the opponent's historic unique-win record. Victories should raise a player's status; losses should lower it. The precise status/ranking formula has not been selected.

See [Results & Ratings](ratings.md) for the agreed example and open details.

## Optional shared Backend for official scores (planned)

The [TrainerOS Backend plan](https://github.com/EriArk/TrainerOS/blob/main/docs/TRAINEROS_BACKEND_PLAN_RU.md) describes a small authenticated results service that **may eventually** compute official standings, daily competitions, tournament results, clan rankings and prizes for compatible games.

- Games still run on user devices through suitable P2P/LAN/approved transport; **the VPS is not a mandatory realtime game relay**.
- Only checked match outcomes and small event metadata belong on the Backend; no video, arbitrary game state stream, ROMs or saves.
- Do not treat a client-submitted winner ID as proof. Result verification, rewards and the exact rank/status formula remain to be designed.
- Offline/local games and supported peer sessions should continue independently when the Backend is unavailable.
- Shared Backend proposals are **not implemented platform capabilities** nor requirements for every small game.

See also [Backend integration summary](../../../docs/backend-integration.md).

## Deferred decisions

Architecture and APIs, division of responsibilities between TrainerOS / Fluxer / games, real-time P2P versus relayed networking, game states, persistence, result verification, precise rating/status formula, tournament structure, layouts, cross-device support and any common SDK are **not specified yet**.

The goal is one shared foundation, **not identical gameplay or compulsory features in every game**. Document and decide the common approach in a dedicated future discussion.
