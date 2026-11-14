# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var scene: Node3D
var output := "user://preview"
func _initialize() -> void:call_deferred("run")
func capture(name: String) -> void:
	for i in 3:await physics_frame
	for i in 2:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+name+".png")
	print("CAPTURE ",name," draws=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
func run() -> void:
	scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.smoke_mode=true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg.begins_with("--descriptor="):
			var d=JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--descriptor=")))
			if d is Dictionary:scene.visitor.appearance(d)
	DirAccess.make_dir_recursive_absolute(output)
	scene.visitor.position=Vector3(0,0.1,15);scene.visitor.pitch=-0.25
	await capture("park-arrival")
	scene.visitor.position=Vector3(46,0.1,-12)
	await capture("town")
	scene.visitor.position=Vector3(210,0.1,2.5)
	await capture("tea-interior")
	scene.visitor.position=Vector3(-39,0.1,-19)
	await capture("gardens")
	scene.visitor.position=Vector3(-18,0.1,-25);scene.visitor.yaw=0.15;scene.visitor.pitch=-0.05
	await capture("meadow-hills")
	scene.visitor.position=Vector3(0,0.1,54);scene.visitor.yaw=PI;scene.visitor.pitch=-0.2
	await capture("harbor")
	scene.visitor.position=Vector3(0,0.1,10);scene.visitor.yaw=PI;scene.visitor.pitch=-0.1;scene.visitor.arm.spring_length=2.2
	await capture("avatar-idle")
	scene.visitor.touch_move=Vector2(0,-0.7)
	for i in 3:
		for j in 10:await physics_frame
		await capture("avatar-walk-"+str(i))
	scene.visitor.touch_move=Vector2.ZERO
	scene.visitor.set_controls(false);scene.visitor.set_physics_process(false)
	for prop in scene.square.find_children("*","GeometryInstance3D",true,false):prop.visibility_range_end=0
	scene.visitor.camera.reparent(scene);scene.visitor.camera.position=Vector3(125,130,155);scene.visitor.camera.look_at(Vector3.ZERO)
	await capture("island")
	scene.visitor.camera.position=Vector3(27,28,35);scene.visitor.camera.look_at(Vector3.ZERO)
	await capture("park-layout")
	scene.queue_free();for i in 3:await process_frame
	quit()
