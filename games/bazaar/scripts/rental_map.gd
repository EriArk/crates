# SPDX-License-Identifier: GPL-3.0-or-later
extends Control
## Project the actual counter positions onto the orthographic park capture.
const PLAN = preload("res://assets/market/park.png")
const MAP_HEIGHT := 43.0
var square
var markers: Dictionary = {}
var labels: Array[Label] = []

func configure(world, buttons: Dictionary) -> void:
	square = world
	markers = buttons
	custom_minimum_size = Vector2(290, 216)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	for caption in ["N  ↑", "GARDENS", "TOWN", "FOUNTAIN", "HARBOR  ↓"]:
		var tag := Label.new()
		tag.text = caption
		tag.add_theme_font_size_override("font_size", 12)
		tag.add_theme_constant_override("outline_size", 5)
		tag.add_theme_color_override("font_outline_color", Color("213c37"))
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tag)
		labels.append(tag)
	resized.connect(arrange)
	arrange()

func arrange() -> void:
	if labels.is_empty() or size.y == 0: return
	var scale_px := size.y / MAP_HEIGHT
	for slot in markers:
		var at: Vector3 = square.stall_layout(slot).position
		var b: Button = markers[slot]
		var center := size * 0.5 + Vector2(at.x, at.z) * scale_px
		b.custom_minimum_size.y = 0
		b.size = Vector2(48, clampf(scale_px*3.05-1,18,26))
		b.position = center + Vector2(-52 if at.x < 0 else 4, -b.size.y/2)
	var positions := [Vector2(.5,.035),Vector2(.13,.5),Vector2(.88,.5),Vector2(.5,.61),Vector2(.5,.96)]
	for i in labels.size():
		labels[i].position = size * positions[i] - labels[i].size * .5
	queue_redraw()

func _draw() -> void:
	var extent := Vector2(size.y * PLAN.get_width() / PLAN.get_height(), size.y)
	draw_texture_rect(PLAN, Rect2((size-extent)*.5,extent), false,Color(.77,.82,.76))
