#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Same Godot/Turnip fallback already used by Pocket Golf on Flip2.
renderer=${MICRO_RALLY_RENDERER:-auto}
if [ -r /proc/device-tree/model ]; then
    model=$(tr -d '\000' </proc/device-tree/model)
    if [ "$model" = 'Retroid Pocket Flip2' ] && [ "$renderer" = auto ]; then
        renderer=gl_compatibility
    fi
fi
case "$renderer" in
    mobile|gl_compatibility) set -- --rendering-method "$renderer" "$@" ;;
esac
exec "$(dirname "$0")/../libexec/micro-rally" --fullscreen "$@"
