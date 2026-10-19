# Music Radio — Agreed Concept

One compact TrainerOS radio widget with **two kinds of sources: SoundCloud and imported M3U/M3U8 files**.

## SoundCloud

- Play liked tracks on shuffle (likes are a **source**, not editable from the widget).
- Choose an existing playlist.
- Choose a SoundCloud-generated auto-radio/recommendation source when genuinely available.
- Minimal player controls only.

## M3U/M3U8

- Import playlists with the normal TrainerOS file picker.
- Play user-owned local audio files or authorized direct audio URLs.
- Randomize a finite track list, but not the individual songs inside a live stream.
- Treat HLS M3U8 manifests distinctly from song playlists.

## Scope clarification

Earlier concepts included separate player clients and later a multi-service provider platform. **Both are superseded.** SoundCloud and M3U/M3U8 alone are sufficient; do not implement other music services. No like/unlike controls, proprietary recommendation engine, playlist editor, or full music browsing client.

## Next design work

Verify SoundCloud service APIs and playback restrictions, authorization, recommendation source accessibility and background audio behavior; test the minimal playlist player on ARM64. One widget, as few moving parts as practical.
