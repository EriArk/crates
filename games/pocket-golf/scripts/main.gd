# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
const Match = preload("res://scripts/match.gd")
const Courses = preload("res://scripts/courses.gd")
const AvatarAnchor = preload("res://scripts/avatar_anchor.gd")
const AvatarBinding = preload("res://scripts/avatar_binding.gd")
const AvatarRoster = preload("res://scripts/avatar_roster.gd")
const Stroke = preload("res://scripts/golf_stroke.gd")
const Size = preload("res://scripts/dimensions.gd")
const GolfCamera = preload("res://scripts/golf_camera.gd")
const Island = preload("res://scripts/island.gd")
const GolfHud = preload("res://scripts/golf_hud.gd")
const Surfaces = preload("res://scripts/surfaces.gd")
const GreenSurface = preload("res://scripts/green_surface.gd")
const Graphics = preload("res://scripts/graphics_settings.gd")
const AimInput = preload("res://scripts/aim_input.gd")
const Audio = preload("res://scripts/golf_audio.gd")
var audio = Audio.new()
var audio_open := false
var audio_notice := ""
var audio_focused := true
var audio_sliders: Array[HSlider] = []
var audio_labels: Array[Label] = []
var presentation_phase := ""
var quitting := false
var graphics = Graphics.new()
var graphics_open := false
var graphics_notice := ""
var contrast_slider: HSlider
var contrast_label: Label
const MINT := Color("579e88")
const CORAL := Color("dd9579")
var game = Match.new()
var course_root: Node3D
var green_grid := PackedInt32Array()
var green_mesh: MeshInstance3D
var island: Island
var camera: GolfCamera
var balls: Array[Node3D] = []
var anchor = AvatarAnchor.new()
var avatar_binding = AvatarBinding.new()
var avatar_roster = AvatarRoster.new()
var local_setup := false
var setup_count := 2
var setup_teams := false
var setup_assignment: Array = [0,1]
var setup_grid: GridContainer
var setup_count_button: Button
var setup_mode_button: Button
var setup_start_button: Button
const SIDE_COLORS := [Color("579e88"),Color("dd9579"),Color("8d9ed6"),Color("dfbb65")]
const SIDE_NAMES := ["Mint","Coral","Iris","Honey"]
var aim_root: Node3D
var cup: Node3D
var field_index := -1
var shot: Dictionary = {}
var shot_course: Dictionary = {}
var elapsed := 0.0
var last_frame := -1
var effects = preload("res://scripts/golf_effects.gd").new()
var touches: Dictionary = {}
var paused := false
var touch_mode := false
var repeat_time := 0.0
var last_axis := Vector2.ZERO
var neutral_required := false
var root_ui: Control
var hud: GolfHud
var input_kind := "keyboard"
var modal_shade: ColorRect
var popup: PanelContainer
var popup_title: Label
var popup_text: Label
var popup_buttons: VBoxContainer
var last_popup := ""
var boards_open := false
var board_mode := "individual"
var board_kind := "records"
var result_text := ""
var ball_materials: Array = []
var capture_dir := ""

func _ready() -> void:
	graphics.load_settings()
	add_child(audio)
	get_tree().auto_accept_quit=false
	get_window().close_requested.connect(_quit_game)
	if OS.get_environment("TRAINEROS_CRATES_GAME")=="1": get_window().mode=Window.MODE_FULLSCREEN
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sdk-endpoint="): game.bridge.endpoint_override=arg.trim_prefix("--sdk-endpoint=")
	_setup_scene()
	anchor.ground=_ground
	anchor.foot_landed.connect(func(side): audio.cue("step_l" if side=="L" else "step_r"))
	_setup_ui()
	add_child(game)
	game.changed.connect(_refresh)
	game.shot_started.connect(_shot_started)
	add_child(avatar_binding)
	avatar_binding.start(anchor,_placeholder,game.bridge.endpoint_override)
	avatar_binding.portraits_changed.connect(func(): hud.set_portraits(avatar_binding.local_portrait,avatar_binding.peer_portrait))
	add_child(avatar_roster)
	avatar_roster.start(avatar_binding,game)
	avatar_roster.changed.connect(_refresh)
	game.bridge.identity_revoked.connect(avatar_binding.disconnect_identity)
	Input.joy_connection_changed.connect(func(_device, connected):
		neutral_required=true
		if not connected: _suspend_input()
		_set_input("pad" if connected else "keyboard"))
	get_window().focus_exited.connect(_suspend_input)
	get_window().focus_exited.connect(func(): audio_focused=false; audio.set_state(false,paused))
	get_window().focus_entered.connect(func(): audio_focused=true; audio.set_state(true,paused))
	_refresh()
	graphics.apply(self)
	_connect_sdk.call_deferred()

func _connect_sdk() -> void:
	# The first draw may compile the island shaders. Open bounded IPC only once
	# rendering is ready, so its hello deadline does not run during shader setup.
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
	if not OS.get_environment("TRAINEROS_SDK_ENDPOINT").is_empty() or not game.bridge.endpoint_override.is_empty():
		game.bridge.connect_host()
	avatar_binding.client.connect_host()

