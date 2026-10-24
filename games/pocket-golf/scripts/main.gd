# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
const Match = preload("res://scripts/match.gd")
const Courses = preload("res://scripts/courses.gd")
const AvatarAnchor = preload("res://scripts/avatar_anchor.gd")
const AvatarBinding = preload("res://scripts/avatar_binding.gd")
const AvatarExchange = preload("res://addons/traineros/avatar_exchange.gd")
const Stroke = preload("res://scripts/golf_stroke.gd")
const Size = preload("res://scripts/dimensions.gd")
const GolfCamera = preload("res://scripts/golf_camera.gd")
const Island = preload("res://scripts/island.gd")
const GolfHud = preload("res://scripts/golf_hud.gd")
const Surfaces = preload("res://scripts/surfaces.gd")
const GreenSurface = preload("res://scripts/green_surface.gd")
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
var avatar_exchange = AvatarExchange.new()
var aim_root: Node3D
var cup: Node3D
var field_index := -1
var shot: Dictionary = {}
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
var ball_materials: Array = []
var capture_dir := ""

func _ready() -> void:
	if OS.get_environment("TRAINEROS_CRATES_GAME")=="1": get_window().mode=Window.MODE_FULLSCREEN
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sdk-endpoint="): game.bridge.endpoint_override=arg.trim_prefix("--sdk-endpoint=")
	_setup_scene()
	_setup_ui()
	add_child(game)
	game.changed.connect(_refresh)
	game.shot_started.connect(_shot_started)
	add_child(avatar_binding)
	avatar_binding.start(anchor,_placeholder,game.bridge.endpoint_override)
	add_child(avatar_exchange)
	avatar_exchange.start(avatar_binding.client,game.bridge)
	avatar_exchange.can_resolve=func(): return game.phase!="moving"
	avatar_exchange.peer_changed.connect(avatar_binding.receive_peer)
	avatar_exchange.peer_unavailable.connect(avatar_binding.clear_peer)
	game.bridge.identity_revoked.connect(avatar_binding.disconnect_identity)
	Input.joy_connection_changed.connect(func(_device, connected):
		neutral_required=true
		if not connected: _suspend_input()
		_set_input("pad" if connected else "keyboard"))
	get_window().focus_exited.connect(_suspend_input)
	_refresh()
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
		cylinder(ball,0.065,0.002,Vector3(0,-Size.BALL,0),MINT if i==0 else CORAL)
		balls.append(ball)
	aim_root=Node3D.new(); course_root.add_child(aim_root)
	for i in 8: sphere(aim_root,0.012,Vector3(0,0.02,-0.15-i*0.15),Color("fff4d4"))

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
	hud.aim_dragged.connect(func(steps): game.adjust(steps,0))
	hud.power_selected.connect(func(percent): game.adjust(0,roundi((percent-game.power)/5.0)))
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
	var node := Button.new(); node.text=text; node.custom_minimum_size.y=46; parent.add_child(node); node.pressed.connect(action); return node

