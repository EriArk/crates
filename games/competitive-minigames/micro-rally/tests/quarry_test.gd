# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures=0
func check(ok: bool, label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	game.set_physics_process(false)
	var valley_points=game.track.points.duplicate()
	game.quick_track=game.Tracks.QUARRY; game.start_race()
	await physics_frame
	check(game.current_track==game.Tracks.QUARRY and game.track.points!=valley_points,"Quarry is distinct geometry")
	check(get_nodes_in_group("driving_surface").size()==1 and get_nodes_in_group("bridge_rail").is_empty(),"Old Valley collision and bridge bodies are detached")
	check(game.cars.all(func(c): return c.track==game.track),"Every vehicle binds to the loaded surface")
	check(game.race_limit_seconds==900 and game.pickups.size()>5,"Track owns race limit and pickups")
	var track=game.track
	var route_length=track.length
	var worst={}
	var low=INF; var high=-INF; var max_grade=0.0; var hits=0; var worst_height=0.0
	for i in track.COUNT:
		var p: Vector3=track.points[i]; var d: Vector3=track.points[(i+1)%track.COUNT]-p
		low=minf(low,p.y); high=maxf(high,p.y); max_grade=maxf(max_grade,absf(d.y)/maxf(0.01,Vector2(d.x,d.z).length()))
		var side=Vector3(-track.tangents[i].z,0,track.tangents[i].x)
		for lane in [-5.5,0.0,5.5]:
			var point=p+side*lane
			var query=PhysicsRayQueryParameters3D.create(point+Vector3.UP*5,point-Vector3.UP*5,1)
			var hit=track.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty():
				hits+=1
				if absf(hit.position.y-p.y)>worst_height:
					worst_height=absf(hit.position.y-p.y); worst={"index":i,"lane":lane,"point":str(point),"hit":str(hit.position),"nearest":track.nearest(point),"analytic":track.ground_height(point.x,point.z,track.nearest(point),true)}
	check(high-low>8 and max_grade<0.55,"Terraced route has meaningful climb and driveable grades")
	check(hits==track.COUNT*3 and worst_height<1.5,"Road and banked shoulders have continuous support around entire lap")
	var projection=preload("road_surface_check.gd").inspect(track)
	check(projection.interior_error<0.001 and projection.coverage_error<0.001,"Whole road triangles follow terrain without holes, overlaps or lifted interiors")
	print("ROAD PROJECTION ",JSON.stringify(projection))
	var visual_error=0.0
	var mesh: ArrayMesh=track.get_node("RoadSurface").mesh
	for vertex in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var query=PhysicsRayQueryParameters3D.create(vertex+Vector3.UP*2,vertex-Vector3.UP*2,1)
		var hit=track.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): failures+=1; print("MISSING ROAD SUPPORT ",vertex)
		else: visual_error=maxf(visual_error,absf(vertex.y-hit.position.y-0.035))
	check(visual_error<0.025,"Visible banked road vertices follow the actual terrain collision")
	for point in [Vector3(-130,40,54),Vector3(130,40,0),Vector3(0,40,-130),Vector3(0,40,130)]:
		var hit=track.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point,point-Vector3.UP*60,1))
		check(not hit.is_empty() and hit.collider.is_in_group("quarry_backdrop"),"Plateau continues beyond each visible driving-mesh edge")
	var old_record=ConfigFile.new(); old_record.set_value("records","best_seconds",42.0); old_record.save("user://valley.cfg")
	game.elapsed=17; game._save_best()
	var retained=ConfigFile.new(); retained.load("user://valley.cfg")
	var quarry_record=ConfigFile.new(); quarry_record.load("user://quarry.1.cfg")
	check(retained.get_value("records","best_seconds")==42.0 and quarry_record.get_value(game.record_section(),"best_seconds")==17,"Quarry quick result cannot overwrite Valley records")
	check(not game.load_track("unknown") and game.track==track,"Unknown stage cannot silently fall back or destroy current world")
	game.return_menu(); game.quick_track=game.Tracks.VALLEY; game.start_race(); await physics_frame
	check(game.track.points==valley_points and get_nodes_in_group("driving_surface").size()==1,"Return to Valley restores original route without duplicate collision")
	check(game.race_limit_seconds==600,"Quarry limit cannot leak into Valley/network")
	print("QUARRY GEOMETRY ",JSON.stringify({"failures":failures,"length":route_length,"elevation":high-low,"max_grade":max_grade,"support_hits":hits,"max_crossfall_height":worst_height,"road_collision_error":visual_error,"worst":worst}))
	await preload("audio_drain.gd").dispose(game,self); quit(1 if failures else 0)
