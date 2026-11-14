# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
const Square = preload("res://scripts/square.gd")
const Walker = preload("res://scripts/walker.gd")
const TouchPad = preload("res://scripts/touch_pad.gd")
var square = Square.new()
var visitor = Walker.new()
var touch_pad = TouchPad.new()
var population = preload("res://scripts/population.gd").new()
var identity := Label.new()
var district_label: Label
var prompt := Button.new()
var panel := PanelContainer.new()
var menu_title := Label.new()
var menu_body := Label.new()
var resume: Button
var fov_slider: HSlider
var fov_label: Label
var sound: CheckButton
var reconnect: Button
var quit_button: Button
var nearest: Dictionary = {}
var modal := false
var smoke_mode := false
var leaving := false

func label(text: String, size: int, color := Color("f6ead3")) -> Label:
	var node := Label.new();node.text=text;node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",color);node.add_theme_color_override("font_shadow_color",Color("193335"));node.add_theme_constant_override("shadow_offset_x",1);node.add_theme_constant_override("shadow_offset_y",2);return node

func backdrop() -> StyleBoxFlat:
	var style := StyleBoxFlat.new();style.bg_color=Color(0.06,0.15,0.16,0.86)
	style.set_corner_radius_all(9);style.content_margin_left=14;style.content_margin_right=14
	style.content_margin_top=8;style.content_margin_bottom=8
	return style

func dress_button(node: Button) -> void:
	for state in ["normal","hover","pressed","focus"]:
		var style := StyleBoxFlat.new();style.set_corner_radius_all(7);style.set_border_width_all(1)
		style.bg_color=Color("2b4e51") if state=="normal" else Color("3d6765")
		style.border_color=Color("c7b17d") if state=="focus" else Color("6c8b7d")
		if state=="focus":style.bg_color=Color.TRANSPARENT;style.set_border_width_all(2)
		node.add_theme_stylebox_override(state,style)

func button(text: String, action: Callable) -> Button:
	var node := Button.new();node.text=text;node.custom_minimum_size=Vector2(0,42)
	node.add_theme_font_size_override("font_size",17);dress_button(node);node.pressed.connect(action);return node

func _ready() -> void:
	smoke_mode="--smoke" in OS.get_cmdline_user_args()
	get_tree().auto_accept_quit=false
	get_tree().root.close_requested.connect(leave_bazaar)
	add_child(square)
	visitor.identity_changed.connect(func(text: String):identity.text=text)
	add_child(visitor);visitor.enter_space(Vector3(0,0.2,10),0)
	add_child(population);population.setup(square,visitor)
	var hud := CanvasLayer.new();add_child(hud)
	var root := Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.add_child(root)
	root.add_child(touch_pad);touch_pad.move_changed.connect(func(value: Vector2):visitor.touch_move=value)
	touch_pad.look_changed.connect(visitor.look)
	var heading_frame := PanelContainer.new();root.add_child(heading_frame);heading_frame.position=Vector2(14,14);heading_frame.add_theme_stylebox_override("panel",backdrop());heading_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var heading := VBoxContainer.new();heading_frame.add_child(heading);heading.mouse_filter=Control.MOUSE_FILTER_IGNORE
	heading.add_child(label("OFFICIAL BAZAAR",12,Color("f4cf8b")))
	district_label=label("Festival Park",24);heading.add_child(district_label)
	identity.add_theme_font_size_override("font_size",12);identity.add_theme_color_override("font_color",Color("e6eadb"));heading.add_child(identity)
	if identity.text.is_empty():identity.text="Guest appearance · TrainerOS is not connected"
	var badge := label("EARLY BUILD · LOCAL WALKTHROUGH",12,Color("f7d494"))
	root.add_child(badge);badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);badge.offset_left=-330;badge.offset_right=-24;badge.offset_top=23;badge.offset_bottom=42
	var pause_button := button("Menu  ☰",func():show_menu());root.add_child(pause_button)
	pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);pause_button.offset_left=-150;pause_button.offset_right=-24;pause_button.offset_top=48;pause_button.offset_bottom=90
	var footer := PanelContainer.new();root.add_child(footer);footer.add_theme_stylebox_override("panel",backdrop())
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);footer.offset_left=14;footer.offset_right=-14;footer.offset_top=-43;footer.offset_bottom=-10;footer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var controls := label("WASD / LS Move · Shift / LB Run · RMB / RS Look · E / A Inspect · Esc / B Menu",13)
	footer.add_child(controls);controls.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;controls.mouse_filter=Control.MOUSE_FILTER_IGNORE
	dress_button(prompt);prompt.add_theme_font_size_override("font_size",17);prompt.text="Inspect";prompt.custom_minimum_size=Vector2(230,44);root.add_child(prompt)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM);prompt.offset_left=-150;prompt.offset_right=150;prompt.offset_top=-94;prompt.offset_bottom=-50
	prompt.pressed.connect(inspect_spot)
	root.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER);panel.offset_left=-215;panel.offset_right=215;panel.offset_top=-202;panel.offset_bottom=202
	var style := StyleBoxFlat.new();style.bg_color=Color("183e42");style.border_color=Color("bba374");style.set_border_width_all(2);style.set_corner_radius_all(14)
	style.content_margin_left=24;style.content_margin_right=24;style.content_margin_top=20;style.content_margin_bottom=20;panel.add_theme_stylebox_override("panel",style)
	var menu := VBoxContainer.new();menu.add_theme_constant_override("separation",8);panel.add_child(menu)
	menu_title.add_theme_font_size_override("font_size",25);menu.add_child(menu_title)
	menu_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;menu_body.custom_minimum_size=Vector2(382,58);menu.add_child(menu_body)
	var camera_row := HBoxContainer.new();camera_row.add_theme_constant_override("separation",12);menu.add_child(camera_row)
	fov_label=label("Field of view · 90°",14);fov_label.custom_minimum_size.x=146;camera_row.add_child(fov_label)
	fov_slider=HSlider.new();fov_slider.min_value=75;fov_slider.max_value=105;fov_slider.step=1;fov_slider.value=90
	fov_slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL;fov_slider.custom_minimum_size.y=30
	fov_slider.tooltip_text="Horizontal field of view at 16:9. Wider screens show more at the sides."
	fov_slider.value_changed.connect(func(value: float):visitor.set_field_of_view(value);fov_label.text="Field of view · %d°"%value)
	camera_row.add_child(fov_slider)
	sound=CheckButton.new();sound.text="Fountain sound";sound.button_pressed=true;sound.custom_minimum_size.y=32
	sound.toggled.connect(func(enabled: bool):square.life.set_sound(enabled,modal));menu.add_child(sound)
	resume=button("Continue exploring",hide_menu);menu.add_child(resume)
	reconnect=button("Use my TrainerOS character",func():visitor.reconnect();hide_menu());menu.add_child(reconnect)
	quit_button=button("Leave Bazaar",leave_bazaar);menu.add_child(quit_button)
	if not smoke_mode:
		var saved := ConfigFile.new()
		if saved.load("user://bazaar-preferences.cfg")==OK:
			fov_slider.value=clampf(float(saved.get_value("camera","fov",90.0)),75,105)
			sound.button_pressed=bool(saved.get_value("audio","fountain",true))
	panel.hide()
	if smoke_mode:call_deferred("run_smoke")

