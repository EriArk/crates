# Session Timer

**Type:** App with a Start widget for TrainerOS

**Status:** 0.1.0 experimental implementation. Desktop verification; handheld acceptance pending.

A session stopwatch with a compact Start widget and optional visual break reminders.
Run it from Apps, then add **Session Timer** through **Start → Edit → Add**.
Press the widget to start/pause, or acknowledge a break reminder. The app window
also has Reset, mode and reminder controls. Minimize the window to keep the widget alive;
**Close timer** closes the process and removes its live widget.

## Timing and controls

- **Manual:** start/pause whenever you choose. This is the default.
- **Game session:** count only a real `running`, non-minimized SDK game session.
  Selection/preparation is not gameplay. A new session resets the counter;
  minimizing pauses it and returning resumes it unless you paused manually.
- **Break reminder:** Off / 15 / 30 / 45 / 60 minutes. Visual notice in the app
  and Start widget; no sound, forced pause, global notification or play restriction.
- D-pad/arrows navigate, Confirm/Enter activates, Back/Escape minimizes. All actions
  also work by touch/mouse. Controller input is handled only while this window is active.
- Profile-specific progress/settings are written atomically every five counted seconds
  and on actions/normal shutdown. An abrupt crash can lose up to that checkpoint interval.
- Restart restores a **paused** timer. Time while the process is closed/disconnected
  is never invented; a stalled/suspended clock pauses until deliberate continuation.

## TrainerOS integration

Requires Platform SDK v1 `context`, `lifecycle`, `ui.start.widget` from
[TrainerOS SDK](https://github.com/EriArk/TrainerOS/blob/codex/platform-sdk-foundation/sdk/README.md).
The app ID is `art.abysstail.session-timer`, widget ID `timer`. JSON-lines over
local TCP keeps the app independent from the shell process. No shell QML is loaded
from the package. No online account or network helper is needed.

Choose a local Trainer before connecting. Profile changes/host loss pause the timer
and require explicit **Connect** for the next context. Data is separated by a hash of
the profile ID; invalid existing state is preserved and reported, never overwritten.
The app never accesses game saves. App data comes from `TRAINEROS_PACKAGE_DATA`,
or the user data directory for a direct development launch.

Current Crates packaging uses the existing `app` type because external extension
autostart/module installation is not implemented. Launch the app explicitly;
closing Start alone does not stop it. The managed launcher must preserve host SDK
discovery before replacing XDG paths (integration change in TrainerOS).

## Build, test and package

Dependencies: C++20, CMake 3.24+, Qt 6.4+ Core/Gui/Qml/Quick/Network, SDL2.
Qt Test is needed with `BUILD_TESTING=ON`; Linux needs QtQuick/Window/WorkerScript
QML runtime modules. Use a matching toolchain and Qt runtime.

```sh
cmake -S widgets/session-timer -B build/session-timer -DCMAKE_BUILD_TYPE=Release
cmake --build build/session-timer --parallel 3
ctest --test-dir build/session-timer --output-on-failure
./build/session-timer/session-timer --windowed
python3 widgets/session-timer/package.py build/session-timer/session-timer dist/session-timer
```

Windows development uses the same UCRT64 Qt/SDL toolchain as TrainerOS and `.exe`.
`--endpoint PATH` and `--data-dir PATH` isolate development. `--screenshot PATH`
saves the actual app window and exits; this is not handheld evidence.

Optional real-host acceptance: configure `TRAINEROS_SOURCE` to a matching TrainerOS
SDK checkout and `TRAINEROS_CORE` to its built `libtrainer_core.a`. This adds
`session_timer_host`, which runs the real app as a child through `PlatformHost`
and `ControlsDashboard`: activation, elapsed time, restart, profile revocation,
profile isolation and crash cleanup. It writes `host-results.txt` and an app screenshot
in the build directory. This optional link configuration is verified on Windows UCRT64.

`package.py` accepts a native 64-bit Linux ELF for x86_64 or aarch64 and produces
an archive, source archive, installer record and SHA256SUMS. It does not cross-compile
or claim that an unbuilt architecture works. Release records target the approved
`EriArk/crates` GitHub repository and remain `Experimental` / `untested` until device acceptance.
The package reuses host Qt/SDL instead of bundling another runtime.

For isolated Linux package checks:
```sh
python3 widgets/session-timer/tests/verify_package.py TRAINEROS_CHECKOUT RECORD_JSON PACKAGE_TAR_GZ
```

The published 0.1.0 packages are in the signed Crates catalogue; handheld delivery
of the required TrainerOS SDK remains separate from these build instructions.
Original code/art: GPL-3.0-or-later; see [LICENSE](LICENSE). Original concept: [idea notes](docs/idea.md).

## Verification — 21 October 2026

- Windows/UCRT64 Qt 6.11: model tests and the actual external app against the real
  TrainerOS SDK host; pause/restart, profile revocation/isolation and crash cleanup.
  The actual QML window also passed keyboard navigation and mouse activation;
  layouts were inspected at 960×540 and 640×400. Physical controllers remain untested.
- Linux x86_64 / Qt 6.4: Release build and model tests. The actual archive passed
  install, launch, live-package lock, removal and data-preserving reinstall in a
  disposable container. Eight existing installer regressions and two SDK-launch/
  release-source tests passed. No personal data or running desktop was used.
- ARM64 / Fedora 44 / Qt 6.11.2: built from the same published source archive,
  model tests and real package install/launch/remove/reinstall passed under QEMU.
  Public catalogue revision 6 selected the ARM build; the external process found
  the real SDK host and counted time through its widget. The same public cycle
  passed on x86_64. ARM assets have separate records and `SHA256SUMS-aarch64`.
- The app window was rendered and inspected on desktop. Physical buttons/touch,
  handheld graphics/performance and suspend remain untested. The current SDK itself
  still needs handheld delivery; existing installed TrainerOS builds must not be
  assumed to expose this API.
