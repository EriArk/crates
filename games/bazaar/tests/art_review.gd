# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
## Capture identical views in successive builds using the same cameras and resolution.
var scene
var camera := Camera3D.new()
var directory := OS.get_environment("BAZAAR_ART_OUTPUT")

func _initialize() -> void:
	run.call_deferred()

func capture(name: String, eye: Vector3, target: Vector3, fov: float) -> void:
	camera.global_position=eye
	camera.look_at(target)
	camera.fov=fov
	camera.make_current()
	await save_view(name)

func save_view(name: String) -> void:
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	var err := frame.save_png(directory.path_join(name+".png"))
	assert(err==OK)
	print("ART_FRAME ",name," ",frame.get_size()," draws=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))

func run() -> void:
	if directory.is_empty() or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(directory)
	scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.smoke_mode=true
	if not scene.personal and OS.get_environment("BAZAAR_ART_GAMEPLAY")=="1":
		var timeout:=Time.get_ticks_msec()+5000
		while not is_instance_valid(scene.visitor.visual) and Time.get_ticks_msec()<timeout:await process_frame
		if scene.modal:scene.hide_menu()
		await save_view("arrival")
	scene.visitor.set_physics_process(false)
	scene.visitor.hide()
	for child in scene.get_children():
		if child is CanvasLayer:child.hide()
	scene.add_child(camera);camera.far=1200
	match scene.world_kind:
		"island":
			await capture("island",Vector3(-24,3.5,30),Vector3(8,3,-27),56)
			await capture("shore",Vector3(8,3,38),Vector3(28,2,64),54)
		"station":
			await capture("station",Vector3(6,2.3,23),Vector3(-8,8,-24),58)
		_:
			await capture("festival",Vector3(1,2.5,20),Vector3(-.4,1.45,-4),56)
			await capture("shops",Vector3(47,2.6,-12),Vector3(45,2.1,-34),56)
			await capture("counter",Vector3(1.1,1.8,-8),Vector3(-5.9,1.3,-10.55),42)
	await scene.leave_bazaar()
