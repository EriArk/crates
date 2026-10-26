# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures = 0
func check(value: bool, message: String) -> void:
	if not value: failures+=1; push_error(message)

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate(); root.add_child(game)
	await process_frame
	game.demo_auto=true; game.start_race()
	check(game.cars.size()==16,"16-car starting grid")
	for frame in 4000:
		await physics_frame
		if frame==250:
			check(game.state=="race","Countdown releases race")
			var car=game.cars[0]; car.immune=0; car.shield=20
			var hp=car.health; car.take_damage(9)
			check(car.health==hp and car.shield==11,"Shield absorbs damage before health")
			car.shield=0; car.take_damage(9); check(car.health==hp-9,"Unshielded damage")
		if frame%600==0:
			print("DRIVE ",frame," ",game.cars.map(func(c): return {"id":c.index,"passed":c.passed,"y":snappedf(c.position.y,0.1),"speed":snappedf(c.linear_velocity.length(),0.1)}))
	var progressed=0
	for car in game.cars:
		if car.passed>100: progressed+=1
		check(car.position.is_finite() and car.linear_velocity.is_finite(),"Finite physics state")
	check(progressed>=14,"At least 14/16 drivers negotiate first 100 route samples")
	check(game.cars[0].passed>=320,"Player autodrive completes a lap without teleporting forward")
	var before=game.cars[0].passed; game.recover_player()
	await physics_frame; await physics_frame
	check(game.cars[0].passed<=before+2,"Recovery cannot advance race progress")
	check(game.effects.particles.size()<=game.effects.LIMIT,"Bounded effect pool")
	game.return_menu(); check(game.state=="menu","Return to cup menu")
	game.start_race(); check(game.elapsed==0 and game.cars[0].laps==0,"Rematch resets race")
	print("DRIVE TEST failures=",failures," progressed=",progressed)
	game.queue_free(); await process_frame; quit(1 if failures else 0)
