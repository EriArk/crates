# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
const Track = preload("track.gd")
const Car = preload("car.gd")
const Effects = preload("effects.gd")
const Controls = preload("controls.gd")
const Hud = preload("hud.gd")
const Art = preload("art.gd")
const Audio = preload("audio.gd")
const Conditions = preload("stage_conditions.gd")
const Weather = preload("weather.gd")
const RaceSession = preload("race_session.gd")
const CupFlow = preload("cup_flow.gd")
var net = RaceSession.new()
var cup = CupFlow.new()
var player_index = 0
var conditions = Conditions.new()
var weather: Node3D
var track: Node3D
var cars: Array[Node3D] = []
var effects: Node3D
var camera: Camera3D
var tilt_shift: ShaderMaterial
var hud: Control
var sound: Node
var controls = Controls.new()
var pickups: Array = []
var state = "menu"
var elapsed = 0.0
var countdown = 3.0
var laps = 4
var bot_count = 15
var effect_clock = 0.0
var show_metrics = false
var demo_auto = false
var capture_path = ""
var capture_time = 0.0
var screenshot_done = false
var capture_results = false
var performance_frames: Array[float] = []
var current_wetness = 0.0
var finish_deadline = INF
var race_limit_seconds = 600.0 # Dirty Valley only; future cup stages own their limit.

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	Engine.max_fps=60
	net.game=self; add_child(net)
	cup.game=self; add_child(cup)
	get_viewport().size_changed.connect(_resolution)
	_resolution()
	var selected_conditions = conditions.descriptor()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--time="): selected_conditions.time=arg.trim_prefix("--time=")
		elif arg.begins_with("--weather="): selected_conditions.weather=arg.trim_prefix("--weather=")
		elif arg=="--nightfall": selected_conditions.timeline=[{"at":120.0,"time":"sunset","weather":"overcast"},{"at":300.0,"time":"night","weather":"rain"}]
	if not conditions.configure(selected_conditions): push_warning("Invalid stage conditions: using clear daytime")
	weather=Weather.new(); add_child(weather); weather.apply(conditions)
	track=Track.new(); add_child(track); track.build()
	track.set_wetness(conditions.wetness())
	effects=Effects.new(); effects.process_mode=Node.PROCESS_MODE_PAUSABLE; add_child(effects)
	sound=Audio.new(); add_child(sound)
	camera=Camera3D.new(); camera.fov=48; camera.near=0.15; camera.far=160; add_child(camera)
	var optics_layer = CanvasLayer.new(); optics_layer.layer=0; add_child(optics_layer)
	var optics = ColorRect.new(); optics.mouse_filter=Control.MOUSE_FILTER_IGNORE
	optics.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tilt_shift=ShaderMaterial.new(); tilt_shift.shader=preload("res://shaders/tilt_shift.gdshader")
	optics.material=tilt_shift; optics_layer.add_child(optics)
	_spawn_cars(); _spawn_pickups()
	var layer = CanvasLayer.new(); add_child(layer); hud=Hud.new(); hud.game=self; layer.add_child(hud)
	for arg in OS.get_cmdline_user_args():
		if arg=="--autodrive": demo_auto=true
		elif arg=="--metrics": show_metrics=true
		elif arg.begins_with("--capture="): capture_path=arg.trim_prefix("--capture=")
		elif arg=="--capture-results": capture_results=true
		elif arg=="--tilt-off": tilt_shift.set_shader_parameter("strength",0.0)
		elif arg.begins_with("--bots="): bot_count=clampi(int(arg.trim_prefix("--bots=")),0,15); _spawn_cars()
	if demo_auto: start_race()
	_camera(1,true)
	net.call_deferred("connect_platform")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screen=") and arg.trim_prefix("--screen=") in ["cup","garage","main"]: hud.menu(arg.trim_prefix("--screen="))

func player() -> Node3D: return cars[player_index]

func _resolution() -> void:
	# UI retains display resolution. Only the 3D viewport has a 720p pixel budget.
	var viewport = get_viewport(); var pixels = DisplayServer.window_get_size()
	viewport.scaling_3d_scale=clampf(720.0/maxf(720,pixels.y),0.35,1.0)

func set_conditions(data: Dictionary) -> bool:
	if state!="menu" or not conditions.configure(data): return false
	weather.apply(conditions); _update_conditions(0)
	return true

func _update_conditions(seconds: float) -> void:
	current_wetness=conditions.wetness(seconds)
	track.set_wetness(current_wetness); weather.set_sample(conditions.sample(seconds))
	for car in cars: car.surface_grip=1.0-current_wetness*0.2