func show_menu(title := "Bazaar Island", detail := "Explore the park market, town shops, gardens and harbor. Multiplayer and trading are still in development.") -> void:
	modal=true;population.set_paused(true);square.life.set_sound(sound.button_pressed,true);visitor.set_controls(false);touch_pad.enabled=false;touch_pad.reset();prompt.hide()
	menu_title.text=title;menu_body.text=detail;panel.show();resume.grab_focus()

func hide_menu() -> void:
	modal=false;population.set_paused(false);square.life.set_sound(sound.button_pressed);panel.hide();visitor.set_controls(true);touch_pad.enabled=true;resume.release_focus()

func inspect_spot() -> void:
	if nearest.is_empty():return
	if nearest.has("arrival"):
		visitor.enter_space(nearest.arrival,nearest.yaw)
		visitor.touch_move=Vector2.ZERO;touch_pad.reset();nearest={};prompt.hide()
	else:show_menu(nearest.title,nearest.detail)

func _process(_delta: float) -> void:
	district_label.text=square.district(visitor.position)
	if modal:return
	nearest={};var distance := 2.1
	for spot in square.destinations:
		var candidate: float=visitor.global_position.distance_to(spot.position)
		if candidate<distance:distance=candidate;nearest=spot
	prompt.visible=not nearest.is_empty()
	if prompt.visible:prompt.text="E / A  ·  "+str(nearest.title)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE:
			if modal:hide_menu()
			else:show_menu()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_E and not modal:inspect_spot()
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index in [JOY_BUTTON_B,JOY_BUTTON_START]:
			if modal:hide_menu()
			else:show_menu()
			get_viewport().set_input_as_handled()
		elif event.button_index==JOY_BUTTON_A and not modal:inspect_spot()

func leave_bazaar(code := 0) -> void:
	if leaving:return
	leaving=true;visitor.set_controls(false);square.life.stop_sound()
	# Let the audio mixer retire playback before engine shutdown.
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(code)

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():leave_bazaar()
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and not smoke_mode:show_menu()

func run_smoke() -> void:
	var suite = load("res://tests/walkthrough.gd").new()
	add_child(suite);await suite.run(self)

func _exit_tree() -> void:
	if smoke_mode or sound==null or fov_slider==null:return
	var saved := ConfigFile.new();saved.set_value("camera","fov",fov_slider.value)
	saved.set_value("audio","fountain",sound.button_pressed);saved.save("user://bazaar-preferences.cfg")
