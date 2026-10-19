# Music Radio — Open-Source Player and Service Integration Research

**Research date:** 2026-10-19. Source review / design candidates, not a working ARM64 deployment or approval from any commercial provider.

## Product scope (agreed)

One minimal TrainerOS Start → Extensions music radio widget. The user chooses a provider + liked songs / an existing playlist / the provider's own recommended radio, **or imports a local M3U/M3U8 playlist**, and uses shuffle where supported. It should play in background through shared TrainerOS Media Session. Do **not** add like/unlike controls or build a full music-service browser. Do not invent a TrainerOS algorithmic recommendation service.

## Playback and widget architecture

Prefer a **single compact widget with a small player/service backend**, not a complete embedded third-party app for each service.

- **Local/M3U/HTTP(S):** inspect `mpv` / `libmpv` for ARM64 playback and playlist/shuffle support. Native playback backend consumes user-authorized files and direct streams. Plain M3U/M3U8 text playlists are distinct from `m3u8` HLS manifests. Resolve relative file references from the playlist location. A live stream can only be skipped as a whole, not shuffled track-by-track.
- **Provider connectors:** where legally and technically supported, obtain accessible liked-track sets / playlists / service recommendations through a provider adapter and hand permitted streams or actions to the playback backend. Other providers may require their own native player, browser embedding, or remote control rather than supplying raw audio URLs.
- **Linux remote control:** MPRIS D-Bus can control a running compliant player (play/pause/next/current metadata, optionally playlists); it is useful for **control**, but cannot force a player that lacks a service-specific API to enumerate liked tracks or recommendation feeds. If relevant, integrate existing host media-session mechanisms instead of creating another system-wide media manager.
- Respect audio focus alongside game/voice, account-owned credentials and application lifecycle; don't ship provider client secrets in a distributable package.

## Service feasibility

### Local files, M3U playlists, direct radio streams — good first prototype

No streaming-service OAuth is required for user-owned local music or permitted public streams. Implement first, test ARM64 audio playback and game-audio coexistence.

Reference: https://mpv.io/manual/stable/

### SoundCloud — potentially workable official provider, with a substantial onboarding condition

- Official REST API supports OAuth 2.1 + PKCE, user likes and playlists, track playback/stream URL (when playable), and **related tracks** (`GET /tracks/{track_urn}/related`). Related tracks are a usable recommendation lead, not proof of a full personalized auto-radio endpoint.
- SoundCloud's official Widget API / oEmbed can embed user-chosen public tracks/playlists and permits programmatic playback/skip; explore it as a less intrusive playback option for public content in a supported webview. A widget embed alone does **not** prove user-liked library enumeration or access to private playlists.
- As of this research, SoundCloud's **API app registration requires an Artist Pro subscription**. Apps receive client ID/secret, and the secret must be kept confidential. This is a blocker for simply bundling unrestricted service login in an open-source widget; investigate viable authorized authentication/deployment options before promising it to general users.
- Not all tracks can be streamed off-site (preview/blocked/geo/paywall). Honor access and attribution.

Primary references:
- https://developers.soundcloud.com/docs/api/register-app.html
- https://developers.soundcloud.com/docs/api/guide
- https://developers.soundcloud.com/docs/api/explorer/
- https://developers.soundcloud.com/docs/api/html5-widget
- https://developers.soundcloud.com/docs/oembed

### Spotify — controllable official playback but severe open-source distribution constraints

- Spotify Web API has user playlists / liked songs endpoints and Premium-only player-control endpoints; for actual audio, control an existing Spotify/Connect device or use a sanctioned playback SDK where supported. The Web API by itself does **not** return raw stream URLs for playback in `mpv`.
- Spotify development apps were restricted in 2026: Premium app owner, **one** dev client ID, maximum **five authorized users**, and reduced endpoint permissions for new integrations. Wider access requires an extended quota/partner process, and individuals cannot simply request that as before.
- Since November 2024 new apps have lost API access to **Recommendations and Spotify-owned algorithmic/editorial playlists**. Thus auto-radio/Discover Weekly cannot be promised via the newly created public Web API integration. The playback app might still offer recommendations internally, but that is not a generally available API contract.
- Official browser Web Playback SDK requires proper browser/DRM support and Premium; not an assumed working Qt/ARM64 path.
- **librespot / spotifyd** can provide open-source local Spotify Connect playback with Premium but use unofficial implementations and are not an official Spotify-approved embedded SDK; assess maintenance, distribution rights and provider terms rather than shipping as guaranteed.