func cycle_time() -> void:
	var data = conditions.descriptor()
	data.time=Conditions.TIMES[(Conditions.TIMES.find(data.time)+1)%Conditions.TIMES.size()]
	if data.timeline.size()==2 and data.timeline[-1].time=="night" and data.timeline[-1].weather=="rain":
		data.timeline[0].time="night" if data.time=="night" else "sunset"
	elif data.timeline.size()==1 and data.timeline[0].weather=="clear": data.timeline[0].time=data.time
	if set_conditions(data): hud.menu("conditions")

func cycle_weather() -> void:
	var data = conditions.descriptor()
	data.weather=Conditions.WEATHERS[(Conditions.WEATHERS.find(data.weather)+1)%Conditions.WEATHERS.size()]
	if set_conditions(data): hud.menu("conditions")

func cycle_scenario() -> void:
	if set_conditions(conditions.next_scenario()): hud.menu("conditions")

func _spawn_cars() -> void:
	for car in cars: remove_child(car); car.queue_free()
	cars.clear()
	for i in bot_count+1:
		var car = Car.new(); car.index=i; car.local_player=i==player_index; car.human=net.online and i<net.members.size(); car.track=track; car.surface_grip=conditions.grip()
		car.model_id=["hatchback-sports","suv","sedan-sports","race"][i%4]
		if not net.online:
			if cup.running: car.model_id=cup.Rules.model(cup.store.data.active.roster[i])
			elif i==0: car.model_id=cup.Rules.model(cup.store.data.selected)
		car.process_mode=Node.PROCESS_MODE_PAUSABLE; add_child(car); cars.append(car)
		if car.local_player and not net.online:
			for paint in car.paint_materials: paint.set_shader_parameter("paint",cup.store.color())
		var at = posmod(-4-(i/3)*3,track.COUNT); var side = Vector3(-track.tangents[at].z,0,track.tangents[at].x)
		car.checkpoint=at; car.passed=-posmod(-at,track.COUNT)
		car.position=track.points[at]+side*(float(i%3)-1)*2.8+Vector3.UP*0.72
		car.rotation.y=atan2(-track.tangents[at].x,-track.tangents[at].z); car.aim=track.tangents[at]
		car.freeze=state!="menu"

func _spawn_pickups() -> void:
	for item in pickups: item.node.queue_free()
	pickups.clear()
	for i in track.pickup_spots.size():
		var node = MeshInstance3D.new(); var mesh = BoxMesh.new(); mesh.size=Vector3(0.85,0.85,0.85); node.mesh=mesh
		node.material_override=Art.material(Color("50c9ff") if i%2 else Color("ffc44b"),0.6)
		node.position=track.pickup_spots[i]; add_child(node)
		var icon = Label3D.new(); icon.text="+" if i%2 else "III"; icon.font_size=65; icon.pixel_size=0.012; icon.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		icon.position.y=0.75; node.add_child(icon)
		pickups.append({"node":node,"cooldown":0.0,"shield":i%2==1})

func start_race() -> void:
	if net.online and not net.starting: net.rematch(); return
	if net.online: cup.running=false
	if not cup.running: laps=4
	get_tree().paused=false; state="countdown"; elapsed=0; countdown=3; capture_time=0
	finish_deadline=INF
	controls.neutral_required=true
	_spawn_cars(); _spawn_pickups(); hud.panel.hide(); hud.message=""; _camera(1,true)
	weather.apply(conditions); _update_conditions(0)

func car_title() -> String: return cup.Rules.title(cup.store.data.selected)
func cycle_car() -> void:
	var available=cup.Rules.CARS.filter(cup.store.owned)
	cup.store.select_car(available[(available.find(cup.store.data.selected)+1)%available.size()]); _spawn_cars(); hud.menu("quick")
func cycle_bots() -> void: bot_count={15:7,7:3,3:0,0:15}.get(bot_count,15); _spawn_cars(); hud.menu("quick")
func quit_game() -> void: get_tree().paused=false; get_tree().quit()

func return_menu() -> void:
	if not cup.pending_result.is_empty(): hud.menu("results"); return
	if net.online: net.leave()
	cup.running=false; laps=4
	player_index=0
	get_tree().paused=false; state="menu"; elapsed=0; _spawn_cars(); hud.menu("main")
	weather.apply(conditions); _update_conditions(0)

func resume_race() -> void:
	if net.online:
		net.overlay=false; hud.panel.hide(); controls.neutral_required=true; return
	get_tree().paused=false; state="race"; hud.panel.hide(); controls.neutral_required=true

func recover_player() -> void:
	if net.online: net.recover()
	else: _recover(player())

