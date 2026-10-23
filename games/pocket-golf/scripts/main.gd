# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
const Match = preload("res://scripts/match.gd")
const Courses = preload("res://scripts/courses.gd")
const AvatarAnchor = preload("res://scripts/avatar_anchor.gd")
const MINT := Color("579e88")
const CORAL := Color("dd9579")
var game = Match.new()
var course_root: Node3D
var camera: Camera3D
var balls: Array[Node3D] = []
var anchor = AvatarAnchor.new()
var aim_root: Node3D
var cup: Node3D
var field_index := -1
var shot: Dictionary = {}
var elapsed := 0.0
var last_frame := -1
var effects: Array = []
var orbit := false
var paused := false
var touch_mode := false
var repeat_time := 0.0
var last_axis := Vector2.ZERO
var neutral_required := false
var root_ui: Control
var header: Label
var score: Label
var hint: Label
var values: Label
var popup: PanelContainer
var popup_title: Label
var popup_text: Label
var popup_buttons: VBoxContainer
var touch_row: HBoxContainer
var touch_button: Button
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
	game.bridge.closed.connect(func(): anchor.clear_identity())
	Input.joy_connection_changed.connect(func(_device, connected):
		neutral_required=true
		if not connected: _suspend_input())
	get_window().focus_exited.connect(_suspend_input)
	_refresh()

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

func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size=size
	return mesh(parent,shape,pos,color)

func sphere(parent: Node3D, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius=radius; shape.height=radius*2; shape.radial_segments=20; shape.rings=12
	return mesh(parent,shape,pos,color)

func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius=radius; shape.bottom_radius=radius; shape.height=height; shape.radial_segments=32
	return mesh(parent,shape,pos,color)

func _setup_scene() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("c5dcdb")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("e3eee0")
	env.ambient_light_energy=0.4
	env.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	environment.environment=env
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-55,-30,0)
	light.light_color=Color("fff2d7")
	light.light_energy=0.65
	light.shadow_enabled=true
	add_child(light)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=22
	camera.position=Vector3(12,20,17)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current=true
	box(self,Vector3(200,0.5,200),Vector3(0,-1.4,0),Color("b7d0c7"))
	add_child(anchor)
	# Abstract marker until the SDK avatar presenter is delivered; no clothing data.
	_placeholder()

func _placeholder() -> void:
	var marker := Node3D.new()
	cylinder(marker,0.28,0.85,Vector3(0,0.45,0),Color("e8c386"))
	sphere(marker,0.29,Vector3(0,1.05,0),Color("f7e8c9"))
	box(marker,Vector3(0.07,0.85,0.07),Vector3(0.45,0.45,0),Color("4b615a"))
	box(marker,Vector3(0.12,0.12,0.4),Vector3(0.45,0.06,0),Color("4b615a"))
	anchor.install_visual(marker,"")