func _refresh() -> void:
	if not game.online and not avatar_exchange.peer_member.is_empty(): avatar_exchange.clear_peer()
	var avatar_seat: int = shot.player if game.phase=="moving" and not shot.is_empty() else game.world.turn
	avatar_binding.select(avatar_seat==(game.seat if game.online else 0),game.phase!="moving")
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
	var player := "Mint" if game.world.turn==0 else "Coral"
	var confirm := "A"; var back := "B"; var view := "X"
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		var name := Input.get_joy_name(pads[0]).to_lower()
		if "playstation" in name or "dual" in name or "ps5" in name: confirm="×"; back="○"; view="□"
		elif "nintendo" in name or "switch" in name: confirm="B"; back="A"; view="Y"
	hud.update_state({"hole":field_index+1,"title":c.title,"par":c.par,
		"players":game.world.players,"player":shot.player if game.phase=="moving" and not shot.is_empty() else game.world.turn,
		"strokes":counts,"totals":totals,
		"power":game.power,"angle":game.angle,"phase":game.phase,"paused":paused,
		"online":game.online,"seat":game.seat,"can_shoot":game.can_fire() and not paused,
		"mode":"touch" if touch_mode else input_kind,"confirm":confirm,"back":back,"view_key":view,
		"view":GolfCamera.TITLES[camera.view]})
	if game.phase!="moving": hud.set_status("")
	anchor.visible=(game.can_fire() or game.phase=="moving") and not paused
	if camera.view==GolfCamera.View.EYES and game.phase!="moving": anchor.visible=false
	aim_root.visible=game.can_fire() and not paused
	if game.can_fire():
		var ball: Vector3 = balls[game.world.turn].position
		var radians := deg_to_rad(game.angle)
		for i in aim_root.get_child_count():
			var point := ball+Vector3(sin(radians),0,-cos(radians))*(0.15+i*0.15)
			point.y=_ground(point)+0.012
			aim_root.get_child(i).position=point
		anchor.position=_stance(ball,radians)
		anchor.rotation.y=-radians
	var state: String = "paused" if paused else game.phase
	popup.visible=state in ["menu","waiting","handoff","result","paused"]
	modal_shade.visible=popup.visible
	if popup.visible: touches.clear(); hud.cancel_pointers()
	if popup.visible and state!=last_popup:
		last_popup=state
		for child in popup_buttons.get_children(): popup_buttons.remove_child(child); child.queue_free()
		if state=="menu":
			popup_title.text="Pocket Golf"; popup_text.text="Three little greens. Take your time.\nFewest strokes wins."
			button(popup_buttons,"Solo round",func(): _start_local(1))
			button(popup_buttons,"Two players · pass the pad",func(): _start_local(2))
			button(popup_buttons,"Exit",func(): get_tree().quit())
		elif state=="handoff":
			popup_title.text=player+" to putt"; popup_text.text="Hole %d / 3 · Par %d\n%s" % [game.world.hole+1,c.par,"Pass the controller, then confirm." if game.world.players==2 else "Aim with left/right. Power with up/down."]
			button(popup_buttons,"Ready",func(): game.accept_turn())
		elif state=="waiting":
			popup_title.text="Connecting match"; popup_text.text=game.info
			button(popup_buttons,"Back",func(): game.leave())
		elif state=="result":
			popup_title.text="Round complete"
			popup_text.text="Mint: %s = %d strokes" % [" · ".join(game.world.scores[0].map(func(n): return str(n))),game.world.total(0)]
			if game.world.players==2:
				popup_text.text+="\nCoral: %s = %d strokes\n%s" % [" · ".join(game.world.scores[1].map(func(n): return str(n))),game.world.total(1),"A draw!" if game.world.total(0)==game.world.total(1) else "Mint wins!" if game.world.total(0)<game.world.total(1) else "Coral wins!"]
			button(popup_buttons,"Play again",func(): game.rematch())
			button(popup_buttons,"Main menu",func(): game.leave())
		elif state=="paused":
			popup_title.text="Take a breather"
			button(popup_buttons,"Keep playing",func(): paused=false; _refresh())
			button(popup_buttons,"Leave round",func(): paused=false; game.leave())
			button(popup_buttons,"Reset camera",func(): camera.reset_view(); paused=false; _refresh())
		if popup_buttons.get_child_count()>0: popup_buttons.get_child(0).grab_focus()
	elif not popup.visible: last_popup=""
	if state=="paused":
		popup_text.text="Left stick: aim / power · Right stick: look\nTriggers: zoom · %s: view · R3: reset"%view if input_kind=="pad" else "Drag the green: look · Pinch: zoom\nDrag aim / power · Tap PUTT to strike" if touch_mode else "Arrows: aim / power · Enter: putt\nWASD: look · Q/E: zoom · Tab: view · R: reset"
	if game.phase=="waiting" and not paused: popup_text.text=game.info
	if game.phase=="menu" and game.info!="A little green. A good time.": popup_text.text=game.info
	if game.phase=="result" and game.voted:
		popup_text.text="Rematch requested. Waiting for your friend…"
		popup_buttons.get_child(0).disabled=true

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
	effects.begin(result,Courses.get_course(field_index))

