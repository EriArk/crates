# Ghost Racing

**Type:** Extension for TrainerOS  
**Status:** Selected concept, not implemented.

A reusable asynchronous racing/challenge feature: compete with a recording of another player's past run instead of requiring both players online at once.

## Initial scope

- Record a compact compatible run representation (inputs, state snapshots or telemetry depending on the game).
- Replay it as a visible ghost inside a game that explicitly supports it.
- Exchange a challenge and results between players through supported TrainerOS/Fluxer data routes.

## Integration notes

Not a generic ability to inject a ghost into any existing game or ROM. Intended first for our authored compatible mini-racing games, potentially other timing/racing titles. Replay validation, versions, timing and fairness are deferred.

**Next:** Discuss detailed UI, technical approach and scope later.

See [original idea notes](docs/idea.md).
