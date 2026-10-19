# Game Roulette

**Type:** TrainerOS Start → Extensions widget  
**Status:** Basic concept agreed, not implemented.

A tiny gamepad-first widget that answers one question: **What should I play?**

## Core experience

1. Open **Start → Extensions** and focus Game Roulette.
2. Press one large, obvious **"Surprise Me!"** button.
3. The widget briefly cycles through existing game cover artwork in a **roulette-like animation**, then lands on a randomly selected game from the user's installed/available game library.
4. Show the chosen cover/title and a clear **Play** action using TrainerOS's normal supported launch flow. Press the roulette button again to reroll if desired.

The initial experience is deliberately **one-button and uncomplicated**. No new separate Games catalog, launcher or large settings page.

## Rules and integration

- Use games and metadata already known to TrainerOS, rather than scanning ROM folders or attempting a second scraper/library.
- Only offer entries confirmed available to launch with the current TrainerOS setup. If the known library is empty, show a clear empty state.
- Controller-first navigation and animation; do not steal global system shortcuts or interfere with the current game.
- Honor the existing Start dashboard widget sizing, focus and game/session lifecycle rules. Selection never launches a game until the player explicitly chooses **Play**.
- The animation is presentation only; the actual selection should be unbiased across the current eligible pool.

## Later, optional (not part of initial version)

Filtering by platform, collection or backlog is an **uncommitted follow-up idea**. Begin with one roulette covering the available library.

See [idea notes](docs/idea.md).
