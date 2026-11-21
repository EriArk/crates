# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var scene: Node3D
var output := "user://population-review"
func _initialize() -> void:call_deferred("run")
func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+name+".png")
	print("CAPTURE ",name)
func view(at: Vector3, target: Vector3) -> void:
	scene.visitor.camera.global_position=at;scene.visitor.camera.look_at(target)
func run() -> void:
	scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.smoke_mode=true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	scene.visitor.set_physics_process(false);scene.visitor.set_controls(false)
	scene.visitor.camera.reparent(scene)
	scene.visitor.hide()
	for child in scene.get_children():
		if child is CanvasLayer:child.hide()
	scene.visitor.position=Vector3(0,0,13);scene.population.update_activity()
	view(Vector3(2,3.5,23),Vector3(-2,1.0,9));await create_timer(1).timeout;await capture("park")
	scene.visitor.position=Vector3(-5.9,0,17);scene.population.update_activity()
	view(Vector3(-3.8,2.1,20),Vector3(-7.65,1.0,17));await capture("merchant-bunny")
	view(Vector3(-3.8,2.1,10),Vector3(-7.65,1.0,7));await capture("merchant-yeti")
	scene.visitor.position=Vector3(210,0,0);scene.population.update_activity()
	view(Vector3(210,1.9,0.8),Vector3(210,1.0,-3.45));await capture("tea-merchant")
	scene.visitor.position=Vector3(46,0,-20);scene.population.update_activity()
	view(Vector3(46,2.4,-9),Vector3(46,0.8,-22));await capture("town-walkers")
	scene.visitor.position=Vector3(-10,0,0);scene.population.update_activity()
	view(Vector3(-5,3,6),Vector3(-10,3.5,0));await capture("birds")
	# Deterministic time samples of actual native rigs and movement, not screenshots
	# of a rest pose labelled as a walking review.
	var pop=scene.population;pop.set_physics_process(false)
	scene.visitor.position=Vector3(0,0,15);pop.update_activity()
	view(Vector3(1,2.3,23),Vector3(-4,1.0,15))
	for actor in pop.residents+pop.birds:actor.player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for frame in 48:
		for step in 5:
			pop._physics_process(1.0/60)
			for actor in pop.residents+pop.birds:
				if actor.active:actor.player.advance(1.0/60)
		await capture("motion-%03d"%frame)
	scene.square.life.stop_sound();await create_timer(0.15).timeout;scene.queue_free();await process_frame;await process_frame;quit()
