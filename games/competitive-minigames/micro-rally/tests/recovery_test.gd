# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures = 0
func check(ok: bool, label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,720)
	var game = load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	game.state="test"
	for car in game.cars: car.freeze=true
	await physics_frame; await physics_frame
	var rails = get_nodes_in_group("bridge_rail")
	check(rails.size()>10,"Continuous bridge rails exist")
	for rail in rails:
		var from: Vector3=rail.position-rail.basis.x*1.5
		var to: Vector3=rail.position+rail.basis.x*1.5
		var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1))
		check(not hit.is_empty() and hit.collider.is_in_group("bridge_rail"),"Mid-span bridge collision has no gap")
	var a=game.cars[0]; var b=game.cars[1]; var at=60
	a.checkpoint=at; a.passed=at; a.position=Vector3(0,-10,0)
	b.position=game.track.points[at]+Vector3.UP*0.85
	check(game._recover(a),"Crowded recovery finds another slot")
	check(a.reset_pose.origin.distance_to(b.position)>=4.2 and a.passed<=at,"Recovery avoids traffic and never advances progress")
	check(a.ghost_time>0 and a.collision_mask==1,"Recovery temporarily disables car contacts")
	check(not game._recover(a),"Repeated recovery cannot queue another teleport")
	# A second recovery must reserve a different position even before physics commits the first.
	b.position=Vector3(0,-10,0); b.checkpoint=at; b.passed=at
	check(game._recover(b) and a.reset_pose.origin.distance_to(b.reset_pose.origin)>=4.2,"Queued recoveries reserve separate slots")
	a.reset_pending=false; b.reset_pending=false
	a.position=Vector3(0,30,0); b.position=a.position; a.ghost_time=0.01; b.ghost_time=0.01
	await physics_frame; await physics_frame
	a.tick(0.02); b.tick(0.02)
	check(a.collision_layer==4 and b.collision_layer==4,"Overlapping ghosts cannot restore solid collision")
	b.position=Vector3(10,30,0); await physics_frame; await physics_frame
	a.tick(0.2); b.tick(0.2)
	check(a.collision_layer==2 and b.collision_layer==2,"Solid collision returns after clearance")
	a.recovery_lock=0; a.checkpoint=at; a.passed=at
	var blocker = 1
	for back in [0,2,4,6]:
		var index: int=at-back; var side = Vector3(-game.track.tangents[index].z,0,game.track.tangents[index].x)
		for lane in [0.0,-3.1,3.1]:
			game.cars[blocker].position=game.track.points[index]+side*lane+Vector3.UP*0.85; blocker+=1
	check(not game._recover(a) and not a.reset_pending and a.passed==at,"Blocked road defers recovery instead of stacking cars or granting progress")
	a.finish_time=20; a.recovery_lock=0
	check(not game._recover(a),"Finished car cannot re-enter race through recovery")
	game.return_menu(); game.start_race(); game.state="race"
	# The player finishing must not stop the other fifteen racers.
	a=game.cars[0]; a.passed=game.laps*game.track.COUNT
	game._physics_process(1.0/60)
	check(game.state=="race" and a.finish_time>=0 and not paused,"Others continue after player finish")
	check(a.freeze and a.collision_layer==0,"Finished car cannot block finish line")
	game.elapsed=game.finish_deadline; game._physics_process(1.0/60)
	check(game.state=="results" and game.cars[1].did_not_finish,"Grace deadline produces explicit DNF")
	check(game.hud.panel.size.x<root.size.x,"Full results stay inside viewport")
	game.start_race(); check(game.cars.all(func(c): return not c.did_not_finish and c.finish_time<0),"Rematch clears DNF and finish state")
	print("RECOVERY TEST failures=",failures," rails=",rails.size())
	await preload("audio_drain.gd").dispose(game,self); quit(1 if failures else 0)
