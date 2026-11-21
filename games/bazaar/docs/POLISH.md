# Bazaar 0.0.3 — polish and third-person camera

Historical 0.0.3 evidence. Its avatar arm deformation was incorrect; see
[0.0.4 animation repair](ANIMATION_REPAIR.md) for the corrected transfer and checks.

14 November 2026. Separate local-world branch; no catalogue publication, merge,
Backend update, handheld installation or enabled Sparks spending.

## Camera

The earlier camera placed a small SDK avatar too far from the viewer. The default
boom is now 3 m outside and 2.4 m inside, scaled to SDK eye height within bounded
limits. The pivot is 0.85 m high for the guest and follows actual terrain height.
Default downward pitch is about 10° outside / 7° inside. Look can tilt upwards;
right-stick deadzone is rescaled continuously. Mouse uses screen-relative motion.

Menu FOV spans 75–105°, default **90° horizontal at 16:9**. This is an authored
choice for this world, not a universal third-person recommendation. Godot receives
58.7155° vertical at the default, with KEEP_HEIGHT: wider screens gain horizontal
view, rather than cropping the vertical view. FOV and fountain sound persist in
local preferences; no profile/account setting is changed.

The collision probe remains centered over the player in X/Z. Height and orbit
angles ease exponentially. A spherical SpringArm excludes the player's collider,
retracts at walls and hides the avatar only under very close compression. Entry
and return reset the pivot immediately; an indoor arrival no longer triggers the
exit prompt. Camera near distance stays 0.07 m.

References reviewed for this change: [Godot third-person spring arm](https://docs.godotengine.org/en/stable/tutorials/3d/spring_arm.html),
[Camera3D aspect and FOV](https://docs.godotengine.org/en/4.7/classes/class_camera3d.html),
[Unity third-person camera composition](https://docs.unity.cn/Packages/com.unity.cinemachine%403.1/manual/ThirdPersonCameras.html).
Collision, framing and distance are tuned together; merely increasing FOV would
leave the character smaller in frame.

## World and interface

Park gate, fountain mosaic, promenade edges and numbered stalls improve wayfinding.
Storefronts have striped awnings, hanging lanterns and readable signs. Tea tables,
cloth racks and curios pedestals distinguish the three rooms. Floors, rugs, beams,
lower counters and visible return doors finish this pass. Display objects remain
scenery; none represents inventory or a sale. Repeated props share meshes/materials
and enter the existing cell-based MultiMesh batches. Material overrides are retained.
Paving mortar is filtered using screen derivatives to reduce distant shimmer.

HUD text uses dark backplates; the menu exposes FOV and fountain sound. The fountain
has an original deterministic mono noise-based water bed with a loop crossfade and
18 m attenuation range. The generator is included; no recording was downloaded.
Pause silences it and teardown explicitly releases playback. Audio resource/lifecycle
checks do not constitute listening acceptance. Animation cadence follows movement
speed; wardrobe-wide retargeting and foot IK remain unverified.

## Evidence

[Headless](polish-evidence/headless.txt) and full [800×450 OpenGL walkthrough](polish-evidence/opengl.txt)
passed ([report](polish-evidence/report.json)). Checks cover 75/90/105° at 16:9,
16:10 and 21:9, character containment, wall retraction/recovery, movement,
collision, touch reset, shop return and retargeted motion. The [SDK socket](polish-evidence/sdk-socket.txt)
subscribe/revoke test passed. [Local preferences](polish-evidence/preferences.txt)
survived two source-runtime launches and ordinary Leave Bazaar calls.
Final source runs contain no script/shader errors or resource-leak warnings.
Software-renderer V-Sync/container-root warnings remain in the logs.

[Render log](polish-evidence/render.txt) · [source hashes matched to remote](polish-evidence/source-sha256.json)
· [binary hashes](polish-evidence/build-manifest.json) · [archive hashes](polish-evidence/package-sha256.json).
Archives and their embedded binaries were read back and hash-checked locally.
Linux x86_64 [rendered the actual exported world](polish-evidence/export-linux.png)
and the [Menu → Leave Bazaar path exited with code 0](polish-evidence/export-menu.txt).
This menu check preceded the final one-line root-window close signal binding;
headless walkthrough was rerun after that binding. Windows and ARM64 are exports
only, not runtime-tested. A [synthetic raw-X11 close-message check](polish-evidence/export-window-close.txt) timed out;
the same harness also timed out on the unchanged [0.0.2 control](polish-evidence/window-control.txt)
(which uses Godot default auto-quit). This does not establish a new game regression;
ordinary desktop window-manager close acceptance remains open. The menu exit
result is not substituted for that failed check.


- [Default third-person view](polish-evidence/park-arrival.png)
- [75°](polish-evidence/fov-75.png) / [105°](polish-evidence/fov-105.png)
- [Park gate](polish-evidence/park-gate.png) / [town](polish-evidence/town.png)
- [Tea room](polish-evidence/tea-interior.png), [tailor](polish-evidence/tailor-interior.png), [curios](polish-evidence/curios-interior.png)
- [Menu at 800×450](polish-evidence/stall-info.png)

The synthetic SDK avatar is supplied only to tests, never bundled in the game.
Normal views use the actual default gameplay camera. Island/park overview captures
alone disable distance culling. Render draw counts are not hardware FPS results.

Remaining: physical controller/touch acceptance, handheld performance, audio
listening, Windows/ARM64 runtime checks, catalogue-managed launch/return, networking,
realm selection/host migration, protected inventory transfers and real trading.
