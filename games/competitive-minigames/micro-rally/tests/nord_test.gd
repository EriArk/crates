# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures=0
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	game.set_process(false); game.set_physics_process(false)
	var directory="user://nord-check/"+str(Time.get_ticks_usec()); game.cup.store.load_profile("driver",directory); game.cup.store.begin()
	var rows: Array=[]
	for i in 16: rows.append({"slot":i,"ms":300000+i*1000,"progress":1600})
	for i in 3: game.cup.store.finish(i,rows)
	var identity=game.cup.store.data.active.id; var roster=game.cup.store.data.active.roster.duplicate()
	game.cup.start_stage(); await physics_frame; await physics_frame
	var track=game.track
	check(game.current_track==game.Tracks.NORD and game.laps==1 and game.cup.stage==3,"Existing three-stage cup opens full Nordschleife finale")
	check(game.cup.store.data.active.id==identity and game.cup.store.data.active.roster==roster,"Final retains identity, roster and previous results")
	check(track.COUNT==4096 and track.length>20800 and track.length<21000,"Full geographic circuit retains length and dense sampling")
	var low=INF; var high=-INF; var grade=0.0; var descent=0.0; var hits=0; var error=0.0
	for i in track.COUNT:
		low=minf(low,track.points[i].y); high=maxf(high,track.points[i].y)
		var delta: Vector3=track.points[(i+1)%track.COUNT]-track.points[i]
		grade=maxf(grade,absf(delta.y)/Vector2(delta.x,delta.z).length())
		descent=maxf(descent,-delta.y/Vector2(delta.x,delta.z).length())
		for lane in [-5.5,0.0,5.5]:
			var p: Vector3=track.road_pose(i,lane,0).origin
			var hit=track.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*3,p-Vector3.UP*3,1))
			if not hit.is_empty(): hits+=1; error=maxf(error,absf(p.y-hit.position.y))
	check(high-low>280 and high-low<310 and grade<0.181 and descent<0.111,"DEM keeps recognisable elevation range with bounded gradients")
	check(hits==track.COUNT*3 and error<0.02,"Road, shoulders and banking have uninterrupted physical support")
	check(track.section_name(0)=="T13" and track.section_name(2378)=="Karussell" and track.section_name(3550)=="Döttinger Höhe","Named sections retain mapped order")
	check(track.banks[2390]>0.25,"Karussell has physical banking, not only a painted texture")
	var projection_error=0.0
	for node in track.get_children():
		if not node is MeshInstance3D or not str(node.name).begins_with("NordRoad"): continue
		var arrays=node.mesh.surface_get_arrays(0); var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]; var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		for i in range(0,indices.size(),3):
			var p=(vertices[indices[i]]+vertices[indices[i+1]]+vertices[indices[i+2]])/3+node.position
			projection_error=maxf(projection_error,absf(p.y-track.surface_height(p.x,p.z)-0.035))
	check(projection_error<0.003,"Clipped visual road follows the long-track terrain grid inside triangles")
	for at in [460,2378,2805,3550,0]:
		for i in 10: track.update_view(track.points[at]); await process_frame
		check(track.scenery.size()<=9 and track.pending.is_empty(),"Scenery streams with a fixed nine-tile budget")
	var report={"length":track.length,"elevation":high-low,"grade":grade,"descent":descent,"support_hits":hits,"support_error":error,"projection_error":projection_error,"max_scenery":track.max_scenery,"terrain_tiles":track.tiles.size()}
	game.finish_race() # Award fixture only; a separate test drives the final in full.
	check(game.cup.store.data.active.settled and game.cup.store.data.active.results.size()==4,"Final result settles the complete four-stage cup")
	var wins=game.cup.store.data.wins; game.finish_race(); check(game.cup.store.data.wins==wins,"Repeated finish never awards twice")
	game.cup.leave_stage(); game.cup.store.load_profile("driver",directory)
	check(game.cup.store.data.active.id==identity and game.cup.store.data.active.settled,"Completed cup survives restart")
	game.quick_track=game.Tracks.NORD; game.start_race(); check(game.laps==1,"Standalone Nordschleife also uses one full lap")
	game.return_menu(); game.quick_track=game.Tracks.VALLEY; game.start_race(); await physics_frame
	check(game.track.COUNT==320 and game.laps==4 and get_nodes_in_group("nord_ground").is_empty(),"Return detaches all long-track collision and preserves Valley")
	report.failures=failures; print("NORD TEST ",JSON.stringify(report))
	await preload("audio_drain.gd").dispose(game,self); quit(1 if failures else 0)
