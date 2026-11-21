# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	game.net.platform_enabled=false; game.select_mode("royale"); game.demo_auto=true; game.start_race()
	var falls=0; var last={}; var distances={}; var dead={}; var reborn=0
	for car in game.cars: last[car.index]=car.position; distances[car.index]=0.0
	for frame in 60*710:
		await physics_frame
		for car in game.cars:
			if car.position.y< -4: falls+=1
			if car.health<=0: dead[car.index]=true
			elif dead.has(car.index): reborn+=1
			var distance=car.position.distance_to(last[car.index])
			if distance<3: distances[car.index]+=distance
			last[car.index]=car.position
		if frame%3600==0: print("ROYALE SOAK t=",snappedf(game.elapsed,0.1)," alive=",game.royale.alive())
		if game.state=="results": break
	var failures=0
	if game.state!="results" or game.royale.alive()>1: failures+=1; push_error("Survival match must resolve")
	if falls>0 or reborn>0: failures+=1; push_error("No geometry falls or resurrection")
	for car in game.cars:
		if distances[car.index]<30: failures+=1; push_error("Stationary bot "+str(car.index))
	print("ROYALE BATTLE ",JSON.stringify({"elapsed":game.elapsed,"alive":game.royale.alive(),"falls":falls,"reborn":reborn,"distance":distances,"places":game.arena.rules.places,"recoveries":game.cars.map(func(c): return c.recovery_count),"eliminations":game.royale.eliminations,"kills":game.arena.rules.rows.map(func(r): return r.kills),"failures":failures}))
	await preload("audio_drain.gd").dispose(game,self); quit(1 if failures else 0)
