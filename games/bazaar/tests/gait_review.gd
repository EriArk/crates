# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
## Optional film: provide the previous helper only in an isolated review checkout.
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var descriptor: Dictionary={};var output := "user://gait-review"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--descriptor="):descriptor=JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--descriptor=")))
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	assert(not descriptor.is_empty());DirAccess.make_dir_recursive_absolute(output)
	var stage := Node3D.new();root.add_child(stage);root.msaa_3d=Viewport.MSAA_DISABLED
	var environment := WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("26343e")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=0.7;stage.add_child(environment)
	var light := DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-25,0);light.shadow_enabled=false;stage.add_child(light)
	var motions: Array=[]
	for i in 4:
		var pivot := Node3D.new();stage.add_child(pivot);pivot.position=Vector3((i%2)*3.6-1.8,0,(i/2)*3.8-1.9)
		var floor_mesh := MeshInstance3D.new();var plane := PlaneMesh.new();plane.size=Vector2(3.4,3.2);floor_mesh.mesh=plane
		var mat := StandardMaterial3D.new();mat.albedo_color=Color("62757b");mat.roughness=1;floor_mesh.material_override=mat;pivot.add_child(floor_mesh)
		var avatar=load("res://addons/traineros/avatar_presenter.gd").from_descriptor(descriptor);pivot.add_child(avatar);avatar.scale=Vector3.ONE*1.8;avatar.rotation.y=PI/2
		var helper=load("res://addons/traineros/previous_locomotion.gd" if i%2==0 else "res://addons/traineros/avatar_locomotion.gd").new();pivot.add_child(helper);assert(helper.bind(avatar));motions.append(helper)
		var label := Label3D.new();label.text=("BEFORE" if i%2==0 else "AFTER")+("  WALK" if i<2 else "  RUN")
		label.position=Vector3(0,2.35,0);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.font_size=38;label.pixel_size=0.006;pivot.add_child(label)
	var camera := Camera3D.new();stage.add_child(camera);camera.position=Vector3(0,8,11);camera.look_at(Vector3(0,0.6,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=8.7;camera.current=true
	for frame in 12:
		for i in 4:motions[i].advance(1.0/12,1.5 if i<2 else 4.4,true,false,true,"walk" if i<2 else "run")
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/frame-%03d.png"%frame)
	stage.queue_free();await process_frame;quit()
