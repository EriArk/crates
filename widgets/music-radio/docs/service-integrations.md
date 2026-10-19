# Music Radio — SoundCloud + M3U Integration

**Scope fixed 19 October 2026:** research notes, not a finished ARM64 implementation.

## Only two source types

1. **M3U/M3U8:** locally imported list of audio files or playable direct streams; random track order where possible.
2. **SoundCloud:** liked tracks, user playlists, and service-provided auto-radio/recommendations **where actually supported**. Liked songs are for listening, not for like/unlike actions.

**Out of scope:** other providers, universal streaming adapter architecture, full music client, custom recommendation service.

## Useful existing open-source components

- [mpv / libmpv](https://mpv.io/manual/stable/): lightweight native media playback candidate for local files, M3U, HTTP radio and supported HLS. It does not implement SoundCloud user authentication, likes or recommendations.
- [Mopidy](https://github.com/mopidy/mopidy) and [mopidy-soundcloud](https://github.com/mopidy/mopidy-soundcloud): examples of a headless music player with a SoundCloud extension. Consider as integration references, but confirm extension maintenance; a large resident Python service may be excessive.
- [SoundCloud HTML5 Widget API](https://developers.soundcloud.com/docs/api/html5-widget): official embedded player controls for available tracks and playlists; does not automatically expose all private likes or personalized recommendations.
- [SoundCloud REST API](https://developers.soundcloud.com/docs/api/guide): investigate supported access to likes, playlists, related music and available playback endpoints. Related tracks are not proof that a personalized auto-radio feed exists.
- [MPRIS](https://specifications.freedesktop.org/mpris/latest/): player-control model if useful, but prefer TrainerOS's existing Media Session to avoid duplicate services.

## SoundCloud caveats

The previous API review found that SoundCloud app registration may require **Artist Pro**. Confirm current requirements via [official registration](https://developers.soundcloud.com/docs/api/register-app.html) before implementation. API credentials and secrets must not be hard-coded in distributed clients.

Availability of audio, liked tracks, private playlists and recommendations depends on supported service permissions and playback methods. A third-party widget should show unsupported options honestly rather than attempt unofficial access circumvention.

## M3U implementation details

- Import through TrainerOS Files; make the selected playlist reusable.
- Resolve relative music paths against the playlist's original location.
- Direct HTTP(S) radio streams and local music require supported codecs.
- Distinguish plain track-list M3U8 from adaptive HLS manifests. A live stream plays continuously; it cannot shuffle its contents at individual song level.
- Never treat a SoundCloud web-page URL inside an M3U as direct playable audio that bypasses SoundCloud restrictions.

## Proposed sequence

1. Build the smallest M3U shuffle player with mpv/libmpv; verify on ArmadaOS ARM64 and background audio coexistence.
2. Prototype permitted SoundCloud playback through its official embedded player or authenticated APIs; verify access to the desired collection types.
3. Present both through the same small widget and TrainerOS Media Session.

**Open:** exact auth/playback path, available recommendations, track availability restrictions, HLS handling, resource usage and UI specifics. No other provider work planned.
