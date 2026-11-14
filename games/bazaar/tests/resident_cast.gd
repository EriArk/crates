# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var scene: Node3D
var output := "user://resident-cast"
func _initialize() -> void:call_deferred("run")
func capture(name: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+name+".png")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.smoke_mode=true
	scene.visitor.hide();scene.visitor.set_physics_process(false);scene.visitor.set_controls(false)
	scene.population.set_physics_process(false)
	for actor in scene.population.residents+scene.population.birds:actor.node.hide();actor.player.active=false
	for child in scene.get_children():
		if child is CanvasLayer:child.hide()
	scene.visitor.camera.reparent(scene);scene.visitor.camera.global_position=Vector3(0,2.6,38)
	scene.visitor.camera.look_at(Vector3(0,0.9,28));scene.visitor.camera.fov=43
	var groups := {"humans":["Chef_Female","Kimono_Female","OldClassy_Male","Wizard","Witch","Casual_Female","Casual_Male"],"animals":["Bunny","Yeti","Dino","Frog","Birb"],"tones":["Casual_Female","Casual_Female","Casual_Female","Casual_Female","Casual_Female"]}
	for group in groups:
		var cast: Array[Dictionary]=[];var types: Array=groups[group]
		for i in types.size():
			var actor: Dictionary=scene.population.figure(types[i],Vector3((i-(types.size()-1)*0.5)*1.65,0.05,28),0.48,i%5)
			actor.player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL;cast.append(actor)
		for clip in (["Idle","Walk","Wave"] if group=="animals" else ["Idle","Walk"]):
			for actor in cast:actor.player.play(clip);actor.player.advance(0)
			for frame in 12:
				for actor in cast:actor.player.seek(actor.player.current_animation_length*frame/12.0,true)
				await capture(group+"-"+clip+"-%02d"%frame)
			for actor in cast:actor.node.rotation.y=PI/2
			await capture(group+"-"+clip+"-side")
			for actor in cast:actor.node.rotation.y=0
			print("CAST REVIEW ",group," ",clip)
		for actor in cast:actor.node.free()
	scene.square.life.stop_sound();await create_timer(0.2).timeout;scene.queue_free();await process_frame;await process_frame;quit()
