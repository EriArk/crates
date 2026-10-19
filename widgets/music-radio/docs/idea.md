# Music Radio — Refined Concept

## Current idea

**Universal radio widget for music services.** Choose a service, then select one of:
- The user's liked music.
- An existing playlist.
- A service-generated auto-playlist / radio of music similar to what the user listens to.
- An imported local `.m3u` or `.m3u8` playlist of audio tracks or supported streams, independent of a music-service account.

Hit play and listen in randomized order if that source/service permits it. A single live radio-stream URL may not offer track-level shuffle.

**Scope clarification:** liked tracks remain a radio source. The user does **not** want controls to add or remove likes from within this widget.

**Important:** auto-playlists here specifically mean *recommendations made by the original music service*. The widget does not need to train its own recommender or merge libraries across services.

## What changed

The earlier concept was **one separate miniature player per service**. It has been superseded: now it is **one common widget with service connectors** and a simple radio-like user experience.

Selection is per service/source. Cross-service mixing, custom playlists and full client features are **not required** in the current concept.

## M3U import specifics

Use the shared TrainerOS file picker to import regular M3U or UTF-8 M3U8 playlist files. Resolve relative local paths from the playlist's directory; URLs require a working, supported media source. Do not mistake HLS `.m3u8` transport manifests for an ordinary list of songs: those need proper stream playback support. Import is local user content, not a Spotify/SoundCloud streaming bypass.

## Implementation constraints for later

Use the existing TrainerOS Media Session and Start → Extensions model if and when implemented. Do not assume every service exposes liked tracks, algorithmic radio or unrestricted playback through its API. Confirm each integration and its allowed player behavior separately. No provider support or technical route has been verified by this concept document.

Detailed UX and technical design will be discussed later.
