# Music Radio

**Category:** TrainerOS Widgets  
**Status:** Updated concept; no implementation yet.

A **single universal radio-style music widget** for TrainerOS. Instead of a separate mini-client for each music service, the widget lets the user pick a service and turn one of its music collections into a shuffle-based radio experience.

## Main flow

1. Choose a connected music service **or** an imported local playlist.
2. Choose a source from that service (or the imported playlist):
   - **Liked tracks** (all available liked/favorited songs).
   - **Existing playlist** chosen from the user's playlists.
   - **Auto-playlist / recommendation radio** offered by that service, based on listening history or related music.
   - **Imported M3U/M3U8 playlist** with playable tracks or stream URLs, without requiring an account.
3. Start listening with **random/shuffle playback** wherever the selected provider or source supports it.
4. Keep essential controls close at hand: play/pause, next, previous and current track information where available.

The service's **own recommendations** power the auto-playlists. This is not a new recommendation engine implemented by TrainerOS.

## Product principles

- One widget, consistent controls, one selected source at a time; not one separately installed player for each provider.
- **Liked tracks are a playback source only.** The widget does **not** offer like/unlike controls or manage a service's liked library.
- Designed as a simple personal radio, **not a full streaming service UI**: searching a vast music catalog, editing playlists and account management are not core goals.
- Ideally play in the background while browsing or gaming, through TrainerOS's shared media/audio-session capabilities.
- Internally, individual service connectors may be required, but they are implementation components of the **one unified widget**.
- Only show providers and sources that are actually accessible through supported authorization and provider APIs. A service-generated radio may not expose a list or custom shuffle control; show the real supported behavior instead of inventing one.

## M3U / M3U8 playlist import

- Choose a local `.m3u` or `.m3u8` file through TrainerOS Files and add it as a reusable source in Music Radio.
- Support ordinary M3U playlists pointing to local audio files and permitted HTTP(S) audio/radio streams; handle relative file paths relative to the playlist's location, not the widget's working directory.
- Differentiate plain UTF-8 `.m3u8` track playlists from HLS adaptive-stream manifests (also `.m3u8`); delegate HLS decoding to a capable media backend only when actually supported.
- Shuffle finite track lists where possible; a single live radio stream generally cannot shuffle its underlying songs.
- Show missing files, dead URLs, unsupported formats and unavailable credentials honestly; an M3U containing music-service web page links does not grant playback access to restricted streams.
- No automatic media downloads or blanket access to other users' folders.

## Still open

Which services to support first, provider authorization/playback capabilities and restrictions, shuffle/recommendation semantics, M3U media formats/backend, widgets' exact controls/layout, background playback and capability-based fallback.

See [idea notes](docs/idea.md) and [service/player research](docs/service-integrations.md) (19 October 2026).
