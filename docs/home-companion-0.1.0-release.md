# Companion (alpha) 0.1.0

A gentle virtual pet for the TrainerOS Home widget slot, using your profile
avatar and outfit. Feed it, let it rest, switch between three scenes, and get
small achievement celebrations and notification hints. Playtime fills while
you play games; there is no Play button or punishment for a long absence.

**Requires an updated TrainerOS shell with `ui.home.widget:1` and
`avatar-care-v1`. Installing this package does not update the shell.** The host
integration is available in [TrainerOS source](https://github.com/EriArk/TrainerOS/commit/bf2bd9b30c089176657a2da37e47676a7d44b28d).
Deployment of that shell and handheld performance/input acceptance are pending.

In Crates, find **Companion (alpha)** under **What's New**, **Workshop** or
**Tools & Modules**. Install, then Open to select it on Home. Extra actions are
in the hamburger menu. Removal preserves your pet's profile state.

The same Python/data archive serves Linux aarch64 and x86_64; both architecture
records are included. This is a Crates alpha package, not an OS image or a shell
update. Source, licenses and SHA-256 checksums accompany the release.

Checks: real Linux installer lifecycle and launcher, installed-asset Qt preview,
Home/profile lifecycle and SDK admission tests. No handheld install or hardware
performance claim is made for this release.
