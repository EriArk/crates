# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
const Square = preload("res://scripts/square.gd")
const Walker = preload("res://scripts/walker.gd")
const TouchPad = preload("res://scripts/touch_pad.gd")
const Lines = preload("res://scripts/resident_lines.gd")
var audio = preload("res://scripts/market_audio.gd").new()
var dialogue = preload("res://scripts/conversation.gd").new()
var talk: Button
var music_toggle := CheckButton.new()
var effects_toggle := CheckButton.new()
var shown_sellers := {}
var speaker: Dictionary = {}
var visits := {}
var square: Node3D
var world_kind := "official"
var personal := false
var visitor = Walker.new()
var touch_pad = TouchPad.new()
var festival: Control
var services: Control
var population: Node3D
var identity := Label.new()
var place_caption: Label
var counter_tests: HBoxContainer
var island_visit
var festival_lab_button: Button
var lab_button: Button
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
var speech := Label.new()
var speech_position := Vector3.ZERO
var speech_time := 0.0
var service_camera := Camera3D.new()
var posing := false
var hud_parts: Array = []
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
	if not personal and "--arrival=festival" in OS.get_cmdline_user_args():
		visitor.enter_space(square.festival.ARENA+Vector3(0,.15,.8),0)
	else:visitor.enter_space(visitor.spawn_point,0)
	if not personal:
		population=load("res://scripts/population.gd").new();add_child(population);population.setup(square,visitor)
	audio.population = population
	audio.visitor = visitor
	add_child(audio)
	visitor.footfall.connect(func(at: Vector3, speed: float, crouched: bool):audio.footstep(square.foot_surface(at), speed, crouched))
	var hud := CanvasLayer.new();add_child(hud)
	var root := Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.add_child(root)
	root.add_child(touch_pad);touch_pad.move_changed.connect(func(value: Vector2):visitor.touch_move=value)
	touch_pad.look_changed.connect(visitor.look)
	# Small map/location corner; the view and contextual interaction stay central.
	var location := VBoxContainer.new();root.add_child(location);location.position=Vector2(22,18)
	location.mouse_filter=Control.MOUSE_FILTER_IGNORE
	district_label=label("Festival Park",20);location.add_child(district_label)
	place_caption=label("MIKA’S ISLAND  /  BEACH MARKET" if world_kind=="island" else "EMPTY STARTING SQUARE  /  LOCAL ALPHA" if personal else "BAZAAR ISLAND  /  ALPHA",10,Color("dfcfab"))
	location.add_child(place_caption)
	compass=label("N",13);root.add_child(compass)
	compass.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP);compass.position.y=18
	compass.name="Compass";compass.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var pause_button := button("☰",func():show_menu());root.add_child(pause_button)
	pause_button.focus_mode=Control.FOCUS_NONE
	pause_button.tooltip_text="Menu · Esc / Start"
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
	prompt.focus_mode = Control.FOCUS_NONE
	talk = button("T / Y  ·  Talk", start_conversation)
	root.add_child(talk)
	talk.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	talk.offset_left=-86;talk.offset_right=86;talk.offset_top=-127;talk.offset_bottom=-83
	talk.focus_mode = Control.FOCUS_NONE
	talk.hide()
	hud_parts=[location,compass,pause_button,hint]
	root.add_child(speech)
	speech.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	speech.offset_left=-243;speech.offset_right=243;speech.offset_top=-134;speech.offset_bottom=-82
	speech.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	speech.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	speech.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	speech.add_theme_stylebox_override("normal",backdrop())
	speech.mouse_filter=Control.MOUSE_FILTER_IGNORE
	speech.hide()
	service_camera.set_cull_mask_value(Square.COUNTER_SIGN_LAYER,false)
	add_child(service_camera)
	root.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT);panel.offset_left=18;panel.offset_right=448;panel.offset_top=-211;panel.offset_bottom=211
	var style := StyleBoxFlat.new();style.bg_color=Color("17272af5");style.border_color=Color("bba374");style.set_border_width_all(2);style.set_corner_radius_all(3)
	style.content_margin_left=24;style.content_margin_right=24;style.content_margin_top=20;style.content_margin_bottom=20;panel.add_theme_stylebox_override("panel",style)
	var menu := VBoxContainer.new();menu.add_theme_constant_override("separation",8);panel.add_child(menu)
	menu.add_child(label("FIELD MENU",12,Color("ffcf83")))
	menu_title.add_theme_font_size_override("font_size",25);menu.add_child(menu_title)
	identity.add_theme_font_size_override("font_size",12);menu.add_child(identity)
	menu_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;menu_body.custom_minimum_size=Vector2(382,20);menu.add_child(menu_body)
	var camera_row := HBoxContainer.new();camera_row.add_theme_constant_override("separation",12);menu.add_child(camera_row)
	fov_label=label("Field of view · 90°",14);fov_label.custom_minimum_size.x=146;camera_row.add_child(fov_label)
	fov_slider=HSlider.new();fov_slider.min_value=75;fov_slider.max_value=105;fov_slider.step=1;fov_slider.value=90
	fov_slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL;fov_slider.custom_minimum_size.y=30
	fov_slider.tooltip_text="Horizontal field of view at 16:9. Wider screens show more at the sides."
	fov_slider.value_changed.connect(func(value: float):visitor.set_field_of_view(value);fov_label.text="Field of view · %d°"%value)
	camera_row.add_child(fov_slider)
	var mixer := HBoxContainer.new()
	menu.add_child(mixer)
	music_toggle.text = "Music"
	effects_toggle.text = "Effects"
	for toggle in [music_toggle, effects_toggle]:
		toggle.button_pressed = true
		mixer.add_child(toggle)
	music_toggle.toggled.connect(audio.set_music)
	effects_toggle.toggled.connect(audio.set_effects)
	sound=CheckButton.new();sound.text="Fountain";sound.button_pressed=true;sound.custom_minimum_size.y=32
	sound.toggled.connect(func(enabled: bool):if not personal:square.life.set_sound(enabled,modal));mixer.add_child(sound);sound.visible=not personal
	resume=button("Continue exploring",hide_menu);menu.add_child(resume)
	reconnect=button("Use my TrainerOS character",func():visitor.reconnect();hide_menu());menu.add_child(reconnect)
	quit_button=button("Leave Bazaar",leave_bazaar);menu.add_child(quit_button)
	if not smoke_mode:
		var saved := ConfigFile.new()
		if saved.load("user://bazaar-preferences.cfg")==OK:
			fov_slider.value=clampf(float(saved.get_value("camera","fov",90.0)),75,105)
			sound.button_pressed=bool(saved.get_value("audio","fountain",true))
			music_toggle.button_pressed=bool(saved.get_value("audio","music",true))
			effects_toggle.button_pressed=bool(saved.get_value("audio","effects",true))
	audio.set_music(music_toggle.button_pressed)
	root.add_child(dialogue)
	dialogue.finished.connect(hide_menu)
	dialogue.syllable.connect(audio.syllable)
	panel.hide()
	if not personal:
		festival=preload("festival_panel.gd").new()
		festival.world=self;festival.ground=square.festival
		root.add_child(festival);festival.closed.connect(hide_menu)
	if world_kind!="station":
		services=load("res://scripts/service_menu.gd").new()
		services.square=square
		if not personal:services.outfit_selected.connect(square.fitting_booth.select)
		else:services.client.world_key="mika-island"
		services.turn_model.connect(func(angle: float):if posing:visitor.anchor.rotate_y(angle))
		root.add_child(services);services.closed.connect(hide_menu)
		lab_button=button("Enter test market",func():
			var use_lab: bool=services.client.endpoint_override.is_empty()
			services.client.use_lab(use_lab)
			if festival:festival.wallet.use_lab(use_lab)
			if island_visit:island_visit.use_endpoint(services.client.endpoint_override)
			place_caption.text="TEST MARKET  /  TEST SPARKS" if use_lab else "BAZAAR ISLAND  /  ALPHA"
			hide_menu())
		menu.add_child(lab_button);menu.move_child(lab_button,menu.get_child_count()-2)
		lab_button.hide()
		festival_lab_button=button("Enter festival test · Ren",func():
			var path:=_festival_lab_path()
			services.client.use_endpoint(path)
			if festival:festival.wallet.use_endpoint(path)
			if island_visit:island_visit.use_endpoint(path)
			place_caption.text="FESTIVAL TEST   /   REN   /   TEST SPARKS"
			hide_menu())
		menu.add_child(festival_lab_button)
		menu.move_child(festival_lab_button,menu.get_child_count()-2)
		festival_lab_button.hide()
		if personal:
			island_visit=preload("island_visit.gd").new()
			island_visit.visitor=visitor
			square.add_child(island_visit)
			island_visit.use_endpoint(services.client.endpoint_override)
		counter_tests=HBoxContainer.new()
		menu.add_child(counter_tests)
		menu.move_child(counter_tests,menu.get_child_count()-2)
		for account in ["Mika","Ren"]:
			var name_:String=account
			var entry:=button("Test · "+name_,func():
				var path:=_counter_lab_path(name_)
				services.client.use_endpoint(path)
				if festival:festival.wallet.use_endpoint(path)
				if island_visit:island_visit.use_endpoint(path)
				place_caption.text="COUNTER TEST   /   "+name_.to_upper()+"   /   TEST SPARKS"
				hide_menu())
			counter_tests.add_child(entry)
		counter_tests.hide()
		if not services.client.endpoint_override.is_empty():place_caption.text="TEST MARKET  /  TEST SPARKS"
		services.client.snapshot.connect(func(method: String, value: Dictionary):
			if method=="bazaar.world":
				update_counters(value.get("places",[]))
				if festival:square.festival.gallery.show_collection(value.get("won",[])))
		services.client.unavailable.connect(func(_reason: String):update_counters([]))
		services.client.read_failed.connect(func(method: String, _reason: String):
			if method=="bazaar.world":update_counters([]))
	if smoke_mode:call_deferred("run_smoke")

