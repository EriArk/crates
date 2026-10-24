#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Flip2 / Turnip Adreno 650 loses the Vulkan device in Godot 4.7.2,
# including in the menu. Keep the workaround local to this game/device.
renderer=${POCKET_GOLF_RENDERER:-auto}
if [ "$renderer" = auto ] && [ -r /proc/device-tree/model ]; then
    model=$(tr -d '\000' </proc/device-tree/model)
    if [ "$model" = 'Retroid Pocket Flip2' ]; then
        renderer=gl_compatibility
    fi
fi
case "$renderer" in
    mobile|gl_compatibility) set -- --rendering-method "$renderer" "$@" ;;
esac
exec "$(dirname "$0")/../libexec/pocket-golf" "$@"