Primary references:
- https://developer.spotify.com/documentation/web-api/concepts/quota-modes
- https://developer.spotify.com/blog/2026-02-06-update-on-developer-access-and-platform-security
- https://developer.spotify.com/blog/2024-11-27-changes-to-the-web-api
- https://developer.spotify.com/documentation/web-api/reference/get-a-list-of-current-users-playlists
- https://developer.spotify.com/documentation/web-api/reference/start-a-users-playback
- https://developer.spotify.com/documentation/web-playback-sdk
- https://github.com/librespot-org/librespot
- https://github.com/Spotifyd/spotifyd

### Navidrome / Subsonic / OpenSubsonic — appealing optional provider

An existing user-operated Navidrome server exposes a documented Subsonic-compatible API for playlists, starred tracks, streaming and random songs. Some similar-song functionality depends on a Last.fm integration. This is a good example of a service connector without dependency on the commercial-service API permission process, although the user must already have a compatible server.

References:
- https://github.com/navidrome/navidrome
- https://github.com/navidrome/website/blob/master/content/en/docs/developers/subsonic-api.md

### YouTube Music and other services — future review

Possible open-source unofficial clients/connectors exist but do not imply provider authorization, robust streaming access, or stable recommendation feeds. Treat as candidates only after checking current terms, access and ARM64 behavior.

## Open-source projects worth examining

| Project | Strength | Caveat for TrainerOS |
| --- | --- | --- |
| [mpv / libmpv](https://mpv.io/manual/stable/) | Lightweight audio/video backend, playlists and shuffle; embeds behind our own interface | Not a service login/catalog/recommendations adapter |
| [Spotube](https://github.com/team-spotube/spotube) | Flutter cross-platform music player with community **provider plugins**; useful design reference | Large full client; unreviewed plugins may be unsafe and unofficial sources need compliance review |
| [Mopidy](https://github.com/mopidy/mopidy) | Python headless music server with modular service backends and local playback | Extra resident server/runtime; Spotify extension reports token/auth troubles, SoundCloud extension seeks a maintainer |
| [spotifyd](https://github.com/Spotifyd/spotifyd) / [librespot](https://github.com/librespot-org/librespot) | Small Rust Spotify Connect engine, including Linux audio backends | Premium-only, unofficial protocol, not a complete user-recommendations interface |
| [Navidrome](https://github.com/navidrome/navidrome) | Stable self-hosted library/service API with playlists | Server for the user's own library, not a general replacement for commercial music services |

Mopidy plugin evidence:
- https://github.com/mopidy/mopidy-spotify
- https://github.com/mopidy/mopidy-soundcloud

MPRIS standard:
- https://specifications.freedesktop.org/mpris/latest/

## Suggested order (proposal, not implementation approval)

1. **M3U / local / HTTP radio** using mpv/libmpv; tiny Start UI and Media Session coexistence on actual ArmadaOS ARM64.
2. **Provider adapter prototype** on a service with demonstrably available authorized API. SoundCloud official widget/embed for public playlists first; custom SoundCloud API only after credential/usage feasibility is addressed. Navidrome/OpenSubsonic is a straightforward optional proof.
3. **Spotify** as an explicitly conditional provider: validate a supported official Connect/controller workflow and account/developer limitations. Do not rely on unrestricted Spotify recommendations or assume a generic public app can serve every TrainerOS user.
4. Evaluate whether adapting Spotube or Mopidy modules is genuinely simpler than maintaining a few focused adapters. Favor a lightweight common interface over shipping an entire second music app.

## Not decided

Exact supported services, whether a local background process exists (and in what form), M3U import persistence/relative-path handling, how auto-radio suggestions update, how errors/restricted sources are presented, provider permissions and licensing, ARM64 compatibility/performance, and the interaction with existing host audio session lifecycle.
