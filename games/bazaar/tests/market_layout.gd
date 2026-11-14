# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures: Array[String]=[]
func check(ok: bool, message: String) -> void:
	if not ok:failures.append(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.smoke_mode=true
	for i in 6:await physics_frame
	scene.visitor.set_physics_process(false)
	var query := PhysicsShapeQueryParameters3D.new();var capsule := CapsuleShape3D.new()
	capsule.radius=scene.visitor.motor.radius;capsule.height=scene.visitor.motor.standing_height-0.04
	query.shape=capsule;query.exclude=[scene.visitor.get_rid()]
	var physics=scene.get_world_3d().direct_space_state
	var positions: Array[Vector3]=[]
	for slot in range(1,13):
		var layout: Dictionary=scene.square.stall_layout(slot)
		scene.visitor.position=layout.approach;scene._process(0)
		check(scene.nearest.get("slot")==slot,"Approach reaches correct persistent slot: "+str(slot))
		query.transform=Transform3D(Basis.IDENTITY,layout.approach+Vector3(0,0.94,0))
		check(physics.intersect_shape(query,1).is_empty(),"Player fits at counter: "+str(slot))
		for other in positions:check(other.distance_to(layout.position)>=3.0,"Stall canopies do not overlap")
		positions.append(layout.position)
	# A full-height visitor can cross the fountain court between districts.
	for side in [-1,1]:
		for x in range(4,14):
			query.transform=Transform3D(Basis.IDENTITY,Vector3(side*x,0.94,0))
			check(physics.intersect_shape(query,1).is_empty(),"Cross route stays clear")
	for actor in scene.population.residents:
		var bounds: AABB=scene.population.figure_bounds[actor.species]
		var height: float=bounds.size.y*actor.visual.scale.y
		check(height>1.35 and height<1.7,"Resident remains below visitor: "+actor.species)
	print(JSON.stringify({"success":failures.is_empty(),"failures":failures,"slots":12,"resident_heights":19}))
	query=null;capsule=null;physics=null
	scene.square.life.stop_sound();await create_timer(0.15).timeout;scene.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
