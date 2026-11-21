# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.net.platform_enabled=false;game.select_mode("royale");game.start_race();game.state="test";game.set_physics_process(false)
	for c in game.cars: c.freeze=true;c.collision_layer=0
	await physics_frame
	var car=game.player();var road=game.track.roads.filter(func(r):return r.name=="Town bank exit")[0]
	var start: Vector3=road.points[0];var target: Vector3=road.points[-1];var direction: Vector3=(target-start).normalized()
	start.y=game.track.height_at(start)+0.9
	car.reset_at(Transform3D(Basis(Vector3.UP,atan2(-direction.x,-direction.z)),start));car.freeze=false
	var reached=false
	for frame in 60*20:
		car.throttle=0.65;car.brake=0;car.steer_towards(target-car.position);car.tick(1.0/60);await physics_frame
		if Vector2(car.position.x-target.x,car.position.z-target.z).length()<4: reached=true;break
	var failures=0
	if not reached or car.position.y<10: failures+=1;push_error("Physical car must climb the bank exit without reset")
	print("COUNTY BANK DRIVE failures=",failures," position=",car.position)
	await preload("audio_drain.gd").dispose(game,self);quit(1 if failures else 0)
