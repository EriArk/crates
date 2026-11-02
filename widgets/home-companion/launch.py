#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Select the installed Home widget through the optional TrainerOS SDK."""
import shutil
import subprocess
import sys
from traineros import Client, HostError, HostUnavailable


def main():
    try:
        with Client("home-companion") as client:
            if not client.supports("ui.home.widget"):
                raise HostUnavailable("Update TrainerOS to a version with installed Home widgets, then open Companion again.")
            client.select_home_widget("pet")
        return 0
    except (HostUnavailable, HostError) as error:
        messages = {"session_busy": "Finish your current game or operation, then open Companion again.",
                    "no_profile": "Select a Trainer profile first.",
                    "stale_context": "Your profile changed. Open Companion again.",
                    "widget_unavailable": "Reinstall Companion in Crates, then open it again."}
        message = messages.get(str(error), str(error))
        print("Companion: " + message, file=sys.stderr)
        # Standalone app launch on an older shell must explain the missing host.
        if shutil.which("zenity"):
            subprocess.run(["zenity", "--error", "--title=Companion", "--text=" + message], check=False)
        elif shutil.which("kdialog"):
            subprocess.run(["kdialog", "--title", "Companion", "--error", message], check=False)
        elif shutil.which("notify-send"):
            subprocess.run(["notify-send", "Companion", message], check=False)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