func _build_course() -> void:
	if course_root!=null:
		remove_child(course_root); course_root.queue_free()
	course_root=Node3D.new(); add_child(course_root)
	field_index=game.world.hole
	var c := Courses.get_course(field_index)
	box(course_root,Vector3(11.4,0.7,17.4),Vector3(0,-0.55,0),Color("b8a487"))
	box(course_root,Vector3(10.6,0.25,16.6),Vector3(0,-0.15,0),Color("e9dbc1"))
	# Alternating mown strips and quiet edge markings make distances visible.
	for z in 16:
		box(course_root,Vector3(10,0.06,1),Vector3(0,-0.04,z-7.5),Color("79ad87") if z%2==0 else Color("80b58c"))
	for x in [-5.12,5.12]: box(course_root,Vector3(0.24,0.4,16.5),Vector3(x,0.13,0),Color("f4e6ce"))
	for z in [-8.12,8.12]: box(course_root,Vector3(10.5,0.4,0.24),Vector3(0,0.13,z),Color("f4e6ce"))
	for wall in c.walls:
		box(course_root,Vector3((wall[2]-wall[0])/1000.0,0.6,(wall[3]-wall[1])/1000.0),Vector3((wall[0]+wall[2])/2000.0,0.3,(wall[1]+wall[3])/2000.0),Color("9baaa2"))
	for sand in c.sand:
		box(course_root,Vector3((sand[2]-sand[0])/1000.0,0.025,(sand[3]-sand[1])/1000.0),Vector3((sand[0]+sand[2])/2000.0,0.008,(sand[1]+sand[3])/2000.0),Color("e5cd96"))
	cup=Node3D.new(); cup.position=Vector3(c.cup[0]/1000.0,0,c.cup[1]/1000.0); course_root.add_child(cup)
	cylinder(cup,0.43,0.02,Vector3(0,0.035,0),Color("f1e4c4"))
	cylinder(cup,0.33,0.025,Vector3(0,0.05,0),Color("284e43"))
	cylinder(cup,0.035,2,Vector3(0,1,0),Color("fff0d3"))
	box(cup,Vector3(0.7,0.4,0.04),Vector3(0.35,1.8,0),CORAL)
	for i in 9:
		var x := (-1 if i%2==0 else 1)*(6.7+(i%3)*0.7)
		var z := -8.0+i*2.1
		cylinder(course_root,0.14,0.9,Vector3(x,-0.5,z),Color("99896d"))
		sphere(course_root,0.85+(i%3)*0.12,Vector3(x,0.35,z),Color("8eb99b") if i%2==0 else Color("a5c18b"))
		cylinder(course_root,0.8,0.12,Vector3(x,-1.07,z),Color("a7c3ad"))
	balls.clear()
	for i in game.world.players:
		var ball := Node3D.new(); course_root.add_child(ball)
		sphere(ball,0.18,Vector3.ZERO,Color("fff8e7") if i==0 else CORAL)
		# A floor ring distinguishes the two overlapping tee positions without moving rules.
		cylinder(ball,0.24,0.015,Vector3(0,-0.165,0),MINT if i==0 else CORAL)
		balls.append(ball)
	aim_root=Node3D.new(); course_root.add_child(aim_root)
	for i in 8: sphere(aim_root,0.055,Vector3(0,0.14,-0.45-i*0.22),Color("fff4d4"))

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
	var top := Panel.new(); top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE); top.offset_bottom=72; root_ui.add_child(top)
	var bg := StyleBoxFlat.new(); bg.bg_color=Color("f7f2e6"); top.add_theme_stylebox_override("panel",bg)
	header=label(top,"POCKET GOLF",Vector2(20,10),24)
	score=label(top,"",Vector2(20,41),18)
	var menu := button(top,"Menu",_pause); menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT); menu.offset_left=-112; menu.offset_right=-16; menu.offset_top=13; menu.offset_bottom=59
	touch_button=button(top,"Touch",func(): touch_mode=!touch_mode; _refresh()); touch_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT); touch_button.offset_left=-224; touch_button.offset_right=-122; touch_button.offset_top=13; touch_button.offset_bottom=59
	var bottom := Panel.new(); bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); bottom.offset_top=-78; root_ui.add_child(bottom); bottom.add_theme_stylebox_override("panel",bg)
	values=label(bottom,"",Vector2(20,7),23)
	hint=label(bottom,"",Vector2(20,43),17)
	touch_row=HBoxContainer.new(); bottom.add_child(touch_row); touch_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT); touch_row.offset_left=-396; touch_row.offset_right=-16; touch_row.offset_top=13; touch_row.offset_bottom=59; touch_row.add_theme_constant_override("separation",8)
	button(touch_row,"←",func(): game.adjust(-1,0)); button(touch_row,"→",func(): game.adjust(1,0)); button(touch_row,"−",func(): game.adjust(0,-1)); button(touch_row,"+",func(): game.adjust(0,1)); button(touch_row,"Putt",_primary)
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
	if anchor.visual==null: _placeholder()
	if game.phase=="menu": paused=false
	if field_index<0 or (game.phase!="moving" and (field_index!=game.world.hole or balls.size()!=game.world.players)): _build_course()
	if game.phase!="moving":
		for i in balls.size():
			if i>=game.world.balls.size(): continue
			var p: Array = game.world.balls[i]
			balls[i].position=Vector3(p[0]/1000.0,0.19,p[1]/1000.0)
			balls[i].visible=not game.world.finished[i]
			if i!=game.world.turn and p==game.world.balls[game.world.turn]: balls[i].visible=false
	var c := Courses.get_course(field_index)
	header.text="POCKET GOLF   /   %02d  %s" % [field_index+1,c.title]
	var counts: Array = shot.strokes if game.phase=="moving" and not shot.is_empty() else game.world.strokes
	score.text="PAR %d     MINT %d" % [c.par, counts[0]]
	if game.world.players==2: score.text+="    CORAL %d" % counts[1]
	if game.online: score.text+="     YOU: "+("MINT" if game.seat==0 else "CORAL")
	var player := "Mint" if game.world.turn==0 else "Coral"
	values.text="%s   ·   Angle %d°   Power %d%%" % [player,game.angle,game.power]
	if game.phase=="moving": values.text="In the cup!" if shot.get("sunk",false) and elapsed>shot.path.size()/60.0 else "Rolling…"
	elif game.online and not game.can_fire() and game.phase=="aim": values.text="Your friend is lining up a putt…"
	var pads := Input.get_connected_joypads()
	var confirm := "A"; var back := "B"; var view := "X"
	if not pads.is_empty():
		var name := Input.get_joy_name(pads[0]).to_lower()
		if "playstation" in name or "dual" in name or "ps5" in name: confirm="×"; back="○"; view="□"
		elif "nintendo" in name or "switch" in name: confirm="B"; back="A"; view="Y"
	hint.text="Stick / D-pad: aim & power    %s: putt    %s: view    %s / Start: menu" % [confirm,view,back] if not pads.is_empty() else "← → Aim    ↑ ↓ Power    Enter: putt    Tab: view    Esc: menu"
	touch_row.visible=touch_mode and game.can_fire() and not paused
	touch_button.text="Hide" if touch_mode else "Touch"
	if touch_row.visible: values.text="Angle %d°   Power %d%%" % [game.angle,game.power]; hint.text="Aim, choose your power, then putt."
	anchor.visible=(game.can_fire() or game.phase=="moving") and not paused
	aim_root.visible=game.can_fire() and not paused
	if game.can_fire():
		var ball: Vector3 = balls[game.world.turn].position
		var radians := deg_to_rad(game.angle)
		aim_root.position=ball-Vector3(0,0.15,0); aim_root.rotation.y=-radians
		anchor.position=ball+Vector3(-cos(radians)*0.85, -0.19,-sin(radians)*0.85)
		anchor.rotation.y=-radians
	var state: String = "paused" if paused else game.phase
	popup.visible=state in ["menu","waiting","handoff","result","paused"]
	if popup.visible and state!=last_popup:
		last_popup=state
		for child in popup_buttons.get_children(): popup_buttons.remove_child(child); child.queue_free()
		if state=="menu":
			popup_title.text="Pocket Golf"; popup_text.text="Three little greens. Take your time.\nFewest strokes wins."
			button(popup_buttons,"Solo round",func(): _start_local(1))
			button(popup_buttons,"Two players · pass the pad",func(): _start_local(2))
			button(popup_buttons,"Play with a friend",func(): game.join())
			button(popup_buttons,"Exit",func(): get_tree().quit())
		elif state=="handoff":
			popup_title.text=player+" to putt"; popup_text.text="Hole %d / 3 · Par %d\n%s" % [game.world.hole+1,c.par,"Pass the controller, then confirm." if game.world.players==2 else "Aim with left/right. Power with up/down."]
			button(popup_buttons,"Ready",func(): game.accept_turn())
		elif state=="waiting":
			popup_title.text="Meet in Lobby"; popup_text.text=game.info
			button(popup_buttons,"Open TrainerOS Lobby",func(): game.bridge.open_lobby())
			button(popup_buttons,"Back",func(): game.leave())
		elif state=="result":
			popup_title.text="Round complete"
			popup_text.text="Mint: %s = %d strokes" % [" · ".join(game.world.scores[0].map(func(n): return str(n))),game.world.total(0)]
			if game.world.players==2:
				popup_text.text+="\nCoral: %s = %d strokes\n%s" % [" · ".join(game.world.scores[1].map(func(n): return str(n))),game.world.total(1),"A draw!" if game.world.total(0)==game.world.total(1) else "Mint wins!" if game.world.total(0)<game.world.total(1) else "Coral wins!"]
			button(popup_buttons,"Play again",func(): game.rematch())
			button(popup_buttons,"Main menu",func(): game.leave())
		elif state=="paused":
			popup_title.text="Take a breather"; popup_text.text="Return when you are ready.\nLeaving ends this round."
			button(popup_buttons,"Keep playing",func(): paused=false; _refresh())
			button(popup_buttons,"Leave round",func(): paused=false; game.leave())
		if popup_buttons.get_child_count()>0: popup_buttons.get_child(0).grab_focus()
	elif not popup.visible: last_popup=""
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
	elapsed=0
	last_frame=-1
	var origin: Array = result.path[0]
	var radians := deg_to_rad(result.angle)
	anchor.position=Vector3(origin[0]/1000.0-cos(radians)*0.85,0,origin[1]/1000.0-sin(radians)*0.85)
	anchor.rotation.y=-radians
	anchor.play_action("golf_putt")
	_burst(balls[result.player].position,Color("f8e2a6"),7)

