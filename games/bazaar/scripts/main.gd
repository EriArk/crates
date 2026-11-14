# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
const Square = preload("res://scripts/square.gd")
const Walker = preload("res://scripts/walker.gd")
const TouchPad = preload("res://scripts/touch_pad.gd")
var square: Node3D
var world_kind := "official"
var personal := false
var visitor = Walker.new()
var touch_pad = TouchPad.new()
var services: Control
var population: Node3D
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
var compass: Label
var touch_actions: HBoxContainer
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
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--world="):world_kind=arg.trim_prefix("--world=")
	if world_kind not in ["official","island","station"]:
		push_error("Unknown Bazaar world");get_tree().quit(2);set_process(false);return
	personal=world_kind!="official"
	if personal:
		square=load("res://scripts/personal_world.gd").new();square.kind=world_kind
	else:square=Square.new()
	get_tree().auto_accept_quit=false
	get_tree().root.close_requested.connect(leave_bazaar)
	add_child(square)
	visitor.identity_changed.connect(func(text: String):identity.text=text)
	add_child(visitor)
	if personal:visitor.camera.far=1000;visitor.spawn_point=square.spawn;visitor.fall_height=-2.3;visitor.world_radius=54.0 if world_kind=="island" else 36.0
	visitor.enter_space(visitor.spawn_point,0)
	if not personal:
		population=load("res://scripts/population.gd").new();add_child(population);population.setup(square,visitor)
	var hud := CanvasLayer.new();add_child(hud)
	var root := Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.add_child(root)
	root.add_child(touch_pad);touch_pad.move_changed.connect(func(value: Vector2):visitor.touch_move=value)
	touch_pad.look_changed.connect(visitor.look)
	# Small map/location corner; the view and contextual interaction stay central.
	var location := VBoxContainer.new();root.add_child(location);location.position=Vector2(22,18)
	location.mouse_filter=Control.MOUSE_FILTER_IGNORE
	district_label=label("Festival Park",20);location.add_child(district_label)
	location.add_child(label("EMPTY STARTING SQUARE  /  LOCAL ALPHA" if personal else "BAZAAR ISLAND  /  ALPHA",10,Color("dfcfab")))
	compass=label("N",13);root.add_child(compass)
	compass.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP);compass.position.y=18
	compass.name="Compass";compass.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var pause_button := button("☰",func():show_menu());root.add_child(pause_button)
	pause_button.tooltip_text="Menu · Esc / B"
	pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);pause_button.offset_left=-62;pause_button.offset_right=-18;pause_button.offset_top=18;pause_button.offset_bottom=58
	var hint := label("Shift / LB  Sprint     C / R3  Crouch     Space / X  Jump",11,Color("eee4ce"))
	root.add_child(hint);hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);hint.offset_left=22;hint.offset_top=-30;hint.offset_bottom=-12
	hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	# Touch actions share the same motor flags as physical input. Show on touch,
	# hide on pad/keyboard; no permanent wall of desktop controls over the world.
	touch_actions=HBoxContainer.new();touch_actions.name="TouchActions";root.add_child(touch_actions)
	touch_actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT);touch_actions.offset_left=-270;touch_actions.offset_right=-22;touch_actions.offset_top=-72;touch_actions.offset_bottom=-26
	var sprint := button("Run",func():visitor.touch_sprint=not visitor.touch_sprint)
	touch_actions.add_child(sprint)
	touch_actions.add_child(button("Crouch",func():visitor.crouch_toggle=not visitor.crouch_toggle))
	touch_actions.add_child(button("Jump",func():visitor.jump_requested=true))
	touch_actions.hide()
	var hint_timer := get_tree().create_timer(12.0)
	hint_timer.timeout.connect(func():if is_instance_valid(hint):hint.hide())
	dress_button(prompt);prompt.add_theme_font_size_override("font_size",17);prompt.text="Inspect";prompt.custom_minimum_size=Vector2(230,44);root.add_child(prompt)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM);prompt.offset_left=-150;prompt.offset_right=150;prompt.offset_top=-76;prompt.offset_bottom=-32
	prompt.pressed.connect(inspect_spot)
	root.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER);panel.offset_left=-215;panel.offset_right=215;panel.offset_top=-202;panel.offset_bottom=202
	var style := StyleBoxFlat.new();style.bg_color=Color("183e42");style.border_color=Color("bba374");style.set_border_width_all(2);style.set_corner_radius_all(14)
	style.content_margin_left=24;style.content_margin_right=24;style.content_margin_top=20;style.content_margin_bottom=20;panel.add_theme_stylebox_override("panel",style)
	var menu := VBoxContainer.new();menu.add_theme_constant_override("separation",8);panel.add_child(menu)
	menu_title.add_theme_font_size_override("font_size",25);menu.add_child(menu_title)
	identity.add_theme_font_size_override("font_size",12);menu.add_child(identity)
	menu_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;menu_body.custom_minimum_size=Vector2(382,58);menu.add_child(menu_body)
	var camera_row := HBoxContainer.new();camera_row.add_theme_constant_override("separation",12);menu.add_child(camera_row)
	fov_label=label("Field of view · 90°",14);fov_label.custom_minimum_size.x=146;camera_row.add_child(fov_label)
	fov_slider=HSlider.new();fov_slider.min_value=75;fov_slider.max_value=105;fov_slider.step=1;fov_slider.value=90
	fov_slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL;fov_slider.custom_minimum_size.y=30
	fov_slider.tooltip_text="Horizontal field of view at 16:9. Wider screens show more at the sides."
	fov_slider.value_changed.connect(func(value: float):visitor.set_field_of_view(value);fov_label.text="Field of view · %d°"%value)
	camera_row.add_child(fov_slider)
	sound=CheckButton.new();sound.text="Fountain sound";sound.button_pressed=true;sound.custom_minimum_size.y=32
	sound.toggled.connect(func(enabled: bool):if not personal:square.life.set_sound(enabled,modal));menu.add_child(sound);sound.visible=not personal
	resume=button("Continue exploring",hide_menu);menu.add_child(resume)
	reconnect=button("Use my TrainerOS character",func():visitor.reconnect();hide_menu());menu.add_child(reconnect)
	quit_button=button("Leave Bazaar",leave_bazaar);menu.add_child(quit_button)
	if not smoke_mode:
		var saved := ConfigFile.new()
		if saved.load("user://bazaar-preferences.cfg")==OK:
			fov_slider.value=clampf(float(saved.get_value("camera","fov",90.0)),75,105)
			sound.button_pressed=bool(saved.get_value("audio","fountain",true))
	panel.hide()
	if not personal:
		services=load("res://scripts/service_menu.gd").new()
		root.add_child(services);services.closed.connect(hide_menu)
		services.client.snapshot.connect(func(method: String, value: Dictionary):
			if method=="bazaar.world":population.apply_stall_sellers(value.get("places",[])))
		services.client.unavailable.connect(func(_reason: String):population.apply_stall_sellers([]))
		services.client.read_failed.connect(func(method: String, _reason: String):
			if method=="bazaar.world":population.apply_stall_sellers([]))
	if smoke_mode:call_deferred("run_smoke")

