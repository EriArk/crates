# Music Radio

**Category:** TrainerOS Widgets  
**Status:** Updated concept; no implementation yet.

A **single universal radio-style music widget** for TrainerOS. Instead of a separate mini-client for each music service, the widget lets the user pick a service and turn one of its music collections into a shuffle-based radio experience.

## Main flow

1. Choose a connected music service.
2. Choose a source from that service:
   - **Liked tracks** (all available liked/favorited songs).
   - **Existing playlist** chosen from the user's playlists.
   - **Auto-playlist / recommendation radio** offered by that service, based on listening history or related music.
3. Start listening with **random/shuffle playback** wherever the selected provider supports it.
4. Keep essential controls close at hand: play/pause, next, previous and current track information where available.

The service's **own recommendations** power the auto-playlists. This is not a new recommendation engine implemented by TrainerOS.

## Product principles

- One widget, consistent controls, one selected source at a time; not one separately installed player for each provider.
- **Liked tracks are a playback source only.** The widget does **not** offer like/unlike controls or manage a service's liked library.
- Designed as a simple personal radio, **not a full streaming service UI**: searching a vast music catalog, editing playlists and account management are not core goals.
- Ideally play in the background while browsing or gaming, through TrainerOS's shared media/audio-session capabilities.
- Internally, individual service connectors may be required, but they are implementation components of the **one unified widget**.
- Only show providers and sources that are actually accessible through supported authorization and provider APIs. A service-generated radio may not expose a list or custom shuffle control; show the real supported behavior instead of inventing one.

## Still open

Which services to support first, provider authorization/playback capabilities and restrictions, shuffle/recommendation semantics, widgets' exact controls/layout, background playback and capability-based fallback.

See [idea notes](docs/idea.md).
