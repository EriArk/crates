# TrainerOS Ecosystem — First-party Games, Accounts & Monetization

> **Owner-approved concept, 20 October 2026. Planning only:** no wallet, store, subscription integration or platform API is claimed to be shipped here. The canonical product contract is [TrainerOS Account & Economy (RU)](https://github.com/EriArk/TrainerOS/blob/main/docs/TRAINEROS_ACCOUNT_ECONOMY_RU.md).

## First-party exclusives by integration, not DRM

**AbyssTail's own games are intended as TrainerOS exclusives.** This does **not** mean restricting third-party Linux games, emulators, independent software or open Platform SDK use.

- Each game owns its original gameplay, content, mechanics and game-specific logic.
- TrainerOS provides reusable platform functions: TrainerOS ID, wallet/cosmetic entitlements, Fluxer Social, existing GameHub Lobby, invitations and multiplayer integration, progress/verified achievements where applicable, Crates distribution and relevant Platform SDK services.
- First-party games deliberately rely on these common TrainerOS functions rather than rebuilding their own social system, accounts, currency store and launcher. Removing TrainerOS naturally removes a meaningful part of the integrated experience.
- **No additional aggressive DRM or specialized emulator protection** is needed merely to force exclusivity.
- Not every game needs every service. Keep simple games simple; games should not require the owner-hosted Backend to execute their local gameplay unless a specific game genuinely requires an online service.
- Crates remains the distribution and update UI (with approved GitHub Releases as package hosting); Fluxer owns social communication; **one** GameHub Lobby serves compatible games. Do not create duplicate systems per game.

## Shared TrainerOS Account

There are two separate identity layers:

- **Local Trainer:** existing device-scoped profile, settings, history and saves; works offline and supports multiple Trainers on one device.
- **TrainerOS ID:** stable online identity for shared coin balance, cosmetic purchases, verified rewards, subscription modifiers and eligible closed builds across first-party games.

Fluxer is the intended login/social identity provider, **not** the permanent wallet ID. The Backend must link external identities securely and allow safe account recovery/relinking without silently losing purchases. RetroAchievements provides supported achievement evidence; Patreon/Ko-fi provides verified paid membership. No additional standalone TrainerOS password registration should be required, and optional online participation must not prevent ordinary offline use.

## Agreed monetization

| Area | Agreed direction |
| --- | --- |
| Currency | **One** shared earnable TrainerOS coin balance for the shell and first-party games |
| Earning | Supported verified game completions, RetroAchievements and eligible first-party game activity |
| Store | **Open to everyone**, even with no subscription |
| Purchases | **Cosmetics only**, with no match/ranking advantage |
| Ownership | Purchased cosmetics and unspent coins stay after canceling support |
| Base earnings | **×1** without a subscription |
| Paid support | Patreon/Ko-fi membership raises the **earning multiplier, capped at ×3** |
| Higher support tiers | Potential early access to upcoming games/add-ons and closed dev/beta builds |
| Discounts | **Not part of the approved model** |
| Direct coin packs / monthly coin grants | Superseded by the **earnings-multiplier** idea; not the current model |

The owner is considering a **very low entry tier around $1/month**, but exact prices, intermediate multipliers, tier count, reward rates and cosmetic prices **are not defined**. Community perks mentioned in brainstorming are proposals, not commitments. Do not retroactively multiply one-time rewards without an explicit policy.

A cosmetic may be shell-wide or specific to a particular game. A shared wallet does **not** imply that every purchased item can be used in every game.

## Trust and platform boundaries

Backend is the authority for the ledger, purchases, entitlements and verified membership; client caches may display offline but cannot authorize new spending. Duplicate events should not mint currency twice. Offline gameplay and saves must stay usable when Backend is down; unconfirmed official rewards and purchases cannot be silently declared complete.

Retro reward eligibility uses a realistic, narrow verified-session policy: supported pinned runtime/config, continuous save lineage, approved achievement/completion evidence and optional server anchors. [Save Lineage #93](https://github.com/EriArk/TrainerOS/issues/93) is an existing foundation, **not proof of fair play**; [Verified Session #94](https://github.com/EriArk/TrainerOS/issues/94) is still policy/implementation work. Do not build disproportionate RAM-level or hardware anti-cheat for cosmetic rewards. Ordinary single-player freedom remains.

Competition records/rankings and official coin rewards may share validated event metadata, but **rating points and spendable coins are not the same thing**. Competitions must not become pay-to-win because of subscription multipliers.

## Deferred, not implicit decisions

Exchange rates, actual item prices and earning rates; subscription tiers and provider verification; per-game rewards and replay/one-time-achievement treatment; offline pending events; entitlement recovery; marketplace design; closed build distribution/retention; coin trading, real-money redemption or transfer; whether and how individual games are sold. None are specified by this document.

## Related documentation

- [Achievement Coins](../concepts/achievement-coins/) — the shared earnable currency concept
- [Backend integration](backend-integration.md)
- [Competitive mini-games](../games/competitive-minigames/docs/shared-approach.md)
- [TrainerOS Backend plan](https://github.com/EriArk/TrainerOS/blob/main/docs/TRAINEROS_BACKEND_PLAN_RU.md)
- [Platform SDK #235](https://github.com/EriArk/TrainerOS/issues/235)
