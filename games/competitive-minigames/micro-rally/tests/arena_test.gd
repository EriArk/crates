# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures=0
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	game.net.platform_enabled=false; game.select_mode("arena"); game.start_race(); game.state="test"; game.set_physics_process(false)
	await physics_frame
	check(game.is_arena() and game.cars.size()==16,"Arena starts with 16 cars through the ordinary mode route")
	check(not "COUNT" in game.track,"Arena does not masquerade as a lap circuit")
	var graph=game.track.graph; var ids=graph.get_point_ids()
	for id in ids: check(not graph.get_id_path(ids[0],id).is_empty(),"Every navigation point connects to the playable graph")
	for i in 16:
		var pos=game.track.spawn_pose(i).origin
		check(game.track.safe_point(pos),"Spawn is traversable")
		var probe=PhysicsShapeQueryParameters3D.new(); var sphere=SphereShape3D.new(); sphere.radius=0.25
		probe.shape=sphere; probe.transform.origin=pos+Vector3.UP*2; probe.motion=Vector3.DOWN*6; probe.collision_mask=1
		var travel=game.get_world_3d().direct_space_state.cast_motion(probe)
		check(travel.size()==2 and travel[0]<1,"Finite wheel footprint finds the floor at spawn %d" % i)
		for j in range(i+1,16): check(pos.distance_to(game.track.spawn_pose(j).origin)>8,"Spawns do not overlap")
	for car in game.cars: car.freeze=false
	for frame in 120: await physics_frame
	for car in game.cars:
		check(car.position.y>game.track.height_at(car.position)+0.1 and car.position.y<game.track.height_at(car.position)+1.5,"Real suspension settles on arena floor")
		car.freeze=true
	var rules=game.arena.Rules.new(); rules.reset(4)
	rules.damage(0,1,40,0); rules.damage(0,2,60,1)
	check(rules.wreck(0,1) and not rules.wreck(0,1.1),"Exactly one result per life")
	check(rules.rows[2].kills==1 and rules.rows[2].score==3 and rules.rows[1].assists==1,"Last attacker gets kill and substantial contributor gets assist")
	rules.revived(0); rules.damage(0,1,40,2); rules.repair(0,35); rules.damage(0,2,80,3); rules.wreck(0,3)
	check(rules.rows[1].assists==1,"Repaired damage cannot farm assists")
	rules.revived(0); rules.damage(0,1,40,4); rules.wreck(0,20)
	check(rules.rows[0].score== -1,"Expired credit does not award a kill")
	var a=game.cars[0]; var b=game.cars[1]
	for car in game.cars: car.freeze=true; car.collision_layer=0; car.health=100; car.immune=0; car.ghost_time=0
	a.position=Vector3(0,0.9,16); a.aim=Vector3.FORWARD; b.position=Vector3(1,0.9,0); b.collision_layer=2
	await physics_frame; await physics_frame
	var low=game.arena.Aim.resolve(a,game.cars,1); var off=game.arena.Aim.resolve(a,game.cars,0)
	check(low.x>0 and low.x<0.05 and absf(off.x)<0.001,"Low assistance is bounded and Off leaves horizontal aim alone")
	b.position.y=4.9; await physics_frame; await physics_frame
	check(game.arena.Aim.resolve(a,game.cars,1).y>0.15,"Aim solves height differences")
	var wall=game.Art.collider(game,Vector3(8,8,1),Vector3(0,4,8)); await physics_frame; await physics_frame
	check(game.arena.Aim.resolve(a,game.cars,2).is_equal_approx(Vector3.FORWARD),"Cover blocks aim assistance")
	wall.queue_free(); await physics_frame; await physics_frame
	a.aim=Vector3.RIGHT
	check(game.arena.Aim.resolve(a,game.cars,2).is_equal_approx(Vector3.RIGHT),"Turning away releases the target immediately")
	game.state="race"; a.position=Vector3(0,0.9,10); b.position=Vector3(0,0.9,-3); a.aim=Vector3.FORWARD
	a.weapon="rocket"; a.ammo=3; a.weapon_selected=true; a.fire_cooldown=0
	await physics_frame; await physics_frame
	game.arena.shoot(a)
	for frame in 50: game.arena.update_rockets(1.0/60)
	check(b.health<100 and a.ammo==2 and game.arena.rockets.is_empty(),"Swept rocket collision deals damage and consumes one round")
	b.health=100; b.position=Vector3(0,0.9,4); a.weapon="pulse"; a.ammo=2; a.fire_cooldown=0
	await physics_frame; await physics_frame
	game.arena.shoot(a)
	check(b.health==68 and a.ammo==1,"Close-range pulse deals bounded damage")
	wall=game.Art.collider(game,Vector3(8,8,1),Vector3(0,4,7)); b.health=100; a.fire_cooldown=0
	await physics_frame; await physics_frame
	game.arena.shoot(a)
	check(b.health==100,"Solid cover blocks the pulse")
	wall.queue_free()
	game.start_race(); game.state="race"; game.set_physics_process(false)
	a=game.cars[0]; a.immune=0; a.ghost_time=0; a.health=10
	game.arena.hurt(a,20,Vector3.ZERO,a.position,1); game.arena.tick(0.01)
	check(game.arena.rules.rows[1].kills==1 and a.health==0,"Real damage enters the arena score ledger")
	game.arena.tick(3.1)
	check(a.health==100 and a.ghost_time>0 and game.arena.rules.rows[0].life==1,"Destroyed car respawns with a new life and protection")
	check(not a.begin_shot(),"Protected respawn cannot shoot")
	a.health=45; a.missing_wheels=1; a.physics.wheels[0].missing=true; a.recovery_lock=0; a.reset_pending=false; a.overturned_time=1
	game.arena.recover(a)
	check(a.health==45 and a.missing_wheels==1,"Recovery does not repair health or a missing wheel")
	game.start_race(); game.elapsed=game.arena.Rules.DURATION-0.01; game.state="race"; game.arena.tick(0.02)
	check(game.state=="results" and game.hud.menu_mode=="results","Timed event opens battle standings")
	game.start_race(); check(game.elapsed==0 and game.arena.rules.rows.all(func(r): return r.score==0 and r.deaths==0),"Rematch resets the score and lives")
	game.return_menu(); game.select_mode("race"); game.start_race()
	check(not game.is_arena() and not game.cars[0].arena_mode and game.track.COUNT==320,"Returning to racing restores genuine lap tracking")
	game.return_menu(); game.cycle_track(); game.select_mode("arena"); game.select_mode("race")
	check(game.quick_track==game.Tracks.QUARRY,"Changing modes preserves the selected racing track")
	await preload("audio_drain.gd").dispose(game,self)
	print("ARENA TEST failures=",failures," nav_points=",ids.size()); quit(1 if failures else 0)
