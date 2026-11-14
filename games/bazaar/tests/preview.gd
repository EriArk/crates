# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene = load("res://main.tscn").instantiate();root.add_child(scene);scene.smoke_mode=true
	var output := "user://preview"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg.begins_with("--descriptor="):
			var d = JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--descriptor=")))
			if d is Dictionary:scene.visitor.appearance(d)
	DirAccess.make_dir_recursive_absolute(output)
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/arrival.png")
	scene.visitor.set_controls(false);scene.visitor.set_physics_process(false)
	scene.visitor.camera.reparent(scene);scene.visitor.camera.position=Vector3(22,22,26);scene.visitor.camera.look_at(Vector3(0,0,-2))
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/overview.png")
	scene.queue_free();for i in 3:await process_frame
	quit()