func show_menu(title := "Bazaar Island", detail := "Explore the park market, town shops, gardens and harbor. Alt / light LS: walk · Shift / LB: sprint · C / R3: crouch · Space / X: jump. Trading is in development.") -> void:
	if is_instance_valid(services) and services.visible:services.hide();services.destroy_preview()
	touch_actions.hide()
	modal=true
	if not personal:population.set_paused(true);square.life.set_sound(sound.button_pressed,true)
	visitor.set_controls(false);touch_pad.enabled=false;touch_pad.reset();prompt.hide()
	if personal and title=="Bazaar Island":title=square.title();detail=square.description()
	menu_title.text=title;menu_body.text=detail;panel.show();resume.grab_focus()

func hide_menu() -> void:
	if is_instance_valid(services) and services.visible:services.hide();services.destroy_preview()
	modal=false
	if not personal:population.set_paused(false);square.life.set_sound(sound.button_pressed)
	panel.hide();visitor.set_controls(true);touch_pad.enabled=true;resume.release_focus()

func inspect_spot() -> void:
	if nearest.is_empty():return
	if nearest.has("arrival"):
		visitor.enter_space(nearest.arrival,nearest.yaw)
		visitor.touch_move=Vector2.ZERO;touch_pad.reset();nearest={};prompt.hide()
	elif nearest.has("service"):
		show_menu();panel.hide();services.open(nearest.service,int(nearest.get("slot",1)))
	else:show_menu(nearest.title,nearest.detail)

func _process(_delta: float) -> void:
	if compass!=null:compass.text=["N","W","S","E"][posmod(roundi(visitor.yaw/(PI/2)),4)]
	district_label.text=square.district(visitor.position)
	if modal:return
	nearest={};var distance := 2.1
	for spot in square.destinations:
		var candidate: float=visitor.global_position.distance_to(spot.position)
		if candidate<distance:distance=candidate;nearest=spot
	prompt.visible=not nearest.is_empty()
	if prompt.visible:prompt.text="E / A  ·  "+str(nearest.title)

func _unhandled_input(event: InputEvent) -> void:
	if touch_actions!=null:
		if event is InputEventScreenTouch:touch_actions.visible=not modal
		elif event is InputEventKey or event is InputEventJoypadButton:touch_actions.hide()
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
	leaving=true;visitor.set_controls(false)
	if not personal:square.life.stop_sound()
	# Let the audio mixer retire playback before engine shutdown.
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(code)

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():leave_bazaar()
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and not smoke_mode and not modal:show_menu()

func run_smoke() -> void:
	var suite = load("res://tests/personal_checks.gd" if personal else "res://tests/walkthrough.gd").new()
	add_child(suite);await suite.run(self)

func _exit_tree() -> void:
	if smoke_mode or sound==null or fov_slider==null:return
	var saved := ConfigFile.new();saved.set_value("camera","fov",fov_slider.value)
	saved.set_value("audio","fountain",sound.button_pressed);saved.save("user://bazaar-preferences.cfg")
