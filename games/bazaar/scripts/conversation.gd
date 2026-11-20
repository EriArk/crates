# SPDX-License-Identifier: GPL-3.0-or-later
extends Control
signal finished
signal syllable(character: int, ordinal: int, pitch: float)

var page_text := Label.new()
var tag := Label.new()
var next := Button.new()
var pages: Array = []
var page := 0
var cursor := 0
var delay := 0.0
var voice_delay := 0.0
var pitch := 1.0

func paper(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var card := Panel.new()
	add_child(card)
	card.anchor_left = .115
	card.anchor_right = .885
	card.anchor_top = 1
	card.anchor_bottom = 1
	card.offset_top = -164
	card.offset_bottom = -17
	var style := paper(Color("fff1d4"), 27)
	style.shadow_color = Color("24241b70")
	style.shadow_size = 5
	style.shadow_offset = Vector2(0,3)
	card.add_theme_stylebox_override("panel", style)
	card.add_child(tag)
	tag.position = Vector2(28,-15)
	tag.add_theme_font_size_override("font_size",19)
	tag.add_theme_color_override("font_color",Color("fff8e5"))
	var badge := paper(Color("385e52"),13)
	badge.content_margin_left = 16
	badge.content_margin_right = 16
	badge.content_margin_top = 3
	badge.content_margin_bottom = 4
	tag.add_theme_stylebox_override("normal",badge)
	card.add_child(page_text)
	page_text.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	page_text.offset_left = 32
	page_text.offset_right = -32
	page_text.offset_top = 20
	page_text.offset_bottom = -38
	page_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	page_text.add_theme_font_size_override("font_size",22)
	page_text.add_theme_color_override("font_color",Color("392e29"))
	var actions := HBoxContainer.new()
	card.add_child(actions)
	actions.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT)
	actions.offset_left = -244
	actions.offset_right = -18
	actions.offset_top = -39
	actions.offset_bottom = -3
	actions.alignment = BoxContainer.ALIGNMENT_END
	var back := Button.new()
	back.text = "B  ·  Back"
	back.pressed.connect(close)
	next.pressed.connect(advance)
	for button in [back,next]:
		actions.add_child(button)
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		for state in ["font_color","font_hover_color","font_pressed_color"]:
			button.add_theme_color_override(state,Color("365c51"))
		button.add_theme_font_size_override("font_size",15)
	hide()

func begin(speaker: String, text: Array, tone: float) -> void:
	tag.text = speaker
	pages = text
	pitch = tone
	page = 0
	show()
	start_page()

func start_page() -> void:
	page_text.text = pages[page]
	page_text.visible_characters = 0
	cursor = 0
	delay = 0
	voice_delay = 0
	next.text = "A  ·  Reveal"

func complete_page() -> void:
	cursor = page_text.text.length()
	page_text.visible_characters = -1
	next.text = "A  ·  Next  ▾" if page+1 < pages.size() else "A  ·  Done"

func _process(delta: float) -> void:
	if not visible or cursor >= page_text.text.length():return
	delay -= delta
	voice_delay -= delta
	while delay <= 0 and cursor < page_text.text.length():
		var letter := page_text.text[cursor]
		cursor += 1
		page_text.visible_characters = cursor
		if letter.to_lower() >= "a" and letter.to_lower() <= "z" and voice_delay <= 0:
			syllable.emit(letter.unicode_at(0), cursor, pitch)
			voice_delay = .095
		delay += .17 if letter in [".","?","!"] else .09 if letter == "," else .029
	if cursor >= page_text.text.length():complete_page()

func advance() -> void:
	if cursor < page_text.text.length():complete_page()
	elif page+1 < pages.size():
		page += 1
		start_page()
	else:close()

func close() -> void:
	if not visible:return
	hide()
	finished.emit()

func _input(event: InputEvent) -> void:
	if not visible:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_E,KEY_SPACE,KEY_ENTER]:advance()
		elif event.physical_keycode == KEY_ESCAPE:close()
		else:return
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_A:advance()
		elif event.button_index in [JOY_BUTTON_B,JOY_BUTTON_START]:close()
		else:return
	else:return
	get_viewport().set_input_as_handled()
