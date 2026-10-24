# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
const DEADZONE := 0.18
const AIM_SPEED := 90.0 # degrees/second at full deflection
const POWER_SPEED := 40.0 # percentage points/second

static func response(axis: Vector2) -> Vector2:
	# Per-axis dead zones keep a horizontal aim gesture from changing power.
	var result := Vector2.ZERO
	for component in 2:
		var amount := clampf((absf(axis[component])-DEADZONE)/(1.0-DEADZONE),0.0,1.0)
		result[component]=signf(axis[component])*amount*amount
	return result
