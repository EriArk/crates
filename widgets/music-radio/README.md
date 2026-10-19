# Music Radio

**Type:** TrainerOS Start → Extensions widget
**Status:** Concept approved; not implemented.

Music Radio is **one lightweight radio widget**, using **only SoundCloud and imported M3U/M3U8 playlists**. No other commercial music-service integrations are planned.

## What the user can play

- **SoundCloud liked tracks:** listen to likes in randomized order (playback only; **no like/unlike buttons**).
- **SoundCloud playlists:** select an existing accessible playlist and shuffle it.
- **SoundCloud auto-radio/recommendations:** select music recommended by SoundCloud itself, if an authorized service interface actually provides it. Do not invent a recommendation engine.
- **M3U/M3U8 playlist:** import via TrainerOS Files, then play and shuffle a supported list of local audio files and/or playable direct HTTP(S) streams. A single uninterrupted live radio stream cannot shuffle individual songs.

## Widget controls

Play/Pause, Previous, Next, source selection, and track information where supported. Ideally playback continues in the background through the existing/planned TrainerOS Media Session, without interfering with game or voice audio.

## M3U specifics

Resolve relative file paths from the imported playlist's directory. Differentiate ordinary UTF-8 M3U8 track lists from HLS streaming manifests with the same extension; HLS needs actual backend support. Report missing files, dead URLs and unsupported streams. No automatic downloads or bypass of restricted music-service access.

## Project limits

Only **SoundCloud + M3U/M3U8**. No Spotify, YouTube Music, Navidrome or other providers; no full streaming UI, playlist editor or cross-service mixer. Keep it simple.

**Implementation still needs verification:** supported SoundCloud authentication and playback, whether likes and personalized recommendations are accessible through permitted APIs, and ARM64 performance. Evaluate mpv/libmpv for local playlist playback and official SoundCloud player/REST APIs for SoundCloud.

See [idea](docs/idea.md) and [integration notes](docs/service-integrations.md).