func update_counters(places: Array) -> void:
	square.update_showcases(places)
	if personal:return
	if places.is_empty():square.festival.gallery.show_collection([])
	var sellers := {}
	for row in places:
		if row.get("rental_id")!=null and row.get("species")!=null:
			sellers[int(row.slot)]=[row.rental_id,row.species]
	if sellers!=shown_sellers or population.hired_sellers.size()!=sellers.size():
		shown_sellers=sellers
		population.apply_stall_sellers(places)

func show_menu(title := "Bazaar Island", detail := "Festival Park  /  Market district") -> void:
	if lab_button:
		counter_tests.visible=FileAccess.file_exists(_counter_lab_path("Mika")) and FileAccess.file_exists(_counter_lab_path("Ren"))
		var in_lab: bool=not services.client.endpoint_override.is_empty()
		lab_button.visible=in_lab or FileAccess.file_exists(services.client.lab_endpoint())
		festival_lab_button.visible=not personal and not counter_tests.visible and FileAccess.file_exists(_festival_lab_path()) and services.client.endpoint_override!=_festival_lab_path()
		lab_button.text="Return to official market" if in_lab else "Enter test market"
	if is_instance_valid(services) and services.visible:services.close()
	visitor.attend(null)
	audio.set_quiet(true)
	talk.hide()
	speech.hide()
	touch_actions.hide()
	modal=true
	if not personal:population.set_paused(true);square.life.set_sound(sound.button_pressed,true)
	visitor.set_controls(false);touch_pad.enabled=false;touch_pad.reset();prompt.hide()
	if title=="Bazaar Island":
		title=square.title() if personal else square.district(visitor.position)
		detail=square.description() if personal else "Official island"
	menu_title.text=title;menu_body.text=detail;panel.show();resume.grab_focus()

