# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var scene: Node3D
var output := "user://resident-world"
func _initialize() -> void:call_deferred("run")
func capture(name: String, at: Vector3, target: Vector3) -> void:
	scene.visitor.camera.global_position=at;scene.visitor.camera.look_at(target)
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+name+".png")
	print("WORLD REVIEW ",name)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.smoke_mode=true
	scene.visitor.hide();scene.visitor.set_physics_process(false);scene.visitor.set_controls(false)
	scene.visitor.camera.reparent(scene)
	for child in scene.get_children():
		if child is CanvasLayer:child.hide()
	for entry in [{"name":"dino-stall","position":Vector3(-5.9,0,-7),"camera":Vector3(-3.8,1.7,-4.5),"target":Vector3(-7.65,1,-7)},
		{"name":"birb-stall","position":Vector3(5.9,0,-17),"camera":Vector3(3.8,1.7,-14.5),"target":Vector3(7.65,1,-17)},
		{"name":"garden-walker","position":Vector3(-39,0,-20),"camera":Vector3(-34,1.8,-17),"target":Vector3(-39,0.8,-23)},
		{"name":"human-merchant","position":Vector3(210,0,0),"camera":Vector3(210,1.6,0),"target":Vector3(210,1,-3.45)}]:
		scene.visitor.position=entry.position;scene.population.update_activity()
		await create_timer(0.7).timeout
		await capture(entry.name,entry.camera,entry.target)
	scene.square.life.stop_sound();await create_timer(0.2).timeout;scene.queue_free();await process_frame;await process_frame;quit()
