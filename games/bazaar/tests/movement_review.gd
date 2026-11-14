# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var scene: Node3D
var output := "user://movement-review"
func _initialize() -> void:call_deferred("run")
func capture(name: String) -> void:
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+name+".png")
	print("CAPTURE ",name)
func run() -> void:
	var descriptor: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg.begins_with("--descriptor="):descriptor=JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--descriptor=")))
	DirAccess.make_dir_recursive_absolute(output)
	scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.smoke_mode=true
	scene.visitor.appearance(descriptor)
	print("CALIBRATION ",scene.visitor.locomotion.stride_speed," scale=",scene.visitor.locomotion.target.global_basis.get_scale())
	scene.visitor.enter_space(scene.square.stall_layout(4).approach+Vector3(0,0.1,0),PI/2)
	for i in 12:await physics_frame
	await capture("stall-scale")
	scene.visitor.crouch_toggle=true
	for i in 12:await physics_frame
	await capture("crouch-world")
	scene.visitor.crouch_toggle=false
	# Studio samples isolate feet, shoulders and knee silhouettes from scenery.
	scene.visitor.set_physics_process(false);scene.visitor.camera.reparent(scene)
	var camera: Camera3D=scene.visitor.camera
	camera.position=Vector3(-1.0,1.4,10.7);camera.look_at(Vector3(-4.15,0.9,7.5))
	var motion=scene.visitor.locomotion
	for state in [{"name":"idle","speed":0.0,"crouch":false,"floor":true,"gait":"idle"},{"name":"walk","speed":1.5,"crouch":false,"floor":true,"gait":"walk"},{"name":"run","speed":4.4,"crouch":false,"floor":true,"gait":"run"},{"name":"sprint","speed":6.2,"crouch":false,"floor":true,"gait":"sprint"},{"name":"crouch","speed":0.0,"crouch":true,"floor":true,"gait":"idle"},{"name":"crouch-walk","speed":1.05,"crouch":true,"floor":true,"gait":"crouch"},{"name":"jump","speed":0.0,"crouch":false,"floor":false,"gait":"idle"}]:
		for frame in 30:motion.advance(1.0/60,state.speed,true,state.crouch,state.floor,state.gait)
		await capture(state.name)
	# The catalogue image is rendered from shipped geometry, with no profile art.
	for child in scene.get_children():
		if child is CanvasLayer:child.hide()
	scene.visitor.hide();scene.population.set_paused(true)
	root.size=Vector2i(800,820)
	camera.position=Vector3(11,8,19);camera.look_at(Vector3(0,1,-2));camera.fov=52
	await capture("catalogue")
	scene.square.life.stop_sound();scene.queue_free();for i in 3:await process_frame
	quit()
