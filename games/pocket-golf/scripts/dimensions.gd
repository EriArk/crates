# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## Shared physical sizes: rules use millimetres, rendering uses metres.
## Slightly enlarged miniature-golf ball/cup stay readable beside the 1 m avatar.
const BALL_MM := 35
const CUP_MM := 75
const BALL := BALL_MM/1000.0
const CUP := CUP_MM/1000.0
const STANCE := 0.32