func _burst(pos: Vector3, color: Color, count: int) -> void:
	for i in count:
		var node := sphere(self,0.06,pos,color)
		var a := i*2.39996
		effects.append({"node":node,"v":Vector3(cos(a),1.8+0.1*i,sin(a))*0.8,"age":0.0})

func _process(delta: float) -> void:
	if course_root==null: return
	var target := Vector3(-12,20,17) if orbit else Vector3(12,20,17)
	camera.position=camera.position.lerp(target,1-exp(-delta*5)); camera.look_at(Vector3.ZERO)
	if game.phase=="moving":
		# Online simulation must keep progressing when a window loses focus.
		if not paused or game.online:
			elapsed+=delta
			var frame := mini(int(elapsed*60),shot.path.size()-1)
			var p: Array = shot.path[frame]
			var ball: Node3D = balls[shot.player]
			ball.position=Vector3(p[0]/1000.0,0.19,p[1]/1000.0)
			if frame!=last_frame:
				for bounce in shot.bounces:
					if bounce>last_frame and bounce<=frame: _burst(ball.position,Color("e4dbbc"),5)
				if frame==shot.path.size()-1 and shot.sunk:
					_burst(ball.position,Color("f3cd79"),18); anchor.play_action("celebrate")
				last_frame=frame
			if elapsed>=shot.path.size()/60.0:
				if shot.sunk: ball.scale=Vector3.ONE*maxf(0,1-(elapsed-shot.path.size()/60.0)*5)
				values.text="In the cup!" if shot.sunk else "8 strokes · moving on" if shot.capped else "Nice and steady."
			if elapsed>shot.path.size()/60.0+0.85:
				ball.scale=Vector3.ONE; game.finish_shot()
	for i in range(effects.size()-1,-1,-1):
		var fx: Dictionary = effects[i]; fx.age+=delta; fx.v.y-=delta*4; fx.node.position+=fx.v*delta; fx.node.scale=Vector3.ONE*maxf(0,1-fx.age)
		if fx.age>=1: fx.node.queue_free(); effects.remove_at(i)
	_poll_stick(delta)

