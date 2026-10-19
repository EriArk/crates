# Friend Radar

**Category:** TrainerOS Start → Extensions widget  
**Status:** UX direction agreed; not implemented.

An **interactive visual radar** that finds **the user's Fluxer friends** and **any discoverable TrainerOS users physically nearby**. No public lobby listings, generic Fluxer community members or unrelated users on the Internet.

## User experience

1. Open Friend Radar in Start → Extensions; its expanded view displays a radar and a clearly visible **Scan** button.
2. Press **Scan**: the circular radar grows or pulses with an animated sweep. During the scan, discover/refresh:
   - **Friends:** retrieve available online/game activity from existing Fluxer/TrainerOS Social presence.
   - **Nearby:** optionally discover other TrainerOS devices in Bluetooth range or reachable on the local Wi-Fi/LAN, **whether or not the owners are friends**, using compatible system discovery capabilities.
3. Show the discovered people as radar contacts, **nickname** above and **current game** underneath when that information is genuinely available. Keep labels readable and avoid duplicates when a friend is also nearby.
4. Focus/select a contact to open existing Social/Lobby-related actions *only if supported and authorized*. Discovering a person does not mean their game has a joinable Lobby.

## On-demand operation and radio control

- Include a clear **Nearby scanning On/Off** toggle in the widget, preferably Off by default. It governs **this widget's** Bluetooth / Wi-Fi search, not the system-wide Bluetooth/Wi-Fi power switch or existing Nearby play settings.
- Do **not** continuously probe Bluetooth or Wi-Fi just because the widget is installed or present on a dashboard page.
- Start an active nearby scan **only when the expanded radar is actually open and the user presses Scan with Nearby enabled**.
- Stop/cancel scanning when the radar view closes, is minimized/hidden, loses the relevant UI lifecycle, or is cancelled. Avoid background discovery workers, resident caches/pollers and continuous network/memory load.
- Remote-friend presence should likewise be requested/refreshed on opening/scanning instead of building an independent permanent polling loop; reuse existing Social state.
- Never automatically turn on radios, connect to unknown access points, pair Bluetooth devices, or enable experimental Wi-Fi Direct. If a radio, permission or service is unavailable, say so without disrupting the current network.
- The widget must **not** disable the host's separately owned Nearby play operation just because its own scan ends.

## Visual design

- **Radar metaphor** is the key feature: a circular field, animated sweep and an expanding ring while scanning.
- Contacts show **nickname** and a smaller **game title** beneath; if no game is known, show a simple accurate idle/unknown status rather than fabricate one.
- Distinguish a **Fluxer friend** from an **unfriended nearby TrainerOS user** with a modest indicator, without clutter.
- Radar positions are illustrative unless a supported proximity/distance source exists; don't claim meter-accurate Bluetooth/Wi-Fi positioning or exact physical distances.
- Use TrainerOS controller focus, safe areas and responsive Start widget behavior.

## Integration and privacy

Reuse existing TrainerOS Nearby discovery (BlueZ/Bluetooth and ordinary LAN discovery) and Fluxer identity/presence systems; extend only missing narrow capabilities rather than adding a second radio/network daemon. Nearby names and current-game disclosure depend on the other user's existing/explicit discoverability and sharing settings. No unsolicited joining, automatic friend requests, personal identifiers or private lobby details.

**Still to decide:** exact indicator styles, whether friends who are online but not gaming should be shown, refresh/expiry behavior, game-status disclosure across nearby devices, and small vs expanded widget layout. Do not add unrelated people/community lobby search.

See [idea notes](docs/idea.md).
