# Achievement Coins — shared TrainerOS currency

> **Owner-approved ecosystem concept, 20 October 2026; not implemented.** The original exploratory question "what are the coins for?" is resolved: **spendable cosmetic currency** used throughout TrainerOS and the creator's own TrainerOS-exclusive games. Exact rates, item prices and technical delivery remain open.

## How it works

- **One shared balance** linked to a portable **TrainerOS ID**, distinct from the existing offline Trainer and external Fluxer/RA accounts.
- Earn coins through eligible **verified game completions, RetroAchievements and events in the creator's games**; not every arbitrary claim or imported save is valid reward evidence.
- The **cosmetic shop is open to everyone without a subscription**. Purchases may be shell-wide or game-specific, and never grant an advantage in matches or rankings.
- Once bought, cosmetics **remain owned after Patreon/Ko-fi support is canceled**; unspent coins also remain.
- A supported active Patreon/Ko-fi membership **multiplies eligible future coin earnings by up to ×3**, depending on supporter tier. Higher tiers may include early access to closed dev/beta game/add-on builds. No approved cosmetic-store discounts.
- Previously discussed **direct sale of coin packs, subscription-locked spending and fixed monthly coin grants** are superseded; the current monetization model is **subscriptions with earning multipliers**.

## Validation and platform ownership

Backend owns the authoritative coin ledger, purchase records, entitlement checks and membership verification. A client cache is not the wallet's source of truth; duplicate reward IDs must not mint coins twice. Existing [Save Lineage #93](https://github.com/EriArk/TrainerOS/issues/93) is groundwork, **not proof of honest play**; [Verified Session #94](https://github.com/EriArk/TrainerOS/issues/94) requires bounded emulator/config/save continuity checks. Do not lock ordinary local gameplay or over-engineer anti-cheat for cosmetic rewards.

## Deferred

Exact subscription tiers (lowest supporter tier considered around $1/month), intermediate multipliers up to ×3, award rates, verification per game, one-time achievement behavior, balance and catalog pricing, offline submission/reconciliation, provider linking/recovery, entitlement UX, or any coin trading/transfer/cashout policies. **None of this has been settled.**

## Related

- [Original idea record](docs/idea.md)
- [TrainerOS Ecosystem rules](../../docs/traineros-ecosystem.md)
- [Canonical TrainerOS Account & Economy](https://github.com/EriArk/TrainerOS/blob/main/docs/TRAINEROS_ACCOUNT_ECONOMY_RU.md)
