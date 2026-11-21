# SPDX-License-Identifier: GPL-3.0-or-later
extends Control
signal move_changed(value: Vector2)
signal look_changed(value: Vector2)
var move_id := -1
var look_id := -1
var origin := Vector2.ZERO
var finger := Vector2.ZERO
var enabled := true

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func reset() -> void:
	move_id=-1;look_id=-1;move_changed.emit(Vector2.ZERO);queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:return
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x<size.x*0.45 and event.position.y>size.y*0.45 and move_id<0:
				move_id=event.index;origin=event.position;finger=origin
			elif event.position.x>size.x*0.5 and look_id<0:look_id=event.index
		else:
			if event.index==move_id:move_id=-1;move_changed.emit(Vector2.ZERO)
			if event.index==look_id:look_id=-1
		queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index==move_id:
			finger=event.position;move_changed.emit(((finger-origin)/58).limit_length());queue_redraw()
		elif event.index==look_id:look_changed.emit(event.relative*0.004)

func _draw() -> void:
	if move_id>=0:
		draw_circle(origin,58,Color(0.13,0.24,0.25,0.35))
		draw_arc(origin,58,0,TAU,40,Color(1,0.9,0.7,0.75),2)
		draw_circle(origin+(finger-origin).limit_length(58),23,Color(1,0.9,0.7,0.6))
