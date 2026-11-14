# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures: Array[String]=[]
func check(ok: bool, message: String) -> void:
	if not ok and not failures.has(message):failures.append(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.smoke_mode=true
	scene.square.life.stop_sound() # This suite does not exercise audio.
	var pop=scene.population
	pop.set_physics_process(false);scene.visitor.set_physics_process(false)
	await physics_frame;await physics_frame
	check(pop.residents.size()==19 and pop.birds.size()==6,"Fixed population budget")
	var merchants := 0;var walkers := 0;var route_samples := 0;var humans := 0
	var space=scene.get_world_3d().direct_space_state
	var shape := SphereShape3D.new();shape.radius=0.34
	var query := PhysicsShapeQueryParameters3D.new();query.shape=shape;query.exclude=[scene.visitor.get_rid()]
	for actor in pop.residents:
		if actor.species in pop.HUMAN_SPECIES:humans+=1
		for clip in (["Idle","Walk","Wave"] if actor.player.has_animation("Wave") else ["Idle","Walk"]):check(actor.player.has_animation(clip),"Own-rig clip exists: "+actor.species+" "+clip)
		var sk: Skeleton3D=actor.visual.find_child("Skeleton3D",true,false)
		check(sk!=null,"Imported skeleton present")
		if sk!=null:
			var rests: Array[Transform3D]=[]
			for i in sk.get_bone_count():rests.append(sk.get_bone_rest(i))
			for clip in (["Idle","Walk","Wave"] if actor.player.has_animation("Wave") else ["Idle","Walk"]):
				actor.player.play(clip);actor.player.advance(0)
				for phase in 12:
					actor.player.seek(actor.player.current_animation_length*phase/12.0,true)
					for i in sk.get_bone_count():
						check(sk.get_bone_rest(i).is_equal_approx(rests[i]),"Native bind matrices unchanged")
						check(sk.get_bone_pose_rotation(i).is_finite(),"Finite native animation")
		if actor.route.is_empty():merchants+=1;continue
		walkers+=1
		for segment in actor.route.size():
			var a: Vector3=actor.route[segment];var b: Vector3=actor.route[(segment+1)%actor.route.size()]
			var steps := ceili(a.distance_to(b)/0.25)
			for i in steps+1:
				var point: Vector3=pop.ground(a.lerp(b,float(i)/steps))
				query.transform=Transform3D(Basis.IDENTITY,point+Vector3(0,0.65,0));route_samples+=1
				check(space.intersect_shape(query,1).is_empty(),"Route clear of static obstacles: "+str(point))
	check(humans==12,"Human majority: twelve humans and seven animal folk")
	check(merchants==12 and walkers==7,"Merchant / pedestrian roles")
	var walker: Dictionary=pop.residents[9]
	walker.wait=0;scene.visitor.position=walker.node.position+Vector3(0.5,0,0)
	var before: Vector3=walker.node.position
	for i in 120:pop.update_resident(walker,1.0/60)
	check(walker.node.position.is_equal_approx(before) and walker.clip=="Idle","Pedestrian yields to visitor")
	scene.visitor.position=Vector3(0,0,35)
	for i in 300:pop.update_resident(walker,1.0/60)
	check(walker.node.position.distance_to(before)>2.5 and walker.clip=="Walk","Pedestrian resumes walking")
	var trader: Dictionary=pop.residents[2];trader.cooldown=0
	scene.visitor.position=trader.node.position+Vector3(1,0,0);pop.update_resident(trader,0.1)
	check(trader.clip=="Wave" and trader.cooldown>10,"Nearby trader greets")
	for i in 300:pop.update_resident(trader,1.0/60)
	check(trader.clip=="Idle","Greeting returns to idle during cooldown")
	var bird: Dictionary=pop.birds[0];scene.visitor.position=bird.node.position-Vector3(0,2,0)
	pop.update_bird(bird,0.1);before=bird.node.position
	for i in 120:pop.update_bird(bird,1.0/60)
	check(bird.alarm>0 and bird.node.position.y>before.y+2 and bird.clip=="Fast_Flying","Bird climbs away from nearby visitor")
	scene.visitor.position=Vector3(250,0,1);pop.update_activity()
	check(not pop.residents[0].active and not pop.residents[0].player.active and not pop.residents[0].node.visible,"Distant park residents sleep indoors")
	check(pop.residents[8].active,"Current shop merchant stays active")
	scene.visitor.position=Vector3(-5.9,0,-12);scene._process(0)
	check(scene.nearest.get("service")=="stall","Merchant interaction reachable from the aisle")
	scene.inspect_spot()
	check(scene.modal and scene.services.visible and scene.services.page=="goods","Stall opens the goods service")
	scene.hide_menu()
	scene.visitor.position=Vector3(250,0,1);pop.update_activity()
	scene.show_menu();check(pop.ambient_paused and not pop.residents[8].player.active,"Menu pauses residents")
	scene.hide_menu();check(not pop.ambient_paused and pop.residents[8].player.active,"Menu resumes residents")
	var result := {"pass":failures.is_empty(),"failures":failures,"residents":19,"birds":6,"route_samples":route_samples}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			var file := FileAccess.open(arg.trim_prefix("--output="),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "))
	print(JSON.stringify(result))
	scene.square.life.stop_sound();await create_timer(0.15).timeout;scene.queue_free();await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)
