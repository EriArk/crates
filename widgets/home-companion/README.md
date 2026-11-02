# Companion (alpha)

A small, forgiving virtual pet in the TrainerOS Home widget slot. Uses your
profile avatar and outfit. Feed it, let it rest, choose a room or garden, and
receive gentle achievement and notification reactions. Playtime fills through
actual foreground games: one hour adds 100 percentage points. No Play button,
death, progress loss or punishment for being away.

Install in **Crates → Companion (alpha) → Install**, then **Open**. You can also
choose Companion from the Home slot's widget picker. Touch and controller inputs
use the same actions; extra options live in the hamburger menu.

## Requirements

Version 0.1.1 records the updated host integration: seven autonomous idle
behaviors, a notification wave with a speech bubble, lifting the achievement
icon overhead, and sliding shutters around model suspension/loading. These
behaviors run in TrainerOS, not inside the downloaded package. They require
[host commit 5420614a](https://github.com/EriArk/TrainerOS/commit/5420614ab8e214f9409065acd201a69e14dc8a23)
or a later build containing it. Older compatible hosts retain their existing
behavior; the manifest remains `avatar-care-v1`. This release also explicitly
declares the Home-only policy (`allowStartWidgets: false`).

- TrainerOS with `ui.home.widget:1` and the trusted `avatar-care-v1` renderer
  (the Home companion integration from 2 November 2026 or newer).
- The shared TrainerOS avatar pack and a selected local profile.
- Linux aarch64 or x86_64, Python 3 for the optional app launcher.

**Updating this Crates package does not update TrainerOS. Older shells cannot
display the widget; update the shell first.** The alpha has server-side host,
package lifecycle and rendered-preview checks. Handheld installation and owner
acceptance remain pending.

Updates replace this package's scenery/props atomically. Removing it hides the
widget and preserves per-profile care state; reinstalling restores the selection.
The shell owns care, gameplay accounting, notifications and the avatar. This
package contains declarative contributions and assets, never downloaded QML
running inside the shell. No additional account, service or background process.

## Source and assets

Code and icon: GPL-3.0-or-later, see LICENSE. `traineros.py` is the shared optional
SDK client, copied without modification from the host revision recorded in
`host-source.json`; its full corresponding source is linked there. Original
generated backgrounds are redistributable project artwork. Kenney models are
CC0; individual licenses, source URLs, import hashes and provenance accompany
`assets/`. Character models remain in the shared SDK pack and are not duplicated.

Build on the server: `python3 package.py OUTPUT --revision FULL_GIT_SHA`.
The same architecture-independent Python/data archive receives explicit records
for both supported Linux architectures. Source and checksums accompany the release.
