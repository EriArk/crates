# SPDX-License-Identifier: GPL-3.0-or-later
extends Button
## One focus stop per offer. The whole row is also a touch target.
const INK := Color("192e32")
const GOLD := Color("f2c87b")
var face: Texture2D
var item_title := ""
var game := ""
var price := ""
var inspected := false:
	set(value):
		inspected=value
		queue_redraw()

func _ready() -> void:
	flat=true
	custom_minimum_size=Vector2(0,64)
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)

func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO,size)
	var active := has_focus() or inspected
	draw_rect(bounds,Color("385453") if active else INK)
	draw_rect(Rect2(0,0,4,size.y),GOLD if active else Color("537170"))
	if has_focus():draw_rect(bounds.grow(-1),GOLD,false,2)
	var well := Rect2(12,10,44,44)
	draw_rect(well,Color("15272c"))
	if face:draw_texture_rect(face,well.grow(-7),false)
	var font := get_theme_default_font()
	var price_width := font.get_string_size(price,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+12
	var available := maxf(8,size.x-68-price_width-10)
	draw_string(font,Vector2(66,28),item_title,HORIZONTAL_ALIGNMENT_LEFT,available,18,Color("fff2dc"))
	draw_string(font,Vector2(66,49),game,HORIZONTAL_ALIGNMENT_LEFT,maxf(8,size.x-80),13,Color("c2d1cb"))
	draw_string(font,Vector2(size.x-price_width-6,29),price,HORIZONTAL_ALIGNMENT_RIGHT,price_width,16,GOLD)
