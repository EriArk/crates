# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var scene: Node3D
var output:="user://personal-review"
func _initialize() -> void:call_deferred("run")
func capture(name: String) -> void:
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+scene.world_kind+"-"+name+".png")
	print("CAPTURE ",scene.world_kind,"-",name," draws=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
func run() -> void:
	var descriptor: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg.begins_with("--descriptor="):descriptor=JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--descriptor=")))
	DirAccess.make_dir_recursive_absolute(output)
	scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.smoke_mode=true
	scene.visitor.client.disconnect_host()
	scene.visitor.client.unavailable.disconnect(scene.visitor.clear_identity)
	if not descriptor.is_empty():scene.visitor.appearance(descriptor)
	for i in 40:await physics_frame
	await capture("arrival")
	scene.visitor.enter_space(Vector3(0,0.6,43) if scene.world_kind=="island" else Vector3(0,0.2,-27),PI if scene.world_kind=="island" else 0.3)
	for i in 40:await physics_frame
	await capture("edge")
	scene.visitor.set_controls(false);scene.visitor.set_physics_process(false)
	for child in scene.get_children():
		if child is CanvasLayer:child.hide()
	scene.visitor.hide();scene.visitor.camera.reparent(scene);var camera: Camera3D=scene.visitor.camera
	camera.far=1000;camera.fov=55;camera.position=Vector3(68,70,85) if scene.world_kind=="island" else Vector3(55,48,65);camera.look_at(Vector3(0,0,0))
	await capture("overview")
	root.size=Vector2i(900,650)
	camera.position=Vector3(48,48,62) if scene.world_kind=="island" else Vector3(39,31,48);camera.look_at(Vector3(0,2,0));camera.fov=58
	await capture("catalogue")
	scene.queue_free();for i in 3:await process_frame
	quit()