func _process(delta: float) -> void:
	if course_root==null: return
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
				if frame==shot.path.size()-1 and shot.sunk:
					anchor.play_action("celebrate")
				last_frame=frame
			if rolling_time>=(shot.path.size()-1)/float(shot.hz):
				hud.set_status("In the cup!" if shot.sunk else "8 strokes · moving on" if shot.capped else "Nice and steady.")
			if rolling_time>(shot.path.size()-1)/float(shot.hz)+0.85:
				ball.get_child(1).visible=true; game.finish_shot()
	if game.phase!="moving" and (not paused or game.online): effects.seek(effects.clock+delta)
	_poll_stick(delta)
	_poll_camera_keys(delta)
	var rolling: bool = game.phase=="moving" and not shot.is_empty()
	var player: int = shot.player if rolling else game.world.turn
	var ball_pos: Vector3 = balls[mini(player,balls.size()-1)].position
	# Follow the cup at ground level while the ball drops below the green.
	ball_pos.y=maxf(ball_pos.y,_ground(ball_pos)+Size.BALL)
	var shot_angle: float = shot.angle if rolling else game.angle
	var golfer := _stance(ball_pos,deg_to_rad(shot_angle))
	hud.set_distance(Vector2(ball_pos.x-cup.position.x,ball_pos.z-cup.position.z).length(),cup.position.y-_ground(ball_pos))
	# Pause freezes the local camera too. Online ball presentation may continue.
	if not paused: camera.frame(delta,ball_pos,golfer,deg_to_rad(shot_angle),rolling,game.phase in ["aim","moving"],avatar_binding.eye_height())

func _poll_stick(delta: float) -> void:
	var direction := Vector2.ZERO
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
		if axis.length()>0.55: direction=Vector2(signf(axis.x),0) if absf(axis.x)>absf(axis.y) else Vector2(0,signf(axis.y))
		if Input.is_joy_button_pressed(device,JOY_BUTTON_DPAD_LEFT): direction=Vector2.LEFT
		elif Input.is_joy_button_pressed(device,JOY_BUTTON_DPAD_RIGHT): direction=Vector2.RIGHT
		elif Input.is_joy_button_pressed(device,JOY_BUTTON_DPAD_UP): direction=Vector2.UP
		elif Input.is_joy_button_pressed(device,JOY_BUTTON_DPAD_DOWN): direction=Vector2.DOWN
	if neutral_required:
		if direction==Vector2.ZERO and not camera_held and not Input.is_anything_pressed(): neutral_required=false
		return
	if direction!=Vector2.ZERO or camera_held: _set_input("pad")
	_camera_axes(look,magnification,delta)
	if direction==Vector2.ZERO: repeat_time=0; last_axis=direction; return
	repeat_time-=delta
	if direction!=last_axis or repeat_time<=0:
		_direction(int(direction.x),int(direction.y)); repeat_time=0.3 if direction!=last_axis else 0.12
	last_axis=direction

func _direction(x: int, y: int) -> void:
	if popup.visible:
		var focused := get_viewport().gui_get_focus_owner()
		var list := popup_buttons.get_children()
		if not list.is_empty(): list[posmod(list.find(focused)+(1 if y>0 or x>0 else -1),list.size())].grab_focus()
	elif not paused: game.adjust(x,-y)
	_refresh()

func _primary() -> void:
	if popup.visible:
		var focus := get_viewport().gui_get_focus_owner()
		if focus not in popup_buttons.get_children() and popup_buttons.get_child_count()>0: focus=popup_buttons.get_child(0)
		if focus is Button and not focus.disabled: focus.pressed.emit()
	elif not paused: game.fire()

func _pause() -> void:
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
	return not paused and game.phase in ["aim","moving"]

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
