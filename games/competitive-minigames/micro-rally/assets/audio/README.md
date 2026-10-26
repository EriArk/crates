# Micro Rally audio

All downloaded recordings in this folder are released by their authors under
[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).
The game's original procedural sounds and playback code remain GPL-3.0-or-later.

| Files | Author / original page | Use |
| --- | --- | --- |
| race.ogg | [Umplix: Super Wreck Roadway](https://opengameart.org/content/super-wreck-roadway) | Looping action rock during a race |
| menu.ogg | [Umplix: Rock Theme 3](https://opengameart.org/content/rock-theme-3) | Menu and garage rock loop |
| impact0/impact1.ogg | [Kenney: Impact Sounds](https://kenney.nl/assets/impact-sounds) | Metal collisions |
| shield/wreck.ogg | [Kenney: Sci-fi Sounds](https://kenney.nl/assets/sci-fi-sounds) | Force field and compact explosion |
| win/finish/dnf/final_lap.ogg | [MintoDog: Racing Game Finish & Jingle](https://opengameart.org/content/racing-game-finish-jingle) | Race milestones |

Music was normalized and converted from the authors' loop WAVs to Vorbis q4,
44.1 kHz. Sound effects/jingles are unmodified Ogg files from the original packs.
See `provenance.json` for exact members, source/output SHA-256, sizes and duration;
the original Kenney notices are retained. Author pages/license declarations were
checked on 26 October 2026. No voice recordings or vocals are used.

Reproduce on the build server with `tools/prepare_audio.py`, Python 3 and ffmpeg.
Mount the source-cache directory at `/audio` in a disposable build container.
Only prepared runtime files belong in the game; source WAVs/zips stay on the server.
