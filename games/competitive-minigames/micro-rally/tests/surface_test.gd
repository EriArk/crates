# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures = 0
func check(ok: bool, label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	game.state="test"; game.set_physics_process(false)
	for other in game.cars: other.freeze=true; other.collision_layer=0
	var car=game.cars[0]; car.freeze=false; car.collision_layer=2
	var worst = INF; var cases = 0
	# Enter the road across both shoulders on six bends, slowly and at drift speed.
	# No bot, recovery, velocity injection after release, or teleport during the run.
	for at in [45,75,130,185,225,275]:
		for side in [-1,1]:
			for speed in [4.0,14.0]:
				var lateral=Vector3(-game.track.tangents[at].z,0,game.track.tangents[at].x)*side
				var start: Vector3=game.track.points[at]+lateral*8.5
				var hit=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start+Vector3.UP*15,start-Vector3.UP*15,1))
				check(not hit.is_empty(),"Shoulder has physical ground")
				start.y=hit.position.y+0.72
				var pose=Transform3D(Basis(Vector3.UP,atan2(lateral.x,lateral.z)),start)
				car.reset_at(pose); car.steer_input=0; car.throttle=1; car.desired=-lateral; car.immune=100; car.disabled_time=0; car.handbrake=false; car.brake=0
				await physics_frame; await physics_frame
				car.linear_velocity=-lateral*speed
				for frame in 100: await physics_frame
				var travel: float=(car.position-start).dot(-lateral); worst=minf(worst,travel); cases+=1
				check(travel>7.0,"Shoulder crossing at %d side %d speed %.0f moved only %.2f m" % [at,side,speed,travel])
				check(car.position.is_finite() and car.position.y>0,"Crossing remains on the physical surface")
	var rail_runs=0
	for at in game.track.COUNT:
		if not game.track._bridge_segment(at) or game.track._bridge_segment(at-1): continue
		var start_at: int=(at+2)%game.track.COUNT
		for side in [-1,1]:
			var tangent: Vector3=game.track.tangents[start_at]
			var lateral=Vector3(-tangent.z,0,tangent.x)*side
			var start: Vector3=game.track.points[start_at]+lateral*5.05+Vector3.UP*0.72
			car.reset_at(Transform3D(Basis(Vector3.UP,atan2(-tangent.x,-tangent.z)),start))
			car.steer_input=0; car.throttle=1; car.desired=tangent; car.immune=100; car.disabled_time=0
			await physics_frame; await physics_frame
			car.linear_velocity=tangent*12+lateral*2
			for frame in 100:
				var index: int=game.track.nearest(car.position)
				# Push gently into the curved wall throughout the run, forcing seam contacts.
				car.steer_towards((game.track.tangents[index]+lateral*0.06).normalized())
				await physics_frame
			var travel: float=(car.position-start).dot(tangent); rail_runs+=1
			check(travel>9,"Glancing along bridge %d side %d moved %.2f m" % [at,side,travel])
	print("SURFACE TEST failures=",failures," cases=",cases," rail_runs=",rail_runs," worst_travel=",worst," engine=",ProjectSettings.get_setting("physics/3d/physics_engine"))
	await preload("audio_drain.gd").dispose(game,self); quit(1 if failures else 0)
