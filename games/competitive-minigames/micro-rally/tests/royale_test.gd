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
	check(game.track.map_bounds.size==Vector2(900,700),"Expanded county bounds")
	# Every authored start/major junction must remain represented, not silently pruned.
	for key in game.track.data.nodes:
		var p=game.track.v3(game.track.data.nodes[key]); p.y=game.track.height_at(p)
		check(graph.get_point_position(graph.get_closest_point(p)).distance_to(p)<9,"Authored junction remains navigable: "+key)
	for bridge in game.track.bridges:
		var midpoint: Vector3=(bridge.a+bridge.b)/2
		var above=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(midpoint+Vector3.UP*8,midpoint-Vector3.UP*20,1))
		check(not above.is_empty() and above.position.y>11.9,"Solid bridge deck")
		var path=game.track.path(bridge.a,bridge.b)
		check(path.size()>3 and Array(path).any(func(p):return p.y>11 and game.track.on_bridge(p)),"Bridge connected at both approaches")
	for car in game.cars: car.freeze=false
	for frame in 120: await physics_frame
	for car in game.cars:
		check(car.position.y>game.track.height_at(car.position)+0.1,"Spawn suspension supported"); car.freeze=true
	var driver=game.player()
	for car in game.cars: car.collision_layer=0
	# Exercise each real bridge approach/deck with wheels, without recovery teleports.
	for bridge in game.track.bridges:
		var direction: Vector3=(bridge.b-bridge.a).normalized(); var start: Vector3=bridge.a-direction*12
		start.y=game.track.height_at(start)+0.9
		driver.reset_at(Transform3D(Basis(Vector3.UP,atan2(-direction.x,-direction.z)),start)); driver.freeze=false
		var reached=false
		for frame in 60*35:
			driver.throttle=0.45; driver.brake=0; driver.steer_towards(direction); driver.tick(1.0/60)
			await physics_frame
			if (driver.position-bridge.b).dot(direction)>5: reached=true; break
		check(reached,"Physical bridge "+bridge.name+" at "+str(driver.position)); driver.freeze=true
	# Lower-bank road crosses beneath the first three upper decks at the same XZ.
	var lower=game.track.roads.filter(func(r):return r.kind=="lower")[0].points
	for bridge in game.track.bridges.slice(0,3):
		var at=-1
		for i in lower.size():
			if game.track.bridge_at(lower[i])>=0 and lower[i].distance_to((bridge.a+bridge.b)/2)<bridge.a.distance_to(bridge.b)*0.55: at=i; break
		check(at>=8 and at<lower.size()-8,"Lower path beneath "+bridge.name)
		if at<8 or at>=lower.size()-8: continue
		var target: Vector3=lower[at+8]; var start: Vector3=lower[at-8]; start.y=game.track.height_at(start)+0.9
		var direction: Vector3=(target-start).normalized(); direction.y=0
		driver.reset_at(Transform3D(Basis(Vector3.UP,atan2(-direction.x,-direction.z)),start)); driver.freeze=false
		var reached=false
		for frame in 60*18:
			driver.throttle=0.4; driver.brake=0; driver.steer_towards(target-driver.position); driver.tick(1.0/60)
			await physics_frame
			if Vector2(driver.position.x-target.x,driver.position.z-target.z).length()<5: reached=true; break
		check(reached and driver.position.y<5,"Physical lower passage "+bridge.name+" at "+str(driver.position)); driver.freeze=true
	var rules=game.royale.Rules.new(); rules.reset(4)
	rules.damage(2,0,100,10); rules.eliminate([2,3],10)
	check(rules.places==[0,0,4,4] and rules.rows[0].kills==1,"Simultaneous eliminations share place and retain kill credit")
	rules.eliminate([2],11); check(rules.rows[2].deaths==1,"Elimination is idempotent")
	rules.eliminate([1],12); rules.finish(); check(rules.places==[1,2,4,4],"Last survivor wins")
	for final in 4:
		game.royale.final_index=final
		var previous_radius=600.0; var previous_center=Vector2.ZERO
		for t in range(0,661,15):
			game.royale.update_zone(t)
			check(game.royale.radius<=previous_radius and game.royale.center.distance_to(previous_center)<=previous_radius-game.royale.radius+0.01,"Successive safe circles are nested")
			previous_radius=game.royale.radius; previous_center=game.royale.center
		for t in range(90,631,30):
			game.royale.update_zone(t)
			var valid: Dictionary={}
			for id in ids:
				if game.royale.outside(graph.get_point_position(id))< -3: valid[id]=true
			# Circle clipping can cut a courtyard. Measure the actual shortest exit,
			# including exposure, with the SAME storm weights used by actual bots.
			var target=Vector3(game.royale.center.x,0,game.royale.center.y); target.y=game.track.height_at(target)
			var goal=graph.get_closest_point(target)
			for id in ids: graph.set_point_weight_scale(id,1+maxf(0,game.royale.outside(graph.get_point_position(id))+10)*0.12)
			var reachable={goal:true}; var queue=[goal]; var cursor=0
			while cursor<queue.size():
				for other in graph.get_point_connections(queue[cursor]):
					if valid.has(other) and not reachable.has(other): reachable[other]=true; queue.append(other)
				cursor+=1
			var worst=0.0; var worst_id=-1
			for id in valid:
				if reachable.has(id): continue
				var route=graph.get_point_path(id,goal); var exposure=0.0
				for i in route.size()-1:
					if game.royale.outside((route[i]+route[i+1])/2)>0: exposure+=route[i].distance_to(route[i+1])
				if exposure>worst: worst=exposure; worst_id=id
			print("ZONE EXIT final=",final," time=",t," metres=",snappedf(worst,0.1)," at=",graph.get_point_position(worst_id) if worst_id>=0 else Vector3.ZERO)
			check(worst<=40,"Safe-area exit exposure bounded to five seconds at 8m/s final=%d time=%d distance=%.1f" % [final,t,worst])
			for id in ids: graph.set_point_weight_scale(id,1)

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
