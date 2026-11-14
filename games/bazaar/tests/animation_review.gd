# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
## Isolated synthetic-avatar comparison. No profile/model is bundled.
const Presenter=preload("res://addons/traineros/avatar_presenter.gd")
const Motion=preload("res://scripts/locomotion.gd")
var output := "user://animation-review"
var figures: Array[Node3D] = []
var motions: Array[Node] = []
var legacy := false
var include_world := false
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var descriptor: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		if arg=="--legacy":legacy=true
		if arg=="--world":include_world=true
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg.begins_with("--descriptor="):descriptor=JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--descriptor=")))
	if descriptor.is_empty():push_error("Synthetic descriptor required");quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	var stage := Node3D.new();root.add_child(stage)
	var environment := WorldEnvironment.new();var env := Environment.new();environment.environment=env
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("26343e")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("dbe6f3");env.ambient_light_energy=0.7
	stage.add_child(environment)
	var light := DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-35,0);light.light_energy=1.1;stage.add_child(light)
	var floor_mesh := MeshInstance3D.new();var plane := PlaneMesh.new();plane.size=Vector2(7,4);floor_mesh.mesh=plane
	var mat := StandardMaterial3D.new();mat.albedo_color=Color("6c7c82");mat.roughness=1;floor_mesh.material_override=mat;stage.add_child(floor_mesh)
	var labels := CanvasLayer.new();stage.add_child(labels)
	for i in 4:
		var pivot := Node3D.new();stage.add_child(pivot);pivot.position.x=(i-1.5)*1.05;figures.append(pivot)
		var avatar=Presenter.from_descriptor(descriptor);pivot.add_child(avatar)
		var motion=(load("res://tests/legacy_locomotion.gd") if legacy else Motion).new();pivot.add_child(motion)
		motions.append(motion)
		if i==0:
			if avatar.animation_player!=null:avatar.animation_player.stop()
			motion.skeleton(avatar).reset_bone_poses()
		else:
			assert(motion.bind(avatar))
			for frame in 90:motion.advance(1.0/60.0,[0.0,0.0,2.4,4.8][i],true)
		var label := Label.new();label.text=["SDK REST", "IDLE", "WALK", "JOG"][i];label.position=Vector2((i+0.5)*root.get_visible_rect().size.x/4.0-55,24)
		label.add_theme_font_size_override("font_size",20);labels.add_child(label)
	var camera := Camera3D.new();stage.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.4
	camera.position=Vector3(0,0.5,4);camera.look_at(Vector3(0,0.5,0));camera.current=true
	for view in ["front","side","back"]:
		for figure in figures:figure.rotation.y=0 if view=="front" else PI/2 if view=="side" else PI
		for i in 3:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/"+view+".png")
		print("ANIMATION REVIEW ",view)
	if not legacy:
		for figure in figures:figure.rotation.y=0.35
		for phase in 24:
			for i in range(1,4):
				var motion=motions[i];var clip: String=["","Idle","Walk","Jog_Fwd"][i]
				motion.player.play(clip,0);motion.player.seek(motion.player.get_animation(clip).length*phase/24.0,true);motion.player.advance(0)
				motion.apply_pose(1.0)
			for i in 2:await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output+"/cycle-%02d.png"%phase)
		print("ANIMATION REVIEW full cycles: 24 phases")
	stage.queue_free()
	for i in 3:await process_frame
	if include_world:
		var world=load("res://main.tscn").instantiate();root.add_child(world);world.smoke_mode=true
		world.visitor.appearance(descriptor);world.visitor.enter_space(Vector3(0,0.1,13),0)
		for i in 30:await physics_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/in-world.png")
		print("ANIMATION REVIEW actual world camera")
		await world.leave_bazaar()
	else:quit()