func _counter_lab_path(account: String) -> String:
	return OS.get_environment("XDG_RUNTIME_DIR").path_join("traineros-counter-lab/"+account+"/sdk/endpoint.json")

func _festival_lab_path() -> String:
	return OS.get_environment("XDG_RUNTIME_DIR").path_join("traineros-festival-lab/sdk/endpoint.json")

func hide_menu() -> void:
	if is_instance_valid(festival) and festival.visible:
		festival.close();return
	if is_instance_valid(services) and services.visible:
		services.close()
		return
	dialogue.hide()
	audio.set_quiet(false)
	modal=false
	visitor.attend(null)
	visitor.camera.make_current()
	visitor.anchor.show()
	if posing:
		square.fitting_booth.leave()
		posing=false
	for part in hud_parts:
		if part!=hud_parts.back():part.show()
	if not personal:population.set_paused(false);square.life.set_sound(sound.button_pressed)
	panel.hide();visitor.set_controls(true);touch_pad.enabled=true;resume.release_focus()

func start_conversation() -> void:
	if modal or speaker.is_empty() or not is_instance_valid(speaker.node):return
	var person: String = speaker.speaker
	var visit_key: String = person + str(speaker.get("slot",""))
	var visit: int = visits.get(visit_key,0)
	visits[visit_key] = visit + 1
	var tone: float = {"Yeti":.72,"Bunny":1.27,"Frog":.83,"Birb":1.35,"Dino":.91}.get(speaker.species, .94 + posmod(person.hash(), 19)*.01)
	show_menu()
	panel.hide()
	for part in hud_parts:part.hide()
	var at: Vector3 = speaker.node.global_position
	var facing: Vector3 = visitor.global_position - at
	speaker.node.rotation.y = atan2(facing.x,facing.z)
	population.play(speaker,"Idle")
	speaker.player.active = true
	visitor.anchor.rotation.y = atan2(-facing.x,-facing.z)
	visitor.attend(at + Vector3.UP*1.15)
	# Frame close pedestrians in profile; the counter already separates shopkeepers.
	var toward := Vector3(facing.x,0,facing.z).normalized()
	if toward.is_zero_approx():toward = Vector3.BACK
	var side := Vector3.UP.cross(toward)
	var across: bool = not speaker.route.is_empty()
	var aim := at + Vector3.UP*.94 + toward * minf(facing.length()*.35,.5)
	var offset := side*3.25 + toward*.95 if across else toward*2.9 + side*1.7
	var eye := aim + Vector3.UP*.6
	var query := PhysicsRayQueryParameters3D.create(eye, eye+offset)
	query.exclude = [visitor.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():offset = offset.normalized()*maxf(.25,eye.distance_to(hit.position)-.15)
	service_camera.global_position = eye + offset
	service_camera.look_at(aim)
	if facing.length() < .7:visitor.anchor.hide()
	service_camera.fov = 41
	service_camera.make_current()
	dialogue.begin(person, Lines.pages(person,visit), tone)

func inspect_spot() -> void:
	if modal or nearest.is_empty():return
	if nearest.get("greeting",false):
		start_conversation()
		return
	if nearest.has("arrival"):
		visitor.enter_space(nearest.arrival,nearest.yaw)
		visitor.touch_move=Vector2.ZERO;touch_pad.reset();nearest={};prompt.hide()
	elif nearest.has("festival"):
		show_menu()
		panel.hide()
		for part in hud_parts:part.hide()
		festival.open(nearest.festival)
	elif nearest.has("service"):
		show_menu()
		panel.hide()
		for part in hud_parts:part.hide()
		var slot := int(nearest.get("slot",1))
		frame_service(nearest.service,slot)
		services.open(nearest.service,slot)
	else:
		speech.text=str(nearest.detail).get_slice("\n",0)
		speech_position=nearest.position
		speech_time=5.0
		speech.show()

func frame_service(kind: String, slot: int) -> void:
	if kind in ["office","island_office"]:return
	visitor.anchor.visible=kind=="tailor"
	var target: Vector3
	var toward: Vector3
	if kind=="stall":
		var layout: Dictionary=square.stall_layout(slot)
		target=layout.seller+Vector3.UP*.98
		toward=(layout.approach-layout.seller).normalized()
	else:
		target=visitor.global_position+Vector3.UP*.92
		toward=Vector3(.23,0,.97).normalized()
		if kind=="tailor":
			posing=true
			square.fitting_booth.enter(visitor)
			target=square.fitting_booth.global_position+Vector3.UP*1.15
			visitor.anchor.rotation.y=atan2(toward.x,toward.z)
		else:target=Vector3(visitor.position.x,1.0,-3.45)
	var right := Vector3.UP.cross(toward).normalized()
	var offset := right * (1.46 if kind=="stall" else 1.12)
	service_camera.global_position=target+toward*3.25+Vector3.UP*.38+offset
	service_camera.look_at(target+offset)
	service_camera.fov=42
	service_camera.make_current()

func _process(_delta: float) -> void:
	if compass!=null:compass.text=["N","W","S","E"][posmod(roundi(visitor.yaw/(PI/2)),4)]
	district_label.text=square.district(visitor.position)
	if modal:
		if posing:
			var control: Control=services.attention_control()
			if control and square.fitting_booth.curtain<.99:
				visitor.attend(service_camera.project_position(control.get_global_rect().get_center(),1.2))
			else:visitor.attend(null)
		return
	speech_time-=_delta
	if speech_time<=0 or visitor.global_position.distance_to(speech_position)>3.4:speech.hide()
	nearest={};var distance := 2.1
	for spot in square.destinations:
		var candidate: float=visitor.global_position.distance_to(spot.position)
		if candidate<distance:distance=candidate;nearest=spot
	prompt.visible=not nearest.is_empty()
	if nearest.is_empty() and not personal:
		for actor in population.residents:
			if actor.route.is_empty() or not actor.active:continue
			var at: Vector3=actor.node.global_position
			if visitor.global_position.distance_to(at)<distance:
				distance=visitor.global_position.distance_to(at)
				nearest={"title":"Talk to "+str(actor.speaker),"actor":actor,"position":at,"attention":at+Vector3.UP*1.12,"greeting":true,"detail":"Beautiful day for the market!"}
	speaker = {} if personal else population.speaker_at(nearest)
	talk.visible = nearest.has("service") and not speaker.is_empty()
	prompt.visible=not nearest.is_empty()
	if nearest.is_empty():
		visitor.attend(null)
	else:
		var target: Vector3=nearest.position
		visitor.attend(nearest.get("attention",target+Vector3.UP*1.5))
	if prompt.visible:
		var verb: String={"tea":"Visit Moss","curios":"Browse curios","stall":"Browse wares","office":"View rental map","tailor":"Visit fitting room"}.get(nearest.get("service",""),nearest.title)
		prompt.text="E / A  ·  "+verb

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
		elif event.physical_keycode==KEY_T and talk.visible:start_conversation()
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index==JOY_BUTTON_START or (modal and event.button_index==JOY_BUTTON_B):
			if modal:hide_menu()
			else:show_menu()
			get_viewport().set_input_as_handled()
		elif event.button_index==JOY_BUTTON_A and not modal:inspect_spot()
		elif event.button_index==JOY_BUTTON_Y and talk.visible:start_conversation()

func leave_bazaar(code := 0) -> void:
	if leaving:return
	leaving=true;visitor.set_controls(false)
	var voices: Array=[audio.music,audio.steps,audio.voice,audio.call]
	if not personal:voices.append_array([square.life.fountain_audio,square.festival.gallery.sound])
	var retiring: Array[WeakRef]=[]
	for voice in voices:
		if voice.has_stream_playback():retiring.append(weakref(voice.get_stream_playback()))
	audio.stop_all()
	if not personal:square.festival.gallery.sound.stop()
	if island_visit:await island_visit.leave()
	if not personal:square.life.stop_sound()
	# The mixer releases stopped voices on its own clock. A fast scene exit can precede that callback.
	var deadline:=Time.get_ticks_msec()+900
	for playback in retiring:
		while playback.get_ref()!=null and Time.get_ticks_msec()<deadline:
			await get_tree().process_frame
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
	saved.set_value("audio","music",music_toggle.button_pressed)
	saved.set_value("audio","effects",effects_toggle.button_pressed)
	saved.set_value("audio","fountain",sound.button_pressed);saved.save("user://bazaar-preferences.cfg")

func transit_session() -> Node:
	return null

func transit_avatar_ready() -> bool:
	return visitor.startup_resolved

func set_transit_controls(locked: bool) -> void:
	visitor.set_controls(not locked and not modal)
