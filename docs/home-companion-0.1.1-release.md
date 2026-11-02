# Companion (alpha) 0.1.1

Companion package refresh for the new TrainerOS Home integration:

- Seven visible autonomous idle behaviors with varied pauses.
- Notification wave, surprised face and an actionable speech bubble.
- Achievement icon held overhead with a happy expression and glow.
- Futuristic sliding doors hide model suspension and loading.
- Explicit Home-only widget policy; existing pet state is retained.

**These animations and lifecycle improvements belong to the TrainerOS shell.**
They require [host commit 5420614a](https://github.com/EriArk/TrainerOS/commit/5420614ab8e214f9409065acd201a69e14dc8a23)
or a later build containing it. Updating Companion alone does not update the
shell; older compatible shells keep their previous behavior. This package
updates the manifest, host source reference and release documentation; scenery
and props are unchanged.

In Crates, open **Companion (alpha)** and choose **Update**. Linux aarch64 and
x86_64 share the same data/Python archive. Sources, licenses and SHA-256 checksums
accompany the release. Removal/reinstallation preserves per-profile pet state.

Host validation: 71 automated checks and real Qt animation/lifecycle previews,
recorded in [TrainerOS evidence](https://github.com/EriArk/TrainerOS/tree/5420614ab8e214f9409065acd201a69e14dc8a23/docs/evidence/2026-11-02-companion-life).
Package validation uses the real Linux installer and launcher. No handheld
installation or hardware performance check is performed for this publication.
