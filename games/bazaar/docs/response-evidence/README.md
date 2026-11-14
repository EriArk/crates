# Bazaar 0.0.9 source checks — 14 November 2026

## Delivered on Flip 2 and Odin 2

The owner resumed handheld installation later on 14 November. Bazaar **0.0.9**
from `d8e371668799f887d02b14c85645c56b90b6e55a`, embedding shared SDK
`c45675a5b59d2e481e6b3f3883a6b5492b8088d2`, is now installed on both devices.
[Export/package hashes](package.json). The existing shell Software 45 and its
running process were preserved; no new shell sequence was consumed.

Actual-device remote keyboard/pointer checks covered Online → Bazaar → Festival
Park, both profile avatars, walk/run/sprint, crouch, jump, menu and normal Leave
back to the selected card. Godot logs were free of errors/warnings, with no live
game process after leaving. [Flip verification](flip-verification.json),
[Odin verification](odin-verification.json). This does not establish physical
stick/touch feel or sustained frame times; the 80% threshold has SDK test coverage.

Preferences remained byte-identical (Flip FOV 90°, Odin 75°); SQLite quick checks
and profile/owner/adventure counts passed. Personal captures remain private.
Task SD staging, scripts and screenshot caches were cleaned. The known old game
0.0.7 was removed after success; verified 0.0.8 remains as the one game rollback.
[Flip cleanup](flip-cleanup.json), [Odin cleanup](odin-cleanup.json).
No merge, public release, shell replacement or spending activation.

## Earlier source validation

No handheld contact, installation, merge or catalogue release. Installed 0.0.8
and shell Software 45 remain unchanged. Current SDK source/hashes are pinned in
`addons/traineros/SOURCE.json`.

## Movement

Raw left-stick input goes through the shared SDK radial mapping once: 18% inner,
20% outer dead zone, linear response in between. Full normal running speed is
available at 80% travel; sprint still requires its separate button. Camera input
is unchanged. Partial resolved movement uses Walk, not a slowed running clip.
Jog/Sprint retain the donor flight clearance instead of pinning the lowest foot
throughout the stride. Gravity and existing speeds have not been increased to
mask the original issue.

[20 motor checks](motor.txt) and [full world walkthrough](walkthrough.txt) passed
on Godot 4.7.2 on the existing server. The shared SDK's seven-state animation
report and OpenGL before/after comparison are [recorded upstream](https://github.com/EriArk/OctoFox-OS/blob/codex/bazaar-entry-device-20261114/docs/evidence/2026-11-14-bazaar-gait/README.md).
Bind/skin, reference arms, shoulder helpers and personal appearance are preserved.
The optional `tests/gait_review.gd` uses a synthetic avatar and a previous helper
only in a private review checkout; no personal model is bundled.

## Service reads

The menu queues the newest page refresh when a read is pending. Each open/switch
has a generation, preventing an earlier reply from filling a reopened page.
Failed/revoked reads clear prices and inventory; NPC prices come from server
seller offers, with unavailable/local-preview text when absent. Payment buttons
remain disabled. A failed SDK hello disconnects instead of leaving a dead client.

[Service checks](services.json) pass: twelve physical places and seller previews,
four enterable rooms, page-switch/reopen races, server price changes, failures,
revocation, no checkout and controller Back. OpenGL review used Xvfb/Mesa at
960×540. Tests use synthetic replies, not a live authenticated player's session.

The existing Backend is deployed with the verified Lobby application owner and
twelve official places. [Server evidence](https://github.com/EriArk/OctoFox-OS/blob/codex/bazaar-catalogue-20261110/docs/evidence/2026-11-14-bazaar-live-reads/README.md).
The native read bridge exists in the older feature branch; installed newer shell
integration remains pending. Save/profile custody, checkout and costume delivery
are unfinished. These source tests do not claim physical controller feel or FPS.
