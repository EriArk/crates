# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Conditions = preload("res://scripts/stage_conditions.gd")
var failures = 0
func check(ok: bool, label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")

func brake_distance(car: Node3D, grip: float) -> float:
	car.surface_grip=grip; car.freeze=false; car.throttle=0; car.boosting=false; car.brake=0; car.handbrake=false; car.desired=Vector3.ZERO; car.steer_input=0
	car.reset_at(Transform3D(Basis.IDENTITY,Vector3(0,30.72,0)))
	for i in 30: await physics_frame
	car.linear_velocity=Vector3(0,0,-12); car.brake=1.0
	var start = car.position
	var stopped = false
	for i in 120:
		await physics_frame
		if absf(car.linear_velocity.z)<0.6: stopped=true; break
	check(stopped,"Vehicle brakes to low-speed stop before reverse engages")
	var distance: float=absf(car.position.z-start.z)
	car.freeze=true
	return distance

func run() -> void:
	root.size=Vector2i(1280,720)
	var c = Conditions.new(); var original = c.descriptor()
	for bad in [{},{"version":99,"time":"day","weather":"rain","seed":1},{"version":1,"time":"night","weather":"rain","seed":1},{"version":1,"time":"day","weather":"rain","seed":-1},{"version":1,"time":"day","weather":"rain","seed":NAN}]:
		check(not c.configure(bad) and c.descriptor()==original,"Invalid contract cannot partly change conditions")
	check(c.configure(JSON.parse_string(JSON.stringify(original))),"Conditions round-trip through JSON transport")
	var route = preload("res://scripts/track.gd").new()
	var random = RandomNumberGenerator.new(); random.seed=701
	for sample in 1500:
		var point = Vector3(random.randf_range(-140,140),0,random.randf_range(-140,140))
		if sample<route.COUNT: point=route.points[sample]
		var best = 0; var distance = INF
		for i in route.COUNT:
			var d = Vector2(point.x-route.points[i].x,point.z-route.points[i].z).length_squared()
			if d<distance: distance=d; best=i
		check(route.nearest(point)==best,"Spatial generation search matches exhaustive route lookup")
	route.free()
	var game = load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	var keys = {}
	for time in Conditions.TIMES:
		for weather in Conditions.WEATHERS:
			var descriptor = {"version":Conditions.VERSION,"time":time,"weather":weather,"seed":1234}
			check(game.set_conditions(descriptor),"Menu accepts valid stage conditions")
			keys[game.conditions.record_key()]=true
			check(game.weather.rain.visible==(weather=="rain"),"Rain appears only in rain preset")
			var transforms = game.weather.rain.multimesh.buffer
			game.set_conditions(descriptor)
			check(transforms==game.weather.rain.multimesh.buffer,"Stage seed repeats bounded rain layout")
			for car in game.cars: check(is_equal_approx(car.surface_grip,game.conditions.grip()),"All cars share weather grip")
	check(keys.size()==12,"Records separate all twelve stage condition combinations")
	game.hud.menu("conditions"); await process_frame; await process_frame
	check(game.hud.panel.position.y+game.hud.panel.size.y<=720,"Conditions menu fits handheld layout")
	game.hud.buttons[1].grab_focus()
	for pressed in [true,false]:
		var event = InputEventJoypadButton.new(); event.button_index=JOY_BUTTON_A; event.pressed=pressed; root.push_input(event)
	await process_frame
	check(game.conditions.weather=="clear" and game.hud.buttons[1].has_focus(),"Controller weather selection keeps focus on weather")
	game.set_conditions({"version":1,"time":"sunset","weather":"rain","seed":1234})
	game.hud.menu("main"); await process_frame; await process_frame
	check(game.hud.panel.position.y+game.hud.panel.size.y<=720,"Main menu fits handheld layout")
	game.start_race()
	var locked = game.conditions.descriptor()
	check(not game.set_conditions(original) and game.conditions.descriptor()==locked,"Cannot change conditions during countdown")
	for car in game.cars: check(is_equal_approx(car.surface_grip,0.84),"Respawned grid retains wet grip")
	game.state="test"
	for car in game.cars: car.freeze=true
	game.weather.update(1,Vector3.ZERO,true); var clock = game.weather.rain_clock
	game.weather.update(1,Vector3.ZERO,false)
	check(game.weather.rain_clock==clock,"Rain freezes with paused race")
	check(game.weather.rain.multimesh.instance_count==240,"Rain particle budget stays fixed")
	var floor_body = StaticBody3D.new(); var shape = CollisionShape3D.new(); var box = BoxShape3D.new(); box.size=Vector3(100,1,100); shape.shape=box; floor_body.add_child(shape); floor_body.position.y=29.5; root.add_child(floor_body)
	var dry: float=await brake_distance(game.cars[0],1.0)
	var wet: float=await brake_distance(game.cars[0],0.84)
	check(dry>1.0 and wet>dry*1.08,"Wet physical braking distance exceeds dry on same surface")
	print("BRAKING dry=",dry," wet=",wet)
	game.elapsed=31.0; game._save_best()
	game.return_menu(); game.set_conditions(original); game.elapsed=25.0; game._save_best()
	var save = ConfigFile.new(); save.load("user://valley.cfg")
	check(save.get_value("records/valley.v1/sunset/rain","best_seconds",0)>0 and save.get_value("records/valley.v1/day/clear","best_seconds",0)>0,"Saving a dry run preserves wet record")
	floor_body.queue_free(); await preload("audio_drain.gd").dispose(game,self)
	print("WEATHER TEST failures=",failures); quit(1 if failures else 0)
