# SPDX-License-Identifier: GPL-3.0-or-later
extends Camera3D
# Local presentation only: never writes aim, shot power, or network state.
enum View { OVERVIEW, SHOULDER, EYES }
const TITLES := ["Overview", "Shoulder", "Eyes"]
var view := View.OVERVIEW
var yaw := [0.61, 0.0, 0.0]
var pitch := [0.77, 0.48, 0.85]
var zoom := [1.0, 1.0, 1.0]
var look_point := Vector3.ZERO
var initialized := false
var following := false

func cycle() -> void:
	view = (view + 1) % 3

func reset_view() -> void:
	yaw[view] = 0.61 if view == View.OVERVIEW else 0.0
	pitch[view] = [0.77, 0.48, 0.85][view]
	zoom[view] = 1.0

func rotate_view(motion: Vector2) -> void:
	yaw[view] = wrapf(yaw[view] + motion.x, -PI, PI)
	pitch[view] = clampf(pitch[view] + motion.y,
		-0.35 if view == View.EYES else 0.30,
		1.15 if view == View.EYES else 1.30)

func magnify(amount: float) -> void:
	zoom[view] = clampf(zoom[view] * exp(-amount), 0.55, 1.55)

func frame(delta: float, ball: Vector3, golfer: Vector3, aim: float, rolling: bool, playing: bool) -> void:
	following = rolling and playing
	var active: int = view if playing else View.OVERVIEW
	var heading: float = yaw[active] - (aim if active != View.OVERVIEW else 0.0)
	var elevation: float = pitch[active]
	var focus := Vector3.ZERO
	var desired := Vector3.ZERO
	var lens := 45.0
	if following:
		# Observe the ball from above; never drag the player's eyes along the turf.
		elevation = maxf(elevation, 0.60)
		focus = ball + Vector3(0, 0.2, 0)
		var distance := clampf(7.5 * zoom[active], 5.0, 12.0)
		desired = focus + _offset(heading, elevation) * distance
	elif active == View.OVERVIEW:
		var toward_ball := clampf((1.0 - zoom[active]) * 2.2, 0, 1) if playing else 0.0
		focus = Vector3(0,0,0.6).lerp(ball, toward_ball)
		desired = focus + _offset(heading, elevation) * 60.0 * zoom[active]
		lens = 28.0
	elif active == View.SHOULDER:
		focus = ball + Vector3(0, 0.35, 0)
		desired = focus + _offset(heading, elevation) * 4.8 * zoom[active]
		# Keep the camera above the 0.6 m obstacles, including at minimum distance.
		desired.y = maxf(desired.y, 1.15)
		lens = 60.0
	else:
		# Temporary eye height of the placeholder. SDK socket integration comes later.
		desired = golfer + Vector3(0, 1.05, 0)
		# The golfer stands beside the ball: look diagonally down to the putting line.
		heading -= atan2(0.85,0.75)
		focus = desired - _offset(heading, elevation) * 5.0
		lens = clampf(65.0 * zoom[active], 38.0, 85.0)
	var blend := 1.0 if not initialized else 1.0 - exp(-delta * 6.0)
	position = position.lerp(desired, blend)
	look_point = look_point.lerp(focus, blend)
	fov = lerpf(fov, lens, blend)
	if position.distance_squared_to(look_point) > 0.001: look_at(look_point)
	initialized = true

func _offset(heading: float, elevation: float) -> Vector3:
	return Vector3(sin(heading) * cos(elevation), sin(elevation), cos(heading) * cos(elevation))
