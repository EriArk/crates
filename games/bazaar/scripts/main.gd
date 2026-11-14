# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
const Square = preload("res://scripts/square.gd")
const Walker = preload("res://scripts/walker.gd")
const TouchPad = preload("res://scripts/touch_pad.gd")
var square = Square.new()
var visitor = Walker.new()
var touch_pad = TouchPad.new()
var identity := Label.new()
var prompt := Button.new()
var panel := PanelContainer.new()
var menu_title := Label.new()
var menu_body := Label.new()
var resume: Button
var reconnect: Button
var quit_button: Button
var nearest: Dictionary = {}
var modal := false
var smoke_mode := false

func label(text: String, size: int, color := Color("f6ead3")) -> Label:
	var node := Label.new();node.text=text;node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",color);node.add_theme_color_override("font_shadow_color",Color("193335"));node.add_theme_constant_override("shadow_offset_x",1);node.add_theme_constant_override("shadow_offset_y",2);return node

func button(text: String, action: Callable) -> Button:
	var node := Button.new();node.text=text;node.custom_minimum_size=Vector2(0,42)
	node.add_theme_font_size_override("font_size",17);node.pressed.connect(action);return node

func _ready() -> void:
	smoke_mode="--smoke" in OS.get_cmdline_user_args()
	add_child(square)
	visitor.identity_changed.connect(func(text: String):identity.text=text)
	add_child(visitor);visitor.position=Vector3(0,0.2,10)
	var hud := CanvasLayer.new();add_child(hud)
	var root := Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.add_child(root)
	root.add_child(touch_pad);touch_pad.move_changed.connect(func(value: Vector2):visitor.touch_move=value)
	touch_pad.look_changed.connect(visitor.look)
	var heading := VBoxContainer.new();root.add_child(heading);heading.position=Vector2(24,18);heading.mouse_filter=Control.MOUSE_FILTER_IGNORE
	heading.add_child(label("OFFICIAL BAZAAR",12,Color("f4cf8b")))
	heading.add_child(label("Fountain Square",28))
	identity.add_theme_font_size_override("font_size",12);identity.add_theme_color_override("font_color",Color("e6eadb"));heading.add_child(identity)
	if identity.text.is_empty():identity.text="Guest appearance · TrainerOS is not connected"
	var badge := label("EARLY BUILD · LOCAL WALKTHROUGH",12,Color("f7d494"))
	root.add_child(badge);badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);badge.offset_left=-330;badge.offset_right=-24;badge.offset_top=23;badge.offset_bottom=42
	var pause_button := button("Menu  ☰",func():show_menu());root.add_child(pause_button)
	pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);pause_button.offset_left=-150;pause_button.offset_right=-24;pause_button.offset_top=48;pause_button.offset_bottom=90
	var controls := label("WASD / LS Move · Shift / LB Run · RMB / RS Look · E / A Inspect · Esc / B Menu",12)
	root.add_child(controls);controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);controls.offset_left=24;controls.offset_top=-30;controls.offset_bottom=-10
	prompt.text="Inspect";prompt.custom_minimum_size=Vector2(230,44);root.add_child(prompt)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM);prompt.offset_left=-150;prompt.offset_right=150;prompt.offset_top=-94;prompt.offset_bottom=-50
	prompt.pressed.connect(inspect_spot)
	root.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER);panel.offset_left=-215;panel.offset_right=215;panel.offset_top=-170;panel.offset_bottom=170
	var style := StyleBoxFlat.new();style.bg_color=Color("183e42");style.border_color=Color("bba374");style.set_border_width_all(2);style.set_corner_radius_all(14)
	style.content_margin_left=24;style.content_margin_right=24;style.content_margin_top=20;style.content_margin_bottom=20;panel.add_theme_stylebox_override("panel",style)
	var menu := VBoxContainer.new();menu.add_theme_constant_override("separation",12);panel.add_child(menu)
	menu_title.add_theme_font_size_override("font_size",25);menu.add_child(menu_title)
	menu_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;menu_body.custom_minimum_size=Vector2(382,82);menu.add_child(menu_body)
	resume=button("Continue exploring",hide_menu);menu.add_child(resume)
	reconnect=button("Use my TrainerOS character",func():visitor.reconnect();hide_menu());menu.add_child(reconnect)
	quit_button=button("Leave Bazaar",func():get_tree().quit());menu.add_child(quit_button)
	panel.hide()
	if smoke_mode:call_deferred("run_smoke")

func show_menu(title := "Fountain Square", detail := "The first walkable area of the official Bazaar. Multiplayer, other squares and trading are still in development.") -> void:
	modal=true;visitor.set_controls(false);touch_pad.enabled=false;touch_pad.reset();prompt.hide()
	menu_title.text=title;menu_body.text=detail;panel.show();resume.grab_focus()

func hide_menu() -> void:
	modal=false;panel.hide();visitor.set_controls(true);touch_pad.enabled=true;resume.release_focus()

func inspect_spot() -> void:
	if not nearest.is_empty():show_menu(nearest.title,nearest.detail)

func _process(_delta: float) -> void:
	if modal:return
	nearest={};var distance := 1.7
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

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and not smoke_mode:show_menu()

func run_smoke() -> void:
	var suite = load("res://tests/walkthrough.gd").new()
	add_child(suite);await suite.run(self)
