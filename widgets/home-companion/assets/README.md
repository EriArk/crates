# Home companion art preparation

Prepared 2026-11-02. Food, lounge chair and the three backgrounds are connected
to the Home companion source implementation; other props remain prepared assets.

`manifest.json` records the 14 selected Kenney props, original archive/file hashes,
output hashes and triangle counts. Source licenses remain in each pack directory.
These props are **CC0-1.0**, separate from TrainerOS's GPL source-code license.
Thank you, Kenney. Only external PNG images were embedded into self-contained GLB;
geometry, materials and node transforms were retained.

Rebuild with the host `tools/home_pet/import_props.py`; original ZIP archives belong in the
server research cache, not the repository. Mesh sizes do not prove frame rate.
`animations.json` describes the downloaded free Quaternius animation sources;
the original rigs/clips are not shipped here or retargeted yet.

See [accepted behavior, art selection and remaining work](https://github.com/EriArk/TrainerOS/blob/bf2bd9b30c089176657a2da37e47676a7d44b28d/docs/HOME_COMPANION.md).

## Backgrounds

Three new background plates were generated with the built-in image_gen tool:
`backgrounds/cozy-room.png`, `backgrounds/sunny-garden.png`, and
`backgrounds/evening-nook.png`. Full prompts are in `background-prompts.json`.
These generated illustrations are not Kenney/Quaternius assets and are not
covered by those authors' CC0 notices. Original generated files are retained;
no avatar, UI, food or central movable furniture is baked into the plates.

Use a bounded QML Image sourceSize for the widget's physical display size and
load only the selected background. Match the live avatar camera, lighting and
contact shadow to the background. Do not use the room as a free-rotation 3D
environment. Wide/compact real-avatar screenshots are retained in
[companion evidence](https://github.com/EriArk/TrainerOS/blob/bf2bd9b30c089176657a2da37e47676a7d44b28d/docs/evidence/2026-11-02-home-companion/README.md);
handheld acceptance remains separate.

## UI icons

`ui/*.svg` are original TrainerOS vector source icons, GPL-3.0-or-later.
They are not part of the Kenney CC0 asset packs. The gamepad is a read-only
playtime indicator; there is no Play action.
