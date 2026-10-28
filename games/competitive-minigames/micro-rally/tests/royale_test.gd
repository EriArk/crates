# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures=0
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	game.net.platform_enabled=false; game.select_mode("royale"); game.start_race(); game.state="test"; game.set_physics_process(false)
	await physics_frame
	check(game.is_royale() and game.cars.size()==16,"Mode route starts real survival map")
	var graph=game.track.graph; var ids=graph.get_point_ids(); var heights=[]
	for id in ids:
		check(not graph.get_id_path(ids[0],id).is_empty(),"Layered navigation is connected: %d" % id)
		heights.append(graph.get_point_position(id).y)
	check(heights.max()-heights.min()>20,"Substantial navigable height range")
	for i in 16:
		check(game.track.safe_point(game.track.spawn_pose(i).origin),"Safe start")
		for j in range(i+1,16): check(game.track.spawn_pose(i).origin.distance_to(game.track.spawn_pose(j).origin)>30,"Separated starts")
	for z in game.track.BRIDGES:
		var high=PhysicsRayQueryParameters3D.create(Vector3(12,18,z),Vector3(12,-5,z),1)
		var low=PhysicsRayQueryParameters3D.create(Vector3(12,8,z),Vector3(12,-5,z),1)
		var above=game.get_world_3d().direct_space_state.intersect_ray(high); var below=game.get_world_3d().direct_space_state.intersect_ray(low)
		check(not above.is_empty() and above.position.y>11.9,"Solid bridge deck")
		check(not below.is_empty() and below.position.y<2,"Real underpass below same XZ")
		var path=game.track.path(Vector3(-60,12,z),Vector3(60,12,z))
		check(path.size()>3 and Array(path).any(func(p): return absf(p.x)<20 and p.y>10),"Bridge is a distinct traversable route")
	for car in game.cars: car.freeze=false
	for frame in 120: await physics_frame
	for car in game.cars:
		check(car.position.y>game.track.height_at(car.position)+0.1,"Spawn suspension supported by height field"); car.freeze=true
	# Real tyres cross the upper deck and pass below it; ray probes alone are insufficient.
	var driver=game.player()
	for car in game.cars: car.collision_layer=0
	for passage in ["over","under"]:
		var start=Vector3(-60,12.9,0) if passage=="over" else Vector3(12,game.track.height_at(Vector3(12,0,-30))+0.9,-30)
		var direction=Vector3.RIGHT if passage=="over" else Vector3.BACK
		driver.reset_at(Transform3D(Basis(Vector3.UP,-PI/2 if passage=="over" else PI),start)); driver.freeze=false
		var reached=false
		for frame in 60*18:
			driver.throttle=0.5; driver.brake=0; driver.steer_towards(direction); driver.tick(1.0/60)
			await physics_frame
			if (driver.position.x>52 if passage=="over" else driver.position.z>25): reached=true; break
		check(reached,"Physical drive across "+passage+" bridge at "+str(driver.position))
		check(driver.position.y>11 if passage=="over" else driver.position.y<3,"Correct bridge layer "+passage)
		driver.freeze=true
	var rules=game.royale.Rules.new(); rules.reset(4)
	rules.damage(2,0,100,10); rules.eliminate([2,3],10)
	check(rules.places==[0,0,4,4] and rules.rows[0].kills==1,"Simultaneous eliminations share place and retain kill credit")
	rules.eliminate([2],11); check(rules.rows[2].deaths==1,"Elimination is idempotent")
	rules.eliminate([1],12); rules.finish(); check(rules.places==[1,2,4,4],"Last survivor wins")
	for final in 4:
		game.royale.final_index=final
		var previous_radius=280.0; var previous_center=Vector2.ZERO
		for t in range(0,661,15):
			game.royale.update_zone(t)
			check(game.royale.radius<=previous_radius and game.royale.center.distance_to(previous_center)<=previous_radius-game.royale.radius+0.01,"Successive safe circles are nested")
			previous_radius=game.royale.radius; previous_center=game.royale.center
		for t in range(90,631,30):
			game.royale.update_zone(t)
			var valid: Array=[]
			for id in ids:
				if game.royale.outside(graph.get_point_position(id))< -3: valid.append(id)
			var reachable: Array=[]
			if not valid.is_empty(): reachable=[valid[0]]
			var cursor=0
			while cursor<reachable.size():
				for other in graph.get_point_connections(reachable[cursor]):
					if other in valid and other not in reachable: reachable.append(other)
				cursor+=1
			check(reachable.size()==valid.size(),"Safe circle preserves routes final=%d time=%d islands=%d" % [final,t,valid.size()-reachable.size()])
		var final_pos=game.track.FINALS[final]; var p=Vector3(final_pos.x,0,final_pos.y); p.y=game.track.height_at(p)
		check(game.track.safe_point(p,8),"Final venue is open and reachable")
	game.start_race(); game.state="race"; game.set_physics_process(false)
	var car=game.player(); car.health=5; car.immune=100; car.ghost_time=100; car.shield=100
	game.elapsed=650; car.position=game.track.spawn_pose(0).origin; game.royale.tick_before(1)
	check(car.health==0,"Storm ignores shield and recovery protection")
	game.arena.tick(0.02); check(game.arena.rules.places[0]==16 and car.health==0,"Elimination enters real gameplay state")
	game.arena.tick(4); check(car.health==0 and game.arena.rules.rows[0].life==0,"No respawn in royale")
	check(not game.arena.recover(car) and game.royale.focus()!=car,"Dead input cannot recover; camera follows a survivor")
	for other in game.cars:
		if other.index!=1: other.health=0
	game.arena.tick(0.01)
	check(game.state=="results" and game.arena.rules.places[1]==1,"Ordinary last survivor produces results")
	game.start_race(); check(game.arena.rules.places.count(0)==16 and game.elapsed==0,"Rematch restores fresh roster")
	game.state="race"
	for other in game.cars: other.health=0
	game.arena.tick(0.01); game.sound.events.clear(); game.sound.finish_played=false; game.sound.update(game,0.1)
	check(game.arena.rules.places.count(1)==0 and game.sound.events.get("win",0)==0,"A simultaneous wipe has no arbitrary winner or victory jingle")
	game.return_menu(); game.select_mode("arena"); game.start_race(); check(not game.is_royale() and not "places" in game.arena.rules,"Arena respawn rules restored")
	await preload("audio_drain.gd").dispose(game,self)
	print("ROYALE TEST failures=",failures," nav=",ids.size()); quit(1 if failures else 0)
