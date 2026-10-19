# Friend Radar — Approved Concept

A **real radar-style widget**, rather than an ordinary list of friends.

## Who appears

- **Fluxer friends**, with nickname and current game when available.
- **Any physically nearby TrainerOS users whose devices are discoverable** through supported Bluetooth or local Wi-Fi/LAN mechanisms, even if they are not friends.
- **Not** random strangers on Fluxer, public community members, or a global lobby directory.

## Interaction

- Open the expanded view in Start → Extensions.
- A **Nearby On/Off** toggle prevents unnecessary Wi-Fi/Bluetooth scanning; this affects the widget's discovery, not radio power or general OS settings.
- Press **Scan** to trigger a short on-demand refresh. A circular animated radar expands/sweeps, revealing contacts with their **nickname** and **game** beneath.
- Active radio search exists **only while this view is open** and is cancelled when hidden or closed. No persistent background scanning or excessive memory/radio load.
- Existing Fluxer presence may provide friends' activity without local radio discovery. Show unsupported/missing game data honestly.
- Nearby users do not need to be friends, but their privacy/discoverability choices and permission boundaries must be respected.
- Any interaction after selecting a contact must reuse normal TrainerOS Social and Lobby behavior.

## Technical note

TrainerOS already has a Nearby play integration using Bluetooth and ordinary LAN discovery; reuse it if possible. Avoid turning on Bluetooth/Wi-Fi automatically, changing hardware/network configuration or relying on unproven Wi-Fi Direct. A drawn radar position is not an exact measured distance.

**Status:** concept recorded, not a claim of an implemented widget or new background discovery service.
