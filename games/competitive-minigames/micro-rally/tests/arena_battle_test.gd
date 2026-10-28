# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures=0
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	game.net.platform_enabled=false; game.select_mode("arena"); game.demo_auto=true; game.start_race()
	var falls=0; var fall_points=[]; var last={}; var distances={}; var max_rockets=0
	for car in game.cars: last[car.index]=car.position; distances[car.index]=0.0
	for frame in 60*490:
		await physics_frame
		max_rockets=maxi(max_rockets,game.arena.rockets.size())
		for car in game.cars:
			if car.position.y< -4:
				falls+=1
				if fall_points.size()<16 and last[car.index].y>=-4: fall_points.append(str(car.position))
			if car.position.distance_to(last[car.index])<3: distances[car.index]+=car.position.distance_to(last[car.index])
			last[car.index]=car.position
		if game.state=="results": break
		if frame%3600==0: print("ARENA SOAK t=",snappedf(game.elapsed,0.1)," score=",game.arena.rules.rows.map(func(r): return r.score))
	var total_kills=0; var lives=0; var pickups=0; var recoveries=0
	for row in game.arena.rules.rows: total_kills+=row.kills; lives+=row.life
	for car in game.cars:
		pickups+=car.bot.pickups_collected; recoveries+=car.recovery_count
		check(distances[car.index]>150,"Every bot travels through the arena")
		check(car.position.is_finite() and car.linear_velocity.is_finite(),"Finite physics")
	check(game.state=="results" and game.elapsed>=480,"Complete eight-minute battle reaches results")
	check(total_kills>=16 and lives>=16,"Combat and repeated respawns occur in normal play")
	check(pickups>=16,"Bots contest supplies")
	check(falls==0,"No cars fall through arena geometry")
	check(max_rockets<=32 and game.effects.particles.size()<=game.effects.LIMIT,"Projectile and effect budgets hold")
	print("ARENA BATTLE ",JSON.stringify({"kills":total_kills,"lives":lives,"pickups":pickups,"recoveries":recoveries,"falls":falls,"fall_points":fall_points,"max_rockets":max_rockets,"distance":distances,"scores":game.arena.rules.rows,"failures":failures}))
	game.start_race(); check(game.elapsed==0 and game.arena.rockets.is_empty(),"Clean rematch after complete battle")
	await preload("audio_drain.gd").dispose(game,self)
	quit(1 if failures else 0)
