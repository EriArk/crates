# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures:=0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.bot_count=0; game.start_race(); game.set_physics_process(false)
	var road=game.track
	var car=game.player()
	var physics=game.get_world_3d().direct_space_state
	for spec in road.mud.PATCHES:
		var at: int=spec[0]
		var side:=Vector3(-road.tangents[at].z,0,road.tangents[at].x)
		var center: Vector3=road.points[at]+side*float(spec[1])
		var hit=physics.intersect_ray(PhysicsRayQueryParameters3D.create(center+Vector3.UP*6,center-Vector3.UP*6,1))
		check(not hit.is_empty(),"Ground under mud patch %d" % at)
		if hit.is_empty(): continue
		var grade: float=road.ground_height(center.x,center.z,at,true)-float(spec[4])
		var offset: float=hit.position.y-grade
		check(signf(offset)==signf(spec[4]) and absf(offset)>0.13,"Playable relief at %d measures %.2f" % [at,offset])
		check(absf(hit.position.y-road.surface_height(center.x,center.z))<0.01,"Visible and physical surfaces match")
		var bypass: Vector3=road.points[at]-side*signf(spec[1] if spec[1]!=0 else 1)*(road.half_width(at)-0.8)
		check(absf(road.mud.height(Vector2(bypass.x,bypass.z)))<0.02,"An unobstructed line bypasses %d" % at)
	var results: Dictionary={}
	for at in [80,251]:
		var runs: Array=[]
		for speed in [6.0,22.0]:
			var forward: Vector3=road.tangents[at]
			var start: Vector3=road.points[at]-forward*10.0
			start.y=road.surface_height(start.x,start.z)+0.62
			car.reset_at(Transform3D(Basis.looking_at(forward,Vector3.UP),start))
			car.freeze=false; car.throttle=0; car.brake=0; car.handbrake=false
			for frame in 50: await physics_frame
			check(car.grounded,"Car starts settled on its wheels")
			car.linear_velocity=forward*speed
			var airborne:=0; var longest:=0; var crossed:=false; var landed:=false
			for frame in 240:
				car.throttle=clampf((float(speed)-car.linear_velocity.dot(forward))*0.40,0,1)
				await physics_frame
				var progress: float=(car.position-road.points[at]).dot(forward)
				if progress>0: crossed=true
				if progress> -3 and not car.grounded:
					airborne+=1; longest=maxi(longest,airborne)
				else:
					if airborne>0 and car.grounded and crossed: landed=true
					airborne=0
				if progress>12: break
			runs.append(longest)
			check(crossed,"Car clears the crest at %.0f m/s" % speed)
			if speed>10: check(landed and longest>=3,"Fast car takes off and lands on its suspension")
		check(runs[0]<runs[1],"Speed controls the length of the hop")
		results[at]=runs
	print("MUD RELIEF ",JSON.stringify({"failures":failures,"airborne_frames":results,"patches":road.mud.PATCHES.size()}))
	await preload("audio_drain.gd").dispose(game,self)
	quit(1 if failures else 0)
