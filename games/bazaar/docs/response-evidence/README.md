# Bazaar 0.0.9 source checks — 14 November 2026

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