func network_ended(reason: String) -> void:
	return_menu(); hud.message=reason; hud.menu("disconnected")

func network_pause() -> void:
	net.overlay=not net.overlay; controls.neutral(player()); controls.neutral_required=true
	if net.overlay: hud.menu("net_pause")
	else: hud.panel.hide()

func _recover(car: Node3D) -> bool:
	if car.finish_time>=0 or car.reset_pending or car.recovery_lock>0: return false
	for back in [0,2,4,6]:
		var at: int=posmod(car.checkpoint-back,track.COUNT)
		var side = Vector3(-track.tangents[at].z,0,track.tangents[at].x)
		for lane in [0.0,-3.1,3.1]:
			var pos: Vector3=track.points[at]+side*lane+Vector3.UP*0.85
			var occupied = false
			for other in cars:
				if other==car or other.finish_time>=0: continue
				var other_pos: Vector3=other.reset_pose.origin if other.reset_pending else other.position
				if other_pos.distance_to(pos)<4.2: occupied=true; break
			if occupied: continue
			var basis = Basis(Vector3.UP,atan2(-track.tangents[at].x,-track.tangents[at].z))
			car.recovery_count+=1
			if car.position.y< -5: car.fall_count+=1
			car.checkpoint=at; car.passed-=back; car.laps=car.passed/track.COUNT
			car.reset_at(Transform3D(basis,pos))
			if car.health<=0: car.health=100; car.ammo=maxi(car.ammo,6)
			return true
	car.recovery_lock=0.25
	return false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if net.online and net.overlay: resume_race(); return
		if state=="menu":
			hud.back(); return
		elif state=="pause": resume_race(); return
	if event is InputEventMouseMotion: controls.mouse_aim=true
	var pause_pressed = (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_ESCAPE) or (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_START)
	if pause_pressed:
		if net.online and state in ["race","countdown"]: network_pause(); return
		if state=="race": state="pause"; controls.neutral(player()); get_tree().paused=true; hud.menu("pause")
		elif state=="pause": resume_race()
		elif state=="menu": hud.menu("main")
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_R and state=="race": recover_player()
		elif event.physical_keycode==KEY_F3: show_metrics=not show_metrics

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and state=="race" and not demo_auto:
		if net.online:
			if not net.overlay: network_pause()
			return
		controls.neutral(player()); state="pause"; get_tree().paused=true; hud.menu("pause")

func _physics_process(delta: float) -> void:
	if net.online and not net.host: net.tick_client(delta); return
	if state=="countdown":
		countdown-=delta
		if countdown<=0:
			state="race"
			for car in cars: car.freeze=false
		return
	if state not in ["race","menu"]: return
	if state=="race": elapsed+=delta
	_update_conditions(elapsed if state=="race" else 0.0)
	effect_clock+=delta
	for car in cars:
		if car.finish_time>=0: continue
		if net.online and car.human and not car.local_player: net.apply_remote(car)
		elif car.local_player and net.online and net.overlay: controls.neutral(car)
		elif car.local_player and state=="race" and not demo_auto: controls.read(car,camera)
		else:
			car.bot_drive(cars,delta); car.bot.combat(car,cars,delta)
		car.tick(delta)
		if car.stuck_time>3 or car.position.y< -8 or car.position.distance_to(track.points[car.checkpoint])>35 or (car.health<=0 and car.disabled_time<=0): _recover(car)
		if car.firing and state=="race": _shoot(car)
		if effect_clock>0.09 and car.grounded and car.linear_velocity.length()>3 and car.position.distance_to(player().position)<45: effects.dust(car,current_wetness)
		if car.laps>=laps and car.finish_time<0 and state=="race":
			car.finish_time=elapsed; controls.neutral(car); car.freeze=true; car.collision_layer=0; car.collision_mask=1
			if net.online and car.human and is_inf(finish_deadline): finish_deadline=elapsed+45
			if car.local_player:
				hud.portrait.set_mood("victory")
				if not net.online:
					finish_deadline=elapsed+45
					if not cup.running: _save_best()
	if state=="race":
		if cars.all(func(c): return c.finish_time>=0) or elapsed>=finish_deadline or elapsed>=race_limit_seconds:
			finish_race(); return
		if player().finish_time>=0: hud.message="Финиш! Соперникам осталось %d с" % ceili(minf(finish_deadline,race_limit_seconds)-elapsed)
	for pickup in pickups:
		pickup.cooldown=maxf(0,pickup.cooldown-delta); pickup.node.visible=pickup.cooldown<=0
		pickup.node.rotation.y+=delta
		if pickup.cooldown>0: continue
		for car in cars:
			if car.finish_time>=0: continue
			if car.position.distance_to(pickup.node.position)<2:
				car.bot.pickups_collected+=1
				if pickup.shield: car.shield_item=true; car.health=minf(100,car.health+20)
				else: car.ammo=mini(36,car.ammo+12)
				pickup.cooldown=8; effects.burst(pickup.node.position,Color("8defff"))
				if car.local_player: sound.pickup.play()
				break
	if effect_clock>0.09: effect_clock=0