func material(color: Color, roughness: float = 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color=color
	m.roughness=roughness
	return m

func mesh(parent: Node3D, shape: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh=shape
	node.material_override=material(color)
	node.position=pos
	parent.add_child(node)
	return node

func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, kind: int=-1) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size=size
	var node := mesh(parent,shape,pos,color)
	if kind>=0:
		node.material_override=Surfaces.make(color,kind,Vector3.RIGHT if size.x>size.z else Vector3.FORWARD)
		if kind==Surfaces.Kind.TURF:
			var walls := PackedVector4Array()
			for wall in Courses.get_course(field_index).walls:
				walls.append(Vector4(wall[0],wall[1],wall[2],wall[3])/1000.0)
			node.material_override.set_shader_parameter("obstacle_count",mini(walls.size(),8))
			walls.resize(8)
			node.material_override.set_shader_parameter("obstacles",walls)
	return node

func sphere(parent: Node3D, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius=radius; shape.height=radius*2; shape.radial_segments=20; shape.rings=12
	return mesh(parent,shape,pos,color)

func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius=radius; shape.bottom_radius=radius; shape.height=height; shape.radial_segments=32
	return mesh(parent,shape,pos,color)

func _setup_scene() -> void:
	# Compatibility blends shadowed lighting differently; keep the pastel palette readable.
	var compatibility := RenderingServer.get_current_rendering_method()=="gl_compatibility"
	var environment := WorldEnvironment.new()
	environment.name="WorldEnvironment"
	var env := Environment.new()
	env.background_mode=Environment.BG_SKY
	var sky := Sky.new(); var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color=Color("72bed8")
	sky_material.sky_horizon_color=Color("c5e7e5")
	sky_material.ground_horizon_color=Color("c5e7e5")
	sky_material.ground_bottom_color=Color("4b9db1")
	sky_material.sun_angle_max=3.0
	sky.sky_material=sky_material; env.sky=sky
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("b7d5e8")
	env.ambient_light_energy=0.32 if compatibility else 0.48
	# Compatibility shades in sRGB; ACES overdrives its sunny grass and sand.
	env.tonemap_mode=Environment.TONE_MAPPER_LINEAR if compatibility else Environment.TONE_MAPPER_ACES
	# Gentle distance separation; the playable island remains crisp.
	env.fog_enabled=true
	env.fog_mode=Environment.FOG_MODE_DEPTH
	env.fog_depth_begin=80.0; env.fog_depth_end=240.0
	env.fog_density=0.35; env.fog_light_color=Color("b8dbdc")
	env.fog_light_energy=1.0; env.fog_sky_affect=0.0
	environment.environment=env
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.name="Sun"
	light.rotation_degrees=Vector3(-36,-55,0)
	light.light_color=Color("ffebcb")
	light.light_energy=0.50 if compatibility else 0.90
	light.shadow_enabled=true
	light.directional_shadow_max_distance=125.0
	light.directional_shadow_blend_splits=true
	light.directional_shadow_split_1=0.08
	light.directional_shadow_split_2=0.25
	light.directional_shadow_split_3=0.60
	light.shadow_bias=0.10
	light.shadow_normal_bias=2.0
	light.shadow_blur=1.2
	add_child(light)
	camera=GolfCamera.new()
	camera.near=0.05
	add_child(camera)
	camera.frame(0,Vector3.ZERO,Vector3.ZERO,0,false,false)
	camera.current=true
	add_child(effects)
	add_child(anchor)
	# Offline/guest marker; actual user appearance comes exclusively from the SDK.
	_placeholder()

func _placeholder() -> void:
	var marker := Node3D.new()
	cylinder(marker,0.28,0.85,Vector3(0,0.45,0),Color("e8c386"))
	sphere(marker,0.29,Vector3(0,1.05,0),Color("f7e8c9"))
	var club: Node3D = preload("res://assets/kenney/golf/club-green.glb").instantiate()
	club.position=Vector3(0.45,0.68,0); club.scale=Vector3.ONE*0.8; marker.add_child(club)
	anchor.install_visual(marker,"")

func _build_course() -> void:
	effects.clear()
	audio.clear_shot(); anchor.reset_motion()
	if course_root!=null:
		remove_child(course_root); course_root.queue_free()
	course_root=Node3D.new(); add_child(course_root)
	field_index=game.world.hole
	var c := Courses.get_course(field_index)
	green_grid=c.height_grid
	camera.obstruction_height=0.6
	island=Island.new(); course_root.add_child(island); island.build(field_index)
	box(course_root,Vector3(10.6,0.16,16.6),Vector3(0,-0.14,0),Color("d4b78b"),Surfaces.Kind.WOOD)
	# The exact same triangle grid supplies physics height/gradients and this mesh.
	green_mesh=MeshInstance3D.new(); green_mesh.name="PlayableGreen"
	green_mesh.mesh=GreenSurface.make_mesh(green_grid)
	var turf := Surfaces.make(Color("80bc8c"),Surfaces.Kind.TURF)
	turf.set_shader_parameter("course_surface",true)
	var sand_bounds := PackedVector4Array(); var wall_bounds := PackedVector4Array()
	for sand in c.sand: sand_bounds.append(Vector4(sand[0],sand[1],sand[2],sand[3])/1000.0)
	for wall in c.walls: wall_bounds.append(Vector4(wall[0],wall[1],wall[2],wall[3])/1000.0)
	turf.set_shader_parameter("sand_count",sand_bounds.size()); sand_bounds.resize(8)
	turf.set_shader_parameter("sand_bounds",sand_bounds)
	turf.set_shader_parameter("obstacle_count",wall_bounds.size()); wall_bounds.resize(8)
	turf.set_shader_parameter("obstacles",wall_bounds)
	green_mesh.material_override=turf; course_root.add_child(green_mesh)
	for x in [-5.12,5.12]: box(course_root,Vector3(0.24,0.4,16.5),Vector3(x,0.13,0),Color("d7b27e"),Surfaces.Kind.WOOD)
	for z in [-8.12,8.12]: box(course_root,Vector3(10.5,0.4,0.24),Vector3(0,0.13,z),Color("d7b27e"),Surfaces.Kind.WOOD)
	for x in [-5.12,5.12]:
		for z in [-8.12,8.12]: cylinder(course_root,0.18,0.44,Vector3(x,0.15,z),Color("f2d7a0"))
	for wall in c.walls:
		var top := 0.6
		for x in range(wall[0],wall[2]+251,250):
			for z in range(wall[1],wall[3]+251,250):
				top=maxf(top,_ground(Vector3(x/1000.0,0,z/1000.0))+0.6)
		camera.obstruction_height=maxf(camera.obstruction_height,top)
		# Extend below all nearby ground so no wall floats above a downhill side.
		box(course_root,Vector3((wall[2]-wall[0])/1000.0,top,(wall[3]-wall[1])/1000.0),Vector3((wall[0]+wall[2])/2000.0,top/2,(wall[1]+wall[3])/2000.0),Color("9baaa2"),Surfaces.Kind.STONE)
	cup=Node3D.new(); cup.position=Vector3(c.cup[0]/1000.0,GreenSurface.sample(green_grid,c.cup[0],c.cup[1])[0]/1000.0,c.cup[1]/1000.0); course_root.add_child(cup)
	cylinder(cup,Size.CUP+0.012,0.004,Vector3(0,0.004,0),Color("f1e4c4"))
	cylinder(cup,Size.CUP,0.004,Vector3(0,0.007,0),Color("284e43"))
	island.flag=island.prop("golf/flag-red",cup.position+Vector3(0,0.01,0),1.0,0.2)
	balls.clear()
	for i in game.world.players:
		var ball := Node3D.new(); course_root.add_child(ball)
		var visual := sphere(ball,Size.BALL,Vector3.ZERO,Color("fff8e7") if i==0 else CORAL)
		visual.name="RollingBall"
		# A narrow painted band makes physical rolling readable, even on a small screen.
		var band := TorusMesh.new(); band.inner_radius=Size.BALL-0.001; band.outer_radius=Size.BALL+0.0004
		mesh(visual,band,Vector3.ZERO,MINT if i==0 else Color("fff0d5"))
		# A floor ring distinguishes the two overlapping tee positions without moving rules.
		cylinder(ball,0.065,0.002,Vector3(0,-Size.BALL,0),SIDE_COLORS[i%4])
		balls.append(ball)
	aim_root=Node3D.new(); course_root.add_child(aim_root)
	for i in 8: sphere(aim_root,0.012,Vector3(0,0.02,-0.15-i*0.15),Color("fff4d4"))
	graphics.apply(self)

func _ground(point: Vector3) -> float:
	return GreenSurface.sample(green_grid,roundi(point.x*1000),roundi(point.z*1000))[0]/1000.0

func _stance(ball: Vector3, radians: float) -> Vector3:
	var feet := ball+Vector3(-cos(radians)*Size.STANCE,0,-sin(radians)*Size.STANCE)
	feet.y=_ground(feet)
	return feet

func _align_marker(ball: Node3D) -> void:
	var normal := GreenSurface.normal(green_grid,roundi(ball.position.x*1000),roundi(ball.position.z*1000))
	ball.get_child(1).basis=Basis(Quaternion(Vector3.UP,normal))
	ball.get_child(1).position.y=_ground(ball.position)-ball.position.y+0.003

func _setup_ui() -> void:
	var canvas := CanvasLayer.new(); add_child(canvas)
	root_ui=Control.new(); root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root_ui.mouse_filter=Control.MOUSE_FILTER_IGNORE; canvas.add_child(root_ui)
	var theme := Theme.new(); theme.default_font_size=20
	var style := StyleBoxFlat.new(); style.bg_color=Color("f5efdf"); style.set_corner_radius_all(12); style.content_margin_left=18; style.content_margin_right=18; style.content_margin_top=10; style.content_margin_bottom=10
	theme.set_stylebox("normal","Button",style)
	var focus := style.duplicate(); focus.border_color=MINT; focus.set_border_width_all(3); theme.set_stylebox("focus","Button",focus)
	var hover := style.duplicate(); hover.bg_color=Color("e1e8cd"); theme.set_stylebox("hover","Button",hover); theme.set_stylebox("pressed","Button",hover)
	theme.set_color("font_color","Button",Color("294e43")); theme.set_color("font_focus_color","Button",Color("294e43")); theme.set_color("font_hover_color","Button",Color("294e43")); theme.set_color("font_pressed_color","Button",Color("294e43"))
	theme.set_color("font_color","Label",Color("294e43")); root_ui.theme=theme
	hud=GolfHud.new(); root_ui.add_child(hud)
	hud.pause_requested.connect(_pause)
	hud.view_requested.connect(_cycle_view)
	hud.putt_requested.connect(_primary)
	hud.aim_dragged.connect(func(degrees): game.adjust_continuous(degrees,0))
	hud.power_selected.connect(func(percent): game.adjust_continuous(0,percent-game.power))
	modal_shade=ColorRect.new(); modal_shade.color=Color(0.04,0.12,0.13,0.24)
	modal_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root_ui.add_child(modal_shade)
	popup=PanelContainer.new(); root_ui.add_child(popup); popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	popup.offset_left=-220; popup.offset_right=220; popup.offset_top=-182; popup.offset_bottom=182
	var panel := style.duplicate(); panel.bg_color=Color("faf3e3"); panel.set_corner_radius_all(20); panel.content_margin_left=26; panel.content_margin_right=26; panel.content_margin_top=20; panel.content_margin_bottom=20
	popup.add_theme_stylebox_override("panel",panel)
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation",12); popup.add_child(column)
	popup_title=Label.new(); popup_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; popup_title.add_theme_font_size_override("font_size",30); column.add_child(popup_title)
	popup_text=Label.new(); popup_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; popup_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; popup_text.custom_minimum_size=Vector2(375,48); column.add_child(popup_text)
	popup_buttons=VBoxContainer.new(); popup_buttons.add_theme_constant_override("separation",8); column.add_child(popup_buttons)

func label(parent: Node, text: String, pos: Vector2, size: int) -> Label:
	var node := Label.new(); node.text=text; node.position=pos; node.add_theme_font_size_override("font_size",size); parent.add_child(node); return node

func button(parent: Node, text: String, action: Callable) -> Button:
	var node := Button.new(); node.text=text; node.custom_minimum_size.y=46; parent.add_child(node)
	node.pressed.connect(func(): audio.cue("ui")); node.pressed.connect(action); return node

func _refresh() -> void:
	if boards_open and game.phase not in ["menu","result"]: boards_open=false
	if presentation_phase!=game.phase:
		if game.phase!="moving": anchor.reset_motion(); audio.clear_shot()
		if game.phase=="menu": audio.reset()
		if game.phase=="result": audio.cue("round-jingle")
		presentation_phase=game.phase
	var avatar_seat: int = shot.get("actor",shot.player) if game.phase=="moving" and not shot.is_empty() else game.world.actor()
	avatar_roster.select_actor(avatar_seat,game.phase!="moving")
	if game.phase=="menu":
		paused=false; effects.clear()
	if field_index<0 or (game.phase!="moving" and (field_index!=game.world.hole or balls.size()!=game.world.players)): _build_course()
	if game.phase!="moving":
		for i in balls.size():
			if i>=game.world.balls.size(): continue
			var p: Array = game.world.balls[i]
			balls[i].position=Vector3(p[0]/1000.0,GreenSurface.ball_height(green_grid,p[0],p[1])/1000.0,p[1]/1000.0)
			_align_marker(balls[i])
			balls[i].visible=not game.world.finished[i]
			if i!=game.world.turn and p==game.world.balls[game.world.turn]: balls[i].visible=false
	var c := Courses.get_course(field_index)
	var counts: Array = shot.strokes if game.phase=="moving" and not shot.is_empty() else game.world.strokes
	var totals: Array = []
	for i in game.world.players:
		totals.append(game.world.total(i)+(counts[i] if game.world.scores[i].size()<=field_index else 0))
	var player: String = _actor_name(game.world.actor())+" \u00b7 "+SIDE_NAMES[game.world.turn]
	var confirm := "A"; var back := "B"; var view := "X"
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		var name := Input.get_joy_name(pads[0]).to_lower()
		if "playstation" in name or "dual" in name or "ps5" in name: confirm="×"; back="○"; view="□"
		elif "nintendo" in name or "switch" in name: confirm="B"; back="A"; view="Y"
	var side_labels: Array = []; var side_portraits: Array = []
	for i in game.world.players:
		var actor: int = avatar_seat if i==(shot.player if game.phase=="moving" and not shot.is_empty() else game.world.turn) else game.world.actor(i)
		side_labels.append(SIDE_NAMES[i]+" \u00b7 "+_actor_name(actor))
		side_portraits.append(avatar_roster.portrait(actor))
	hud.side_portraits=side_portraits
	hud.update_state({"side_labels":side_labels,"thinking":game.solo_bot and game.world.actor()==1,"hole":field_index+1,"title":c.title,"par":c.par,
		"players":game.world.players,"player":shot.player if game.phase=="moving" and not shot.is_empty() else game.world.turn,
		"strokes":counts,"totals":totals,
		"power":game.power,"angle":game.angle,"phase":game.phase,"paused":paused,
		"online":game.online,"seat":game.seat,"can_shoot":game.can_fire() and not paused,
		"mode":"touch" if touch_mode else input_kind,"confirm":confirm,"back":back,"view_key":view,
		"view":GolfCamera.TITLES[camera.view]})
	if game.phase!="moving": hud.set_status("")
	# Turn ownership gates input, not the opponent's presence on the green.
	anchor.visible=(game.phase in ["aim","moving","waiting_turn"]) and not paused
	if camera.view==GolfCamera.View.EYES and game.phase!="moving": anchor.visible=false
	aim_root.visible=game.phase=="aim" and not paused
	if game.phase=="aim":
		var ball: Vector3 = balls[game.world.turn].position
		var radians := deg_to_rad(game.angle)
		anchor.position=_stance(ball,radians)
		anchor.rotation.y=-radians
		if aim_root.visible:
			for i in aim_root.get_child_count():
				var point := ball+Vector3(sin(radians),0,-cos(radians))*(0.15+i*0.15)
				point.y=_ground(point)+0.012
				aim_root.get_child(i).position=point
	audio.set_state(audio_focused,paused)
	var state: String = "boards" if boards_open else "setup" if local_setup else "audio" if audio_open else "graphics" if graphics_open else "paused" if paused else game.phase
	popup.visible=state in ["menu","waiting","handoff","result","paused","graphics","audio","setup","boards"]
	modal_shade.visible=popup.visible
	if popup.visible: touches.clear(); hud.cancel_pointers()
	if popup.visible and state!=last_popup:
		if state=="setup" and game.online:
			setup_count=game.participant_count; setup_teams=setup_count not in [2,4]; _default_teams()
		last_popup=state
		var half_height := 250 if state in ["setup","boards"] else 230 if state=="result" else 200
		popup.offset_top=-half_height; popup.offset_bottom=half_height
		popup_text.add_theme_font_size_override("font_size",18 if state=="boards" else 20)
		for child in popup_buttons.get_children(): popup_buttons.remove_child(child); child.queue_free()
		if state=="menu":
			popup_title.text="Pocket Golf"; popup_text.text="Three little greens. Take your time.\nFewest strokes wins."
			button(popup_buttons,"Solo · island rival",func(): field_index=-1; paused=false; game.local(2,[],true))
			button(popup_buttons,"Local match",func(): local_setup=true; setup_count=2; setup_teams=false; _default_teams(); _refresh())
			button(popup_buttons,"Shared tables",_open_boards)
			var settings_row := HBoxContainer.new(); popup_buttons.add_child(settings_row)
			button(settings_row,"Graphics",_open_graphics).size_flags_horizontal=Control.SIZE_EXPAND_FILL
			button(settings_row,"Sound",_open_audio).size_flags_horizontal=Control.SIZE_EXPAND_FILL
			button(popup_buttons,"Exit",_quit_game)
		elif state=="handoff":
			popup_title.text=player+" to putt"; popup_text.text="Hole %d / 3 · Par %d\n%s" % [game.world.hole+1,c.par,"Pass the controller, then confirm." if game.participant_count>1 and not game.solo_bot else "Aim with left/right. Power with up/down."]
			button(popup_buttons,"Ready",func(): game.accept_turn())
		elif state=="waiting":
			popup_title.text="Connecting match"; popup_text.text=game.info
			button(popup_buttons,"Back",func(): game.leave())
		elif state=="setup":
			popup_title.text="Players & teams"
			var options := HBoxContainer.new(); popup_buttons.add_child(options)
			setup_count_button=button(options,"",_cycle_count)
			setup_count_button.disabled=game.online
			setup_mode_button=button(options,"",_toggle_teams)
			setup_grid=GridContainer.new(); setup_grid.columns=2; popup_buttons.add_child(setup_grid)
			for i in 8:
				button(setup_grid,"",func(): _cycle_team(i)).size_flags_horizontal=Control.SIZE_EXPAND_FILL
			var actions := HBoxContainer.new(); popup_buttons.add_child(actions)
			setup_start_button=button(actions,"Start round",_start_configured)
			button(actions,"Back",func(): local_setup=false; game.leave() if game.online else _refresh())
			for control in _popup_controls():
				control.custom_minimum_size.y=38
				control.add_theme_font_size_override("font_size",18)
				control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		elif state=="result":
			popup_title.text="Round complete"
			var lines: Array = []; var winners: Array = []; var lowest := 100000
			for i in game.world.players:
				var total: int = game.world.total(i)
				lines.append("%s: %s = %d"%[SIDE_NAMES[i]," \u00b7 ".join(game.world.scores[i].map(func(n): return str(n))),total])
				if total<lowest: lowest=total; winners=[SIDE_NAMES[i]]
				elif total==lowest: winners.append(SIDE_NAMES[i])
			result_text="\n".join(lines)+"\n"+(winners[0]+" wins!" if winners.size()==1 else "Draw: "+" / ".join(winners))
			button(popup_buttons,"Play again",func(): game.rematch())
			button(popup_buttons,"Shared tables",_open_boards)
			button(popup_buttons,"Main menu",func(): game.leave())
		elif state=="boards":
			popup_title.text="Island clubhouse"
			var filters := HBoxContainer.new(); popup_buttons.add_child(filters)
			button(filters,"",func(): board_mode="teams" if board_mode=="individual" else "individual"; _load_board())
			button(filters,"",func(): board_kind="wins" if board_kind=="records" else "records"; _load_board())
			var pages := HBoxContainer.new(); popup_buttons.add_child(pages)
			button(pages,"Previous",func(): _load_board(maxi(0,int(game.scorecards.board.get("offset",0))-5),game.scorecards.board.get("revision","")))
			button(pages,"Next",func(): _load_board(int(game.scorecards.board.get("next_offset",0)),game.scorecards.board.get("revision","")))
			var actions := HBoxContainer.new(); popup_buttons.add_child(actions)
			button(actions,"Retry result",func(): game.scorecards.retry_result())
			button(actions,"Back",func(): boards_open=false; _refresh())
			for control in _popup_controls():
				control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
				control.add_theme_font_size_override("font_size",18)
		elif state=="paused":
			popup_title.text="Take a breather"
			button(popup_buttons,"Keep playing",func(): paused=false; _refresh())
			button(popup_buttons,"Leave round",func(): paused=false; game.leave())
			button(popup_buttons,"Reset camera",func(): camera.reset_view(); paused=false; _refresh())
			button(popup_buttons,"Graphics",_open_graphics)
			button(popup_buttons,"Sound",_open_audio)
		elif state=="audio":
			popup_title.text="Island sounds"
			audio_sliders.clear(); audio_labels.clear()
			for setting in ["Music","Effects"]:
				var row := HBoxContainer.new(); popup_buttons.add_child(row)
				var caption := Label.new(); caption.custom_minimum_size.x=156; row.add_child(caption); audio_labels.append(caption)
				var slider := HSlider.new(); slider.min_value=0; slider.max_value=100; slider.step=5
				slider.custom_minimum_size=Vector2(180,46); slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
				row.add_child(slider); audio_sliders.append(slider)
				slider.value_changed.connect(func(value):
					if setting=="Music": audio.music_percent=roundi(value)
					else: audio.effects_percent=roundi(value)
					audio.apply_levels()
					audio_notice="Could not save; active until exit." if audio.save_settings()!=OK else ""
					_refresh())
			button(popup_buttons,"Back",_close_audio)
		elif state=="graphics":
			popup_title.text="Graphics"
			button(popup_buttons,"",func(): graphics.quality=(graphics.quality+1)%3; _apply_graphics())
			button(popup_buttons,"",func(): graphics.scale_percent={50:75,75:100,100:50}[graphics.scale_percent]; _apply_graphics())
			button(popup_buttons,"",func(): graphics.fps=30 if graphics.fps==60 else 60; _apply_graphics())
			var contrast_row := HBoxContainer.new(); popup_buttons.add_child(contrast_row)
			contrast_label=Label.new(); contrast_label.custom_minimum_size.x=156; contrast_row.add_child(contrast_label)
			contrast_slider=HSlider.new(); contrast_slider.min_value=80; contrast_slider.max_value=150; contrast_slider.step=5
			contrast_slider.custom_minimum_size=Vector2(180,46); contrast_slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			contrast_slider.tooltip_text="100% is the original image. Left/right adjusts; confirm resets."
			contrast_slider.set_value_no_signal(graphics.contrast_percent); contrast_row.add_child(contrast_slider)
			contrast_slider.value_changed.connect(func(value):
				graphics.contrast_percent=roundi(value); graphics.apply_contrast(self); _save_graphics(); _refresh())
			button(popup_buttons,"Back",_close_graphics)
		var controls := _popup_controls()
		if not controls.is_empty(): controls[0].grab_focus()
	elif not popup.visible: last_popup=""
	if state=="setup":
		_refresh_setup()
	if state=="paused":
		popup_text.text="Left stick: aim / power · Right stick: look\nTriggers: zoom · %s: view · R3: reset"%view if input_kind=="pad" else "Drag the green: look · Pinch: zoom\nDrag aim / power · Tap PUTT to strike" if touch_mode else "Arrows: aim / power · Enter: putt\nWASD: look · Q/E: zoom · Tab: view · R: reset"
	if state=="waiting": popup_text.text=game.info
	if state=="boards": _refresh_boards()
	if state=="graphics":
		popup_text.text="Applies now · saved on this device\nContrast: 100% = original image" if graphics_notice.is_empty() else graphics_notice
		popup_buttons.get_child(0).text="Quality: "+Graphics.TITLES[graphics.quality]
		popup_buttons.get_child(1).text="3D resolution: %d%%"%graphics.scale_percent
		popup_buttons.get_child(2).text="Frame limit: %d FPS"%graphics.fps
		contrast_label.text="Contrast: %d%%"%graphics.contrast_percent
		contrast_slider.set_value_no_signal(graphics.contrast_percent)
	if state=="audio":
		popup_text.text="Music · a little island melody\nEffects · putts, footsteps and jingles" if audio_notice.is_empty() else audio_notice
		for i in 2:
			var value: int = audio.music_percent if i==0 else audio.effects_percent
			audio_labels[i].text=("Music" if i==0 else "Effects")+(": Off" if value==0 else ": %d%%"%value)
			audio_sliders[i].set_value_no_signal(value)
	if state=="menu" and game.info!="A little green. A good time.": popup_text.text=game.info
	if state=="result":
		popup_text.text=("Rematch requested. Waiting for all players…" if game.voted else result_text)+"\n"+game.scorecards.message
		popup_buttons.get_child(0).disabled=game.voted or game.scorecards.busy
		popup_buttons.get_child(1).disabled=game.voted or game.scorecards.busy

func _open_boards() -> void:
	boards_open=true; _refresh(); _load_board()

func _load_board(offset: int = 0, revision: String = "") -> void:
	game.scorecards.fetch_board(board_mode,board_kind,offset,revision)

func _refresh_boards() -> void:
	var data: Dictionary = game.scorecards.board
	var lines: Array = ["Fewest strokes" if board_kind=="records" else "Outright wins · draws stay draws"]
	for row in data.get("items",[]):
		var names: Array = []
		for id in row.get("members",[]): names.append("You" if id==game.scorecards.player else "P "+str(id).substr(0,6))
		lines.append("%d.  %s   ·   %d"%[row.place," / ".join(names),row.value])
	if data.get("items",[]).is_empty() and not data.is_empty(): lines.append("Be the first to finish a confirmed round.")
	lines.append(""); lines.append(game.scorecards.board_message)
	if game.scorecards.poll_at>0: lines.append(game.scorecards.message)
	popup_text.text="\n".join(lines)
	var filters := popup_buttons.get_child(0)
	filters.get_child(0).text="Teams" if board_mode=="teams" else "Individual"
	filters.get_child(1).text="Wins" if board_kind=="wins" else "Records"
	for child in filters.get_children(): child.disabled=game.scorecards.busy
	var pages := popup_buttons.get_child(1)
	pages.get_child(0).disabled=game.scorecards.busy or data.get("offset",0)==0
	pages.get_child(1).disabled=game.scorecards.busy or data.get("next_offset")==null
	popup_buttons.get_child(2).get_child(0).disabled=game.scorecards.busy

func _open_graphics() -> void:
	graphics_open=true; graphics_notice=""; _refresh()

func _open_audio() -> void:
	audio_open=true; audio_notice=""; _refresh()

func _quit_game() -> void:
	if quitting: return
	quitting=true
	audio.shutdown()
	# Release decoder references on the mixer thread before engine teardown.
	await get_tree().create_timer(0.20).timeout
	get_tree().quit()

func _close_audio() -> void:
	audio_open=false; _refresh()

func _close_graphics() -> void:
	graphics_open=false; _refresh()

func _apply_graphics() -> void:
	graphics.apply(self)
	_save_graphics()
	_refresh()

func _save_graphics() -> void:
	graphics_notice="Could not save settings; active until exit." if graphics.save_settings()!=OK else ""

func _popup_controls() -> Array[Control]:
	var result: Array[Control] = []
	for child in popup_buttons.get_children():
		if child is Button and child.visible and not child.disabled: result.append(child)
		elif child is Container:
			for control in child.get_children():
				if control.visible and (control is Slider or control is Button and not control.disabled): result.append(control)
	return result

func _start_local(count: int) -> void:
	# Force presentation rebuild when switching one/two-player modes on the same hole.
	field_index=-1; paused=false; game.local(count)

func _shot_started(result: Dictionary) -> void:
	shot=result
	hud.set_status("Putting…")
	elapsed=0
	last_frame=-1
	var origin: Array = result.path[0]
	var radians := deg_to_rad(result.angle)
	anchor.position=_stance(Vector3(origin[0]/1000.0,0,origin[1]/1000.0),radians)
	anchor.rotation.y=-radians
	anchor.play_action("golf_putt")
	shot_course=Courses.get_course(field_index)
	effects.begin(result,shot_course)
	audio.begin(effects.events)

func _process(delta: float) -> void:
	if course_root==null or quitting: return
	audio.set_state(audio_focused,paused)
	if game.phase=="moving":
		# Online simulation must keep progressing when a window loses focus.
		if not paused or game.online:
			elapsed+=delta
			anchor.seek_stroke(elapsed)
			var rolling_time := maxf(0,elapsed-Stroke.CONTACT)
			if elapsed>=Stroke.CONTACT: hud.set_status("Rolling…")
			effects.seek(rolling_time)
			var sample_time: float = rolling_time*shot.hz
			var frame := mini(int(sample_time),shot.path.size()-1)
			var next_frame := mini(frame+1,shot.path.size()-1)
			var blend := clampf(sample_time-frame,0,1)
			var p: Array = shot.path[frame]
			var q: Array = shot.path[next_frame]
			if elapsed>=Stroke.CONTACT:
				var speed: float = Vector2(q[0]-p[0],q[1]-p[1]).length()*shot.hz/1000.0
				audio.seek(rolling_time,speed,effects.sandy(effects.point(shot,frame),shot_course))
			var ball: Node3D = balls[shot.player]
			ball.position=Vector3(lerpf(p[0],q[0],blend)/1000.0,lerpf(shot.heights[frame],shot.heights[next_frame],blend)/1000.0,lerpf(p[1],q[1],blend)/1000.0)
			_align_marker(ball)
			var visual: Node3D = ball.get_node("RollingBall")
			# Integrate every crossed segment, not just the render-frame displacement:
			# banks still rotate correctly when the display skips simulation samples.
			for index in range(maxi(last_frame+1,1),frame+1):
				var previous: Array = shot.path[index-1]
				var current: Array = shot.path[index]
				var movement := Vector3(current[0]-previous[0],shot.heights[index]-shot.heights[index-1],current[1]-previous[1])/1000.0
				if movement.length_squared()>0:
					var normal := GreenSurface.normal(green_grid,current[0],current[1])
					var axis := normal.cross(movement)
					if axis.length_squared()>0.000001: visual.rotate(axis.normalized(),movement.length()/Size.BALL)
			ball.get_child(1).visible=shot.capture_frame<0 or frame<shot.capture_frame
			if frame!=last_frame:
				last_frame=frame
			if shot.sunk and frame==shot.path.size()-1:
				var reaction_time: float = rolling_time-(shot.path.size()-1)/float(shot.hz)
				anchor.celebrate(reaction_time,(field_index+shot.strokes[shot.player]+game.round_id)%3)
			if rolling_time>=(shot.path.size()-1)/float(shot.hz):
				hud.set_status("In the cup!" if shot.sunk else "8 strokes · moving on" if shot.capped else "Nice and steady.")
			if rolling_time>(shot.path.size()-1)/float(shot.hz)+(2.8 if shot.sunk else 0.85):
				ball.get_child(1).visible=true; game.finish_shot()
	if game.phase!="moving" and (not paused or game.online): effects.seek(effects.clock+delta)
	if not paused and audio_focused: game.tick_bot(delta)
	_poll_stick(delta)
	_poll_camera_keys(delta)
	if game.phase=="aim" and not paused: anchor.step_turn(delta)
	var rolling: bool = game.phase=="moving" and not shot.is_empty()
	var player: int = shot.player if rolling else game.world.turn
	var ball_pos: Vector3 = balls[mini(player,balls.size()-1)].position
	# Follow the cup at ground level while the ball drops below the green.
	ball_pos.y=maxf(ball_pos.y,_ground(ball_pos)+Size.BALL)
	var shot_angle: float = shot.angle if rolling else game.angle
	var golfer := _stance(ball_pos,deg_to_rad(shot_angle))
	hud.set_distance(Vector2(ball_pos.x-cup.position.x,ball_pos.z-cup.position.z).length(),cup.position.y-_ground(ball_pos))
	# Pause freezes the local camera too. Online ball presentation may continue.
	if not paused:
		if rolling and is_instance_valid(anchor.motion) and anchor.motion.celebration>=0:
			camera.celebration_frame(delta,anchor.global_position,anchor.global_basis)
		else: camera.frame(delta,ball_pos,golfer,deg_to_rad(shot_angle),rolling,game.phase in ["aim","moving","waiting_turn"],avatar_binding.eye_height())

func _poll_stick(delta: float) -> void:
	var direction := Vector2.ZERO
	var aim_axis := Vector2.ZERO
	var look := Vector2.ZERO
	var magnification := 0.0
	var camera_held := false
	for device in Input.get_connected_joypads():
		var right := Vector2(Input.get_joy_axis(device,JOY_AXIS_RIGHT_X),Input.get_joy_axis(device,JOY_AXIS_RIGHT_Y))
		if right.length()>0.20: look=right.limit_length() * (minf(right.length(),1.0)-0.20)/0.80
		var trigger_right := Input.get_joy_axis(device,JOY_AXIS_TRIGGER_RIGHT)
		var trigger_left := Input.get_joy_axis(device,JOY_AXIS_TRIGGER_LEFT)
		camera_held=camera_held or right.length()>0.20 or trigger_right>0.10 or trigger_left>0.10
		var trigger: float = trigger_right-trigger_left
		if absf(trigger)>0.10: magnification=trigger
		var axis := Vector2(Input.get_joy_axis(device,JOY_AXIS_LEFT_X),Input.get_joy_axis(device,JOY_AXIS_LEFT_Y))
		if axis.length_squared()>aim_axis.length_squared(): aim_axis=axis
		if popup.visible and axis.length()>0.55: direction=Vector2(signf(axis.x),0) if absf(axis.x)>absf(axis.y) else Vector2(0,signf(axis.y))
		if Input.is_joy_button_pressed(device,JOY_BUTTON_DPAD_LEFT): direction=Vector2.LEFT
		elif Input.is_joy_button_pressed(device,JOY_BUTTON_DPAD_RIGHT): direction=Vector2.RIGHT
		elif Input.is_joy_button_pressed(device,JOY_BUTTON_DPAD_UP): direction=Vector2.UP
		elif Input.is_joy_button_pressed(device,JOY_BUTTON_DPAD_DOWN): direction=Vector2.DOWN
	if neutral_required:
		if direction==Vector2.ZERO and AimInput.response(aim_axis)==Vector2.ZERO and not camera_held and not Input.is_anything_pressed(): neutral_required=false
		return
	if direction!=Vector2.ZERO or AimInput.response(aim_axis)!=Vector2.ZERO or camera_held: _set_input("pad")
	_camera_axes(look,magnification,delta)
	_aim_stick(aim_axis,delta)
	if direction==Vector2.ZERO: repeat_time=0; last_axis=direction; return
	repeat_time-=delta
	if direction!=last_axis or repeat_time<=0:
		_direction(int(direction.x),int(direction.y)); repeat_time=0.3 if direction!=last_axis else 0.12
	last_axis=direction

func _aim_stick(axis: Vector2, delta: float) -> void:
	if paused or popup.visible or neutral_required or not game.can_fire(): return
	var rate := AimInput.response(axis)
	if rate==Vector2.ZERO: return
	# Limit a stalled frame's jump; ordinary 30/60/120 FPS have identical rates.
	var elapsed := clampf(delta,0.0,0.1)
	game.adjust_continuous(rate.x*AimInput.AIM_SPEED*elapsed,-rate.y*AimInput.POWER_SPEED*elapsed)

func _direction(x: int, y: int) -> void:
	if popup.visible:
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Slider and x!=0:
			focused.value+=x*focused.step
			return
		var list := _popup_controls()
		if not list.is_empty(): list[posmod(list.find(focused)+(1 if y>0 or x>0 else -1),list.size())].grab_focus()
	elif not paused: game.adjust(x,-y)
	_refresh()

func _primary() -> void:
	if popup.visible:
		var focus := get_viewport().gui_get_focus_owner()
		if graphics_open and focus==contrast_slider:
			contrast_slider.value=100; return
		var list := _popup_controls()
		if focus not in list and not list.is_empty(): focus=list[0]
		if focus is Button and not focus.disabled: focus.pressed.emit()
	elif not paused: game.fire()

func _pause() -> void:
	if boards_open: boards_open=false; _refresh(); return
	if audio_open: _close_audio(); return
	if graphics_open: _close_graphics(); return
	if local_setup: local_setup=false; _refresh(); return
	if game.phase=="menu": return
	paused=!paused; _refresh()

func _suspend_input() -> void:
	neutral_required=true
	touches.clear(); hud.cancel_pointers()
	if game.phase!="menu": paused=true; _refresh()

func _set_input(kind: String) -> void:
	if input_kind==kind and touch_mode==(kind=="touch"): return
	input_kind=kind; touch_mode=kind=="touch"; _refresh()

func _input(event: InputEvent) -> void:
	if quitting: return
	if event is InputEventScreenTouch and event.pressed: _set_input("touch")
	elif event is InputEventMouseButton and event.pressed and event.device!=InputEvent.DEVICE_ID_EMULATION: _set_input("mouse")
	if hud.route_pointer(event):
		get_viewport().set_input_as_handled(); return
	if event is InputEventKey and event.pressed:
		_set_input("keyboard")
		match event.keycode:
			KEY_LEFT: _direction(-1,0)
			KEY_RIGHT: _direction(1,0)
			KEY_UP: _direction(0,-1)
			KEY_DOWN: _direction(0,1)
			KEY_ENTER,KEY_SPACE: if not event.echo: _primary()
			KEY_ESCAPE: if not event.echo: _pause()
			KEY_TAB: if not event.echo: _cycle_view()
			KEY_R: if not event.echo and _camera_allowed(): camera.reset_view()
			KEY_W,KEY_A,KEY_S,KEY_D,KEY_Q,KEY_E: _refresh()
			_: return
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		_set_input("pad")
		if neutral_required: return
		match event.button_index:
			JOY_BUTTON_DPAD_LEFT: _direction(-1,0); last_axis=Vector2.LEFT; repeat_time=0.3
			JOY_BUTTON_DPAD_RIGHT: _direction(1,0); last_axis=Vector2.RIGHT; repeat_time=0.3
			JOY_BUTTON_DPAD_UP: _direction(0,-1); last_axis=Vector2.UP; repeat_time=0.3
			JOY_BUTTON_DPAD_DOWN: _direction(0,1); last_axis=Vector2.DOWN; repeat_time=0.3
			JOY_BUTTON_A: _primary()
			JOY_BUTTON_B,JOY_BUTTON_START: _pause()
			JOY_BUTTON_X: _cycle_view()
			JOY_BUTTON_RIGHT_STICK: if _camera_allowed(): camera.reset_view()
			_: return
		_refresh(); get_viewport().set_input_as_handled()
	if event is InputEventScreenTouch and not event.pressed: touches.erase(event.index)

func _camera_allowed() -> bool:
	return not paused and game.phase in ["aim","moving","waiting_turn"]

func _cycle_view() -> void:
	if not _camera_allowed(): return
	camera.cycle(); _refresh()

func _camera_axes(look: Vector2, magnification: float, delta: float) -> void:
	if not _camera_allowed() or neutral_required: return
	if look.length_squared()>0 or magnification!=0:
		camera.rotate_view(look*delta*1.8)
		camera.magnify(magnification*delta)

func _poll_camera_keys(delta: float) -> void:
	var look := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	var magnification := float(Input.is_physical_key_pressed(KEY_E))-float(Input.is_physical_key_pressed(KEY_Q))
	if look!=Vector2.ZERO or magnification!=0: _set_input("keyboard")
	_camera_axes(look,magnification,delta)

func _unhandled_input(event: InputEvent) -> void:
	if not _camera_allowed() or neutral_required: return
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		camera.rotate_view(event.relative*0.006)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: camera.magnify(0.12)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: camera.magnify(-0.12)
		else: return
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed:
		# HUD and modal controls consume their own touches before this handler.
		touches[event.index]=event.position
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and touches.has(event.index):
		if touches.size()==1: camera.rotate_view(event.relative*0.006)
		elif touches.size()==2:
			var other: int = touches.keys()[0] if touches.keys()[1]==event.index else touches.keys()[1]
			var before: float = touches[event.index].distance_to(touches[other])
			var after: float = event.position.distance_to(touches[other])
			if before>20 and after>20: camera.magnify(log(after/before))
		touches[event.index]=event.position
		get_viewport().set_input_as_handled()

func _actor_name(actor: int) -> String:
	if game.solo_bot and actor==1: return "RIVAL"
	if actor==(game.seat if game.online else 0): return "YOU"
	return _seat_label(actor)

func _seat_label(actor: int) -> String:
	var members: Array = game.bridge.session.get("members",[])
	return "P%d"%int(members[actor].seat if game.online and actor<members.size() else actor+1)

func _default_teams() -> void:
	var roster: Array = Match.Rules.default_roster(setup_count)
	if setup_teams and setup_count==4: roster=[[0,1],[2,3]]
	setup_assignment.resize(setup_count)
	for i in roster.size():
		for member in roster[i]: setup_assignment[member]=i

func _setup_roster() -> Array:
	if not setup_teams: return Match.Rules.default_roster(setup_count)
	var roster: Array = []
	for team in 4:
		var seats: Array = []
		for i in setup_count:
			if setup_assignment[i]==team: seats.append(i)
		if not seats.is_empty(): roster.append(seats)
	return roster

func _cycle_count() -> void:
	var counts := [2,4,5,6,7,8]
	setup_count=counts[(counts.find(setup_count)+1)%counts.size()]
	setup_teams=setup_count>4 or setup_teams and setup_count==4
	_default_teams(); _refresh()

func _toggle_teams() -> void:
	if setup_count==4: setup_teams=not setup_teams; _default_teams(); _refresh()

func _cycle_team(member: int) -> void:
	if not setup_teams or member>=setup_count: return
	setup_assignment[member]=(setup_assignment[member]+1)%mini(4,setup_count/2)
	_refresh()

func _refresh_setup() -> void:
	var valid: bool = Match.Rules.valid_roster(_setup_roster(),setup_count)
	popup_text.text="One ball per team \u00b7 take turns within your team.\nTap a player to change teams." if setup_teams else "Everyone plays their own ball.\nFewest strokes wins."
	if not valid: popup_text.text="Each team needs 2 or 3 players.\nUnequal teams are welcome: 2 versus 3."
	setup_count_button.text="Players: %d"%setup_count
	setup_mode_button.text="Teams" if setup_teams else "Individual"
	setup_mode_button.disabled=setup_count!=4
	for i in 8:
		var control: Button = setup_grid.get_child(i)
		control.visible=i<setup_count
		if i<setup_count:
			control.text="%s · %s"%[_seat_label(i),SIDE_NAMES[setup_assignment[i]]]
			control.disabled=not setup_teams
	setup_start_button.disabled=not valid
	var controls := _popup_controls()
	if not controls.is_empty() and get_viewport().gui_get_focus_owner() not in controls: controls[0].grab_focus()

func _start_configured() -> void:
	var roster := _setup_roster()
	if not Match.Rules.valid_roster(roster,setup_count): return
	local_setup=false; field_index=-1; paused=false
	if game.online: game.start_group(roster)
	else: game.local(setup_count,roster)