func _poll_stick(delta: float) -> void:
	var direction := Vector2.ZERO
	for device in Input.get_connected_joypads():
		var axis := Vector2(Input.get_joy_axis(device,JOY_AXIS_LEFT_X),Input.get_joy_axis(device,JOY_AXIS_LEFT_Y))
		if axis.length()>0.55: direction=Vector2(signf(axis.x),0) if absf(axis.x)>absf(axis.y) else Vector2(0,signf(axis.y))
		if Input.is_joy_button_pressed(device,JOY_BUTTON_DPAD_LEFT): direction=Vector2.LEFT
		elif Input.is_joy_button_pressed(device,JOY_BUTTON_DPAD_RIGHT): direction=Vector2.RIGHT
		elif Input.is_joy_button_pressed(device,JOY_BUTTON_DPAD_UP): direction=Vector2.UP
		elif Input.is_joy_button_pressed(device,JOY_BUTTON_DPAD_DOWN): direction=Vector2.DOWN
	if neutral_required:
		if direction==Vector2.ZERO and not Input.is_anything_pressed(): neutral_required=false
		return
	if direction==Vector2.ZERO: repeat_time=0; last_axis=direction; return
	repeat_time-=delta
	if direction!=last_axis or repeat_time<=0:
		_direction(int(direction.x),int(direction.y)); repeat_time=0.3 if direction!=last_axis else 0.12
	last_axis=direction

func _direction(x: int, y: int) -> void:
	touch_mode=false
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
	if game.phase!="menu": paused=true; _refresh()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed: touch_mode=true; _refresh()
	if event is InputEventKey and event.pressed:
		touch_mode=false
		match event.keycode:
			KEY_LEFT: _direction(-1,0)
			KEY_RIGHT: _direction(1,0)
			KEY_UP: _direction(0,-1)
			KEY_DOWN: _direction(0,1)
			KEY_ENTER,KEY_SPACE: if not event.echo: _primary()
			KEY_ESCAPE: if not event.echo: _pause()
			KEY_TAB: if not event.echo: orbit=!orbit
			_: return
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		touch_mode=false
		if neutral_required: return
		match event.button_index:
			JOY_BUTTON_DPAD_LEFT: _direction(-1,0); last_axis=Vector2.LEFT; repeat_time=0.3
			JOY_BUTTON_DPAD_RIGHT: _direction(1,0); last_axis=Vector2.RIGHT; repeat_time=0.3
			JOY_BUTTON_DPAD_UP: _direction(0,-1); last_axis=Vector2.UP; repeat_time=0.3
			JOY_BUTTON_DPAD_DOWN: _direction(0,1); last_axis=Vector2.DOWN; repeat_time=0.3
			JOY_BUTTON_A: _primary()
			JOY_BUTTON_B,JOY_BUTTON_START: _pause()
			JOY_BUTTON_X: orbit=!orbit
			_: return
		_refresh(); get_viewport().set_input_as_handled()
