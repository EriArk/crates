# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Conditions = preload("res://scripts/stage_conditions.gd")
var failures = 0
func check(ok: bool, label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var c = Conditions.new(); var plan = c.next_scenario()
	check(c.configure(plan),"Nightfall scenario validates")
	var saved = c.descriptor()
	for events in [[{"at":10,"time":"night","weather":"rain"}],[{"at":120,"time":"night","weather":"rain"},{"at":90,"time":"day","weather":"clear"}],[{"at":INF,"time":"night","weather":"rain"}],[{"at":100,"time":"unknown","weather":"rain"}],"rain"]:
		var bad = saved.duplicate(true); bad.timeline=events
		check(not c.configure(bad) and c.descriptor()==saved,"Invalid timeline is rejected atomically")
	var too_many = saved.duplicate(true); too_many.timeline=[]
	for i in 9: too_many.timeline.append({"at":float(i+1)*60,"time":"night","weather":"rain"})
	check(not c.configure(too_many),"Bounded schedule limits admission")
	var remote = Conditions.new(); check(remote.configure(JSON.parse_string(JSON.stringify(saved))),"Timeline survives JSON admission")
	var digest = c.record_key()
	check(digest==remote.record_key(),"Equivalent JSON timeline has identical record category")
	var expected = c.sample(180)
	for sample_time in [0.0,60.0,120.0,180.0,299.99,300.0,1200.0]:
		check(c.sample(sample_time)==remote.sample(sample_time),"Timeline depends on elapsed time, not sampling frequency")
	check(c.sample(180)==expected,"Sampling out of order cannot accumulate drift")
	check(absf(c.wetness(180)-c.wetness(180.01))<0.001,"Wetness changes continuously")
	check(c.wetness(120)==0 and is_equal_approx(c.wetness(300),0.8),"Rain starts dry and ends wet")
	check(c.grip(180)<1 and c.grip(180)>0.84,"Intermediate grip follows intermediate wetness")
	var copy = c.descriptor(); copy.timeline[0].weather="rain"
	check(c.descriptor()==saved,"Exported descriptor cannot mutate active timeline")
	var shifted = saved.duplicate(true); shifted.timeline[1].at=360.0; remote.configure(shifted)
	check(remote.record_key()!=digest,"Different schedule duration has separate record category")
	root.size=Vector2i(1280,720)
	var game = load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	check(game.set_conditions(saved),"Stage accepts schedule before start")
	game.start_race(); game.state="race"; game.elapsed=180; game._update_conditions(game.elapsed)
	check(is_equal_approx(game.current_wetness,c.wetness(180)),"Actual game consumes stage clock")
	for car in game.cars: check(is_equal_approx(car.surface_grip,c.grip(180)),"All physical cars receive transitioning grip")
	game.state="pause"; paused=true
	var wet = game.current_wetness; var elapsed = game.elapsed; var lighting = game.weather.sun.light_energy
	for i in 5: await process_frame
	check(game.elapsed==elapsed and game.current_wetness==wet and game.weather.sun.light_energy==lighting,"Pause freezes timeline and lighting")
	game.start_race(); check(game.elapsed==0 and game.current_wetness==0,"Rematch restarts scenario from dry start")
	game.return_menu()
	var night = {"version":2,"time":"night","weather":"clear","seed":2}
	game.set_conditions(night); game.weather.update_headlights(game.cars,1)
	check(game.weather.headlights.size()==4,"At most four real headlight sources")
	check(game.weather.headlights[0].visible and game.weather.light_cars[0]==game.cars[0],"Player always receives first headlight")
	for light in game.weather.headlights: check(not light.shadow_enabled,"Headlights do not add shadow maps")
	game.cycle_bots(); await process_frame; game.weather.update_headlights(game.cars,1)
	for car in game.weather.light_cars: check(car==null or car in game.cars,"Rebuilt grid cannot retain old light owners")
	game.set_conditions({"version":2,"time":"day","weather":"clear","seed":2}); game.weather.update_headlights(game.cars,2)
	for light in game.weather.headlights: check(not light.visible,"Daylight turns off headlight rendering")
	game.hud.menu("conditions"); await process_frame; await process_frame
	check(game.hud.panel.position.y+game.hud.panel.size.y<=720,"Expanded conditions menu fits 720p logical layout")
	var legacy = ConfigFile.new(); legacy.set_value("records","best_seconds",1.0); legacy.save("user://valley.cfg")
	game.set_conditions(saved); game.elapsed=88; game._save_best()
	var record = ConfigFile.new(); record.load("user://valley.cfg")
	check(record.get_value("records/"+game.conditions.record_key(),"best_seconds",0)==88.0,"Legacy dry best cannot become a dynamic-scenario best")
	game.queue_free(); await process_frame
	print("TIMELINE TEST failures=",failures); quit(1 if failures else 0)
