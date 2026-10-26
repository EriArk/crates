# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures = 0
func check(ok: bool, label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	game.demo_auto=true
	for weather in ["clear","rain"]:
		game.return_menu(); game.set_conditions({"version":2,"time":"day" if weather=="clear" else "night","weather":weather,"seed":38021})
		game.start_race()
		var falls = 0; var previous_low = {}
		for frame in 60*650:
			await physics_frame
			for car in game.cars:
				var low: bool=car.position.y< -5
				if low and not previous_low.get(car.index,false): falls+=1
				previous_low[car.index]=low
			if game.state=="results": break
			if frame%3600==0: print("RACE ",weather," seconds=",snappedf(game.elapsed,0.1)," progress=",game.cars.map(func(c): return c.passed))
		var finishers = game.cars.filter(func(c): return c.finish_time>=0).size()
		print("RACE RESULT ",JSON.stringify({"weather":weather,"elapsed":game.elapsed,"finishers":finishers,"falls":falls,"cars":game.cars.map(func(c): return {"id":c.index,"passed":c.passed,"finish":c.finish_time,"recoveries":c.recovery_count,"shots":c.bot.shots,"pickups":c.bot.pickups_collected,"lane_changes":c.bot.lane_changes})}))
		check(game.state=="results","Full "+weather+" race reaches result screen")
		check(finishers>=14,"At least 14/16 finish full "+weather+" race")
		check(falls==0,"No cars fall below the course in full "+weather+" race")
		check(game.cars.any(func(c): return c.bot.shots>0) and game.cars.any(func(c): return c.bot.pickups_collected>0),"Bots use weapons and collect items in full race")
		for car in game.cars: check(car.position.is_finite() and car.linear_velocity.is_finite(),"Finite full-race physics")
		check(game.effects.particles.size()<=game.effects.LIMIT,"Full race respects effect budget")
	game.return_menu(); game.start_race()
	check(game.elapsed==0 and game.cars.all(func(c): return c.finish_time<0),"Full-race rematch resets all finishers")
	await preload("audio_drain.gd").dispose(game,self)
	print("RACE TEST failures=",failures); quit(1 if failures else 0)
