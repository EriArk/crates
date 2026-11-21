# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Wire=preload("res://scripts/race_wire.gd")
var failures=0
func check(ok: bool,label: String):
	if not ok: failures+=1; push_error(label)
func _initialize(): call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process(false);game.set_physics_process(false); game.state="test"
	game.net.platform_enabled=false;game.net.bridge.set_process(false)
	for c in game.cars: c.freeze=true
	var car=game.player();var other=game.cars[1]
	for c in game.cars:
		if c!=car: c.reset_pending=false; c.position=Vector3(1000+c.index*10,100,1000)
	car.immune=0;car.ghost_time=0;car.shield=0;car.health=30
	car.take_damage(10,Vector3.ZERO,car.wheel_pivots[0].global_position)
	check(car.missing_wheels==0 and car.health==20,"Low health and a close hit do not remove a wheel")
	car.aim=Vector3(0,0.35,-1).normalized();car.aim_3d=true
	var command=Wire.input(car);check(Wire.valid_input(command),"3D input passes validation")
	Wire.apply_input(other,command);check(other.aim.dot(car.aim)>0.999 and other.aim_3d,"Remote driver preserves pitch and aim mode")
	command[11]=2000;check(not Wire.valid_input(command),"Invalid vertical aim rejected")
	game.controls.reticle=Vector2(.5,.48);game.controls.move_reticle(Vector2(1,-1),.2)
	var held=game.controls.reticle;game.controls.move_reticle(Vector2.ZERO,.5)
	check(held.x>.5 and held.y<.48 and held==game.controls.reticle,"Stick moves a persistent screen reticle")
	for life in [2,1,0]:
		car.immune=0;car.ghost_time=0;car.disabled_time=0;car.shield=0
		game.state="race";game.feedback.update(game,0)
		var explosions=int(game.sound.events.get("wreck",0))
		car.take_damage(200)
		check(car.lives==life and car.collision_layer==0 and car.collision_mask==0,"Death consumes one life and immediately removes collisions")
		var serial=car.death_serial; car.register_wreck();check(car.death_serial==serial,"Corpse does not repeat death/explosion")
		await process_frame;game.feedback.update(game,0)
		check(int(game.sound.events.get("wreck",0))==explosions+1,"Each death emits exactly one explosion cue, including feedback")
		if life>0:
			car.reset_pending=false;car.recovery_lock=0
			if life==2:
				car.recovery_lock=.25;car.disabled_time=0;game._physics_process(.3)
				check(car.health>0,"A blocked-road retry timer continues while wrecked")
			else:check(game._recover(car),"Race respawns while lives remain")
			check(car.health==100 and car.ghost_time>=2 and car.collision_layer==4 and car.collision_mask==1,"Respawn protects from cars while retaining ground support")
			await physics_frame;await physics_frame;car.freeze=true
			car.tick(2.6)
			check(car.ghost_time==0 and car.collision_layer==2 and car.collision_mask==3,"Clear respawn becomes solid after brief ghost protection")
	check(not game._recover(car),"Race cannot recover after third death")
	var snapshot=Wire.car_state(car)
	check(snapshot.size()==Wire.CAR_LIMITS.size() and snapshot[56]==0 and snapshot[57]==3,"Snapshot carries remaining lives and death serial")
	game.select_mode("royale");game.start_race();game.state="race";game.set_physics_process(false)
	for c in game.cars: c.freeze=true
	car=game.player();game.royale.update_zone(300);game.elapsed=300
	for life in [2,1,0]:
		car.health=0;game.arena.tick(.01)
		check(car.lives==life,"Royale consumes exactly one life per wreck")
		if life>0:
			check(game.arena.rules.places[0]==0 and game.royale.alive()==16,"Pending respawn still competes for final place")
			game.arena.tick(3.1)
			check(car.health>0 and game.royale.outside(car.reset_pose.origin)<0,"Royale respawns inside current safe zone")
			await physics_frame;await physics_frame;car.freeze=true
		else: check(game.arena.rules.places[0]==16 and not game.arena.recover(car),"Third royale death assigns final place")
	game.start_race();check(game.player().lives==3 and game.player().death_serial==0,"Rematch restores three fresh lives")
	game.state="race";game.elapsed=661;game.royale.update_zone(game.elapsed)
	for c in game.cars: c.freeze=true;c.health=0
	for step in 120:
		game.arena.tick(.5)
		await physics_frame
		if game.state=="results":break
	check(game.state=="results" and game.cars.all(func(c):return c.lives==0),"Closed final circle exhausts remaining lives without an endless respawn wait")
	# Check height-aware reticle intersection and muzzle occlusion in real physics.
	paused=false;game.state="test";game.set_process(false);game.set_physics_process(false)
	for c in game.cars: c.freeze=true
	car=game.player(); car.position=Vector3(0,100,0);car.reset_pending=false
	var target=game.Art.collider(game,Vector3(4,4,1),Vector3(0,103,-20))
	game.camera.position=Vector3(0,102,5);game.camera.look_at(Vector3(0,103,-20));game.camera.fov=66
	await physics_frame;await physics_frame
	var point=game.Controls.aim_point(game.camera,car,Vector2(.5,.5))
	check(point.y>102 and point.z< -19,"Low-camera crosshair follows raised target instead of ground plane")
	target.free();other=game.cars[1];other.reset_pending=false;other.position=Vector3(0,103,-20)
	other.health=100;other.immune=0;other.ghost_time=0;other.disabled_time=0;other.shield=0;other.collision_layer=2
	car.health=100;car.disabled_time=0;car.immune=0;car.ghost_time=0;car.cool_weapon();car.aim_3d=true;car.assist_level=0
	game.camera.look_at(other.position);await physics_frame;await physics_frame
	point=game.Controls.aim_point(game.camera,car,Vector2(.5,.5));car.aim=(point-car.muzzle_origin()).normalized()
	game._shoot(car);check(other.health<100,"Actual muzzle ray hits an elevated car under the low-camera reticle with assistance off")
	var wall=game.Art.collider(game,Vector3(8,8,1),Vector3(0,102,-8));await physics_frame;await physics_frame
	point=game.Controls.aim_point(game.camera,car,Vector2(.5,.5));check(point.z> -9,"Reticle ray respects a nearer obstruction")
	var protected_health=other.health;car.fire_cooldown=0;game._shoot(car)
	check(other.health==protected_health,"Muzzle shot cannot pass through nearer cover")
	print("COMBAT_FEEL_TEST failures=",failures)
	await preload("audio_drain.gd").dispose(game,self);quit(1 if failures else 0)