func finish_race() -> void:
	state="results"; get_tree().paused=not net.online; hud.message=""
	if net.online: net.phase="results"; net.overlay=false
	for car in cars:
		car.did_not_finish=car.finish_time<0; controls.neutral(car); car.freeze=true
	if cup.running: cup.finish()
	hud.menu("results")

func _shoot(car: Node3D) -> void:
	if car.fire_cooldown>0 or car.ammo<=0 or car.disabled_time>0 or car.finish_time>=0 or car.ghost_time>0: return
	car.fire_cooldown=0.28 if car.local_player or car.human else 0.55; car.ammo-=1
	car.bot.shots+=1
	var from: Vector3=car.position+Vector3.UP*0.2+car.aim*0.9
	var to: Vector3=from+car.aim*34
	var query = PhysicsRayQueryParameters3D.create(from,to,3,[car.get_rid()])
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		to=hit.position
		if hit.collider is RigidBody3D and hit.collider.has_method("take_damage"):
			hit.collider.take_damage(9,car.aim*75)
			if hit.collider.local_player: hud.portrait.set_mood("hurt")
		effects.burst(to,Color("ffbb51"))
	effects.beam(from,to); net.shot(car,from,to)
	if car.local_player: sound.shot.play()

func _process(delta: float) -> void:
	if cars.is_empty(): return
	_camera(delta)
	weather.update(delta,player().position,state in ["menu","race","countdown"])
	weather.update_headlights(cars,delta,player_index)
	sound.engine(player().linear_velocity.length(),state=="race" and player().finish_time<0)
	if state=="race" and player().boosting: hud.portrait.set_mood("excited")
	capture_time+=delta
	if state=="race" and not capture_path.is_empty(): performance_frames.append(delta)
	if not capture_path.is_empty() and (state=="results" if capture_results else capture_time>10) and not screenshot_done:
		screenshot_done=true
		await RenderingServer.frame_post_draw
		var error = get_viewport().get_texture().get_image().save_png(capture_path)
		print("CAPTURE ",error," ",capture_path)
		print("METRICS ",JSON.stringify({"frames":performance_frames.size(),"cars":cars.size(),"fps":Engine.get_frames_per_second(),"renderer":RenderingServer.get_current_rendering_method(),"scale":get_viewport().scaling_3d_scale,"player_position":str(player().position),"passed":player().passed}))
		get_tree().quit()

func _camera(delta: float, snap: bool = false) -> void:
	var target: Vector3=player().position
	var lookahead: Vector3=player().linear_velocity.limit_length(12)*0.20
	lookahead.y=0; target+=lookahead
	var desired_pos = target+Vector3(0,29,23)
	camera.position=desired_pos if snap else camera.position.lerp(desired_pos,1-exp(-delta*5))
	camera.rotation_degrees=Vector3(-51.6,0,0)
	var focus: Vector2=camera.unproject_position(player().position)
	tilt_shift.set_shader_parameter("focus_y",clampf(focus.y/get_viewport().get_visible_rect().size.y,0.4,0.65))

func standings() -> Array:
	var result = cars.duplicate()
	result.sort_custom(func(a,b):
		if a.finish_time>=0 and b.finish_time>=0: return a.finish_time<b.finish_time
		if a.finish_time>=0: return true
		if b.finish_time>=0: return false
		return a.passed>b.passed)
	return result

func _save_best() -> void:
	# Local first-stage result only. Never grants a full-cup prize or global rank.
	var file = ConfigFile.new(); file.load("user://valley.cfg")
	var section = "records/"+conditions.record_key()
	var legacy = float(file.get_value("records","best_seconds",INF)) if conditions.time_of_day=="day" and conditions.weather=="clear" and conditions.timeline.is_empty() else INF
	var previous = float(file.get_value(section,"best_seconds",legacy))
	if elapsed<previous: file.set_value(section,"best_seconds",elapsed)
	file.set_value(section,"completed_runs",int(file.get_value(section,"completed_runs",0))+1)
	file.set_value(section,"conditions",conditions.descriptor())
	if file.save("user://valley.cfg.pending")==OK:
		DirAccess.rename_absolute("user://valley.cfg.pending","user://valley.cfg")
