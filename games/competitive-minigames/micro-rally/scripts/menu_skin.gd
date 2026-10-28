# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
const PAPER = Color("fff5df")
const GOLD = Color("ffc244")
const DARK = Color("202728")
static var heading: FontVariation

static func title_font() -> Font:
	if heading==null:
		heading=FontVariation.new(); heading.base_font=preload("res://assets/fonts/RobotoCondensed-Italic.ttf")
		heading.variation_opentype={0x77676874:800.0} # OpenType 'wght' tag.
	return heading

static func plate(color: Color, margin: float = 18, accent: bool = false) -> StyleBoxFlat:
	var box=StyleBoxFlat.new(); box.bg_color=color
	box.content_margin_left=margin; box.content_margin_right=margin
	box.content_margin_top=10; box.content_margin_bottom=10
	box.skew=Vector2(-0.07,0)
	if accent: box.border_width_left=5; box.border_color=GOLD
	return box

static func style_button(button: Button) -> void:
	button.alignment=HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font",title_font())
	button.add_theme_stylebox_override("normal",plate(Color(0.08,0.11,0.12,0.88)))
	button.add_theme_stylebox_override("hover",plate(Color("3b4443"),18,true))
	button.add_theme_stylebox_override("focus",plate(GOLD))
	button.add_theme_stylebox_override("pressed",plate(Color("ed9b27")))
	button.add_theme_stylebox_override("disabled",plate(Color(0.1,0.12,0.13,0.65)))
	button.add_theme_color_override("font_color",PAPER)
	button.add_theme_color_override("font_hover_color",PAPER)
	button.add_theme_color_override("font_focus_color",Color("1a2021"))
	button.add_theme_color_override("font_pressed_color",Color("1a2021"))
	button.add_theme_color_override("font_disabled_color",Color("b1b7b2"))
	button.add_theme_constant_override("outline_size",0)

static func style_slider(slider: HSlider) -> void:
	var track=plate(Color("54605b"),0); track.content_margin_top=4; track.content_margin_bottom=4
	var fill=track.duplicate(); fill.bg_color=GOLD
	slider.add_theme_stylebox_override("slider",track)
	slider.add_theme_stylebox_override("grabber_area",fill)
	slider.add_theme_stylebox_override("grabber_area_highlight",fill)
	var image=Image.create(18,30,false,Image.FORMAT_RGBA8); image.fill(PAPER)
	var texture=ImageTexture.create_from_image(image)
	slider.add_theme_icon_override("grabber",texture); slider.add_theme_icon_override("grabber_highlight",texture)
	var focus=StyleBoxFlat.new(); focus.bg_color=Color.TRANSPARENT
	focus.set_border_width_all(2); focus.border_color=GOLD; focus.set_expand_margin_all(6)
	slider.add_theme_stylebox_override("focus",focus)
