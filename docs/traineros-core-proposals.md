# TrainerOS Core Features — Selected Ideas Outside Crates

These have been selected as **core TrainerOS features**, not independent installable Crates. They are recorded here to avoid misclassifying the brainstorming ideas. This file does not mean any feature is already implemented or that a GitHub issue has been created.

## Performance Profiles

Per-game performance/system profiles should belong in TrainerOS proper, using the real features available in ArmadaOS and later SteamOS/Bazzite. This is **not** the optional standalone extension imagined in the initial brainstorm. Details remain to be specified.

## Gyro Bridge

Gamepad/handheld gyroscope integration, mappings and relevant settings belong to TrainerOS core input handling. Detailed supported sensors and behavior remain to be discussed.

## Challenge Cards

**Approved as a built-in TrainerOS Social/game capability, not a separate Fluxer Activity app.**

- Players can send each other game challenges represented as clear, compact cards (a title/goal and who is challenged).
- Cards should use existing Social/Fluxer identity, conversations and the same Lobby/game flows when a live session is involved.
- A supported game may attach results or progress; asynchronous challenges should not require a live game session.
- Core TrainerOS owns the common experience, individual games supply supported challenge types and outcomes.
- No new main tab or parallel chat, and no fabricated provider feature or unlimited packet route.

Exact challenge formats, expiration, validation, presentation and rules are for a later design pass.
