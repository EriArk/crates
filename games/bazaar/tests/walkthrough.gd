# SPDX-License-Identifier: GPL-3.0-or-later
extends Node
var failures: Array[String] = []
var output := "user://review"
func check(ok: bool, message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func frames(count: int) -> void:
	for i in count:await get_tree().physics_frame
func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new();event.physical_keycode=code;event.pressed=pressed;Input.parse_input_event(event)
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(output+"/"+name+".png")==OK,"Capture "+name)
func textured(node: Node) -> bool:
	# Some fountain surfaces intentionally use a plain water material. Every
	# imported model must still contain its actual palette-textured surfaces.
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var mat = node.get_active_material(i)
			if mat is StandardMaterial3D and mat.albedo_texture!=null:return true
	for child in node.get_children():
		if textured(child):return true
	return false
func run(world: Node3D) -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	await frames(12)
	check(world.square.models.size()>=12,"Imported town assets loaded")
	for asset in world.square.models:
		var sample = world.square.models[asset].instantiate()
		if not asset.begins_with("nature/"):check(textured(sample),"Palette texture imported: "+asset)
		sample.free()
	check(world.visitor.is_on_floor(),"Visitor rests on real collision floor")
	check(world.visitor.fallback.visible,"Missing host uses anonymous appearance")
	# Projection and collision are checked independently of the avatar art.
	check(world.visitor.camera.keep_aspect==Camera3D.KEEP_HEIGHT,"Landscape camera preserves vertical FOV")
	check(absf(world.visitor.camera.fov-58.7155)<0.02,"90 horizontal at 16:9 is converted to vertical FOV")
	var window := get_window();var original_size := window.size
	for viewport_size in [Vector2i(960,540),Vector2i(960,600),Vector2i(1260,540)]:
		window.size=viewport_size;await get_tree().process_frame;await frames(2)
		for angle in [75.0,90.0,105.0]:
			world.fov_slider.value=angle;await frames(2)
			var head: Vector2=world.visitor.camera.unproject_position(world.visitor.position+Vector3(0,1.75,0))
			var feet: Vector2=world.visitor.camera.unproject_position(world.visitor.position+Vector3(0,0.03,0))
			var viewport: Rect2=get_viewport().get_visible_rect()
			check(viewport.has_point(head) and viewport.has_point(feet),"Character fits FOV/aspect: "+str(viewport_size)+" / "+str(angle))
			var fraction: float=absf(feet.y-head.y)/viewport.size.y
			check(fraction>0.16 and fraction<0.42,"Useful third-person framing")
	window.size=original_size;world.fov_slider.value=90;await frames(3)
	var wall=world.square.block(world.visitor.position+Vector3(0,1.2,1.0),Vector3(4,3,0.2),"888888")
	await frames(5)
	check(world.visitor.arm.get_hit_length()<1.25,"Camera retracts before a wall")
	check(world.visitor.camera.global_position.z<wall.global_position.z-0.1,"Camera stays on visitor side of wall")
	wall.queue_free();await frames(5)
	check(world.visitor.arm.get_hit_length()>5.0,"Camera returns after obstruction clears")
	await capture("arrival")
	var start: Vector3=world.visitor.position
	key(KEY_W,true);await frames(240);key(KEY_W,false);await frames(12)
	check(start.z-world.visitor.position.z>5,"Keyboard moves through the square")
	check(world.visitor.position.z>2.2,"Fountain collision prevents walking through basin")
	key(KEY_D,true);await frames(110);key(KEY_D,false);await frames(12)
	check(world.visitor.position.x>3.5,"Can walk around the fountain")
	var before: Vector3=world.visitor.position
	world.show_menu();key(KEY_W,true);await frames(30);key(KEY_W,false)
	check(world.visitor.position.distance_to(before)<0.05,"Pause stops movement")
	check(world.square.life.fountain_audio.stream_paused,"Pause silences ambience")
	world.hide_menu()
	world.visitor.position=Vector3(0,0.1,82.5);world.visitor.velocity=Vector3.ZERO
	key(KEY_S,true);await frames(90);key(KEY_S,false);await frames(12)
	check(world.visitor.position.z<85.1,"World boundary is closed")
	var touch := InputEventScreenTouch.new();touch.index=4;touch.pressed=true;touch.position=Vector2(100,400)
	world.touch_pad._unhandled_input(touch)
	var drag := InputEventScreenDrag.new();drag.index=4;drag.position=Vector2(100,342)
	world.touch_pad._unhandled_input(drag)
	check(world.visitor.touch_move.y < -0.9,"Touch stick sets movement")
	world.show_menu();check(world.visitor.touch_move==Vector2.ZERO,"Pause clears held touch")
	world.hide_menu()
	world.visitor.position=Vector3(-3.8,0.1,-4.8);world.visitor.velocity=Vector3.ZERO;await frames(12)
	check(not world.nearest.is_empty(),"Nearby sign can be inspected")
	world.inspect_spot();check(not world.modal and world.speech.visible and world.visitor.input_enabled,"Stall describes development without spending")
	check(Rect2(Vector2.ZERO,get_viewport().get_visible_rect().size).encloses(world.speech.get_global_rect()),"Field caption fits viewport")
	await capture("stall-info")
	world.hide_menu();world.visitor.position=Vector3(-1.0,0.1,7.5);world.visitor.yaw=-0.15
	world.visitor.pitch=-0.55;world.visitor.arm.spring_length=6.2;await frames(12)
	await capture("fountain-square")
	# Explicit test-only descriptor belongs to synthetic fixture data, not a save/profile.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--descriptor="):
			var descriptor = JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--descriptor=")))
			check(descriptor is Dictionary,"Avatar fixture descriptor parsed")
			if descriptor is Dictionary:
				world.visitor.appearance(descriptor);await frames(12)
				check(is_instance_valid(world.visitor.visual) and not world.visitor.fallback.visible,"Shared SDK avatar loaded")
				check(is_instance_valid(world.visitor.locomotion) and world.visitor.locomotion.ready_to_animate,"Pack retargeted onto SDK skeleton")
				await capture("shared-avatar")
				var motion=world.visitor.locomotion
				var thigh: int=motion.target.find_bone("thigh.L")
				var pose: Quaternion=motion.target.get_bone_pose_rotation(thigh)
				world.visitor.touch_move=Vector2(0,-1);await frames(22)
				check(motion.current=="Jog_Fwd","Default full input selects the run clip")
				check(pose.angle_to(motion.target.get_bone_pose_rotation(thigh))>0.04,"Retargeted leg moves")
				world.visitor.touch_move=Vector2.ZERO
				await capture("walk")
				world.visitor.clear_identity("revoked");await frames(2)
				check(world.visitor.visual==null and world.visitor.fallback.visible and world.visitor.locomotion==null,"Revocation clears identity and animation immediately")
	# Rooms are actual enter/exit destinations, not just modal descriptions.
	for shop in world.square.shop_exits:
		world.visitor.position=shop.door+Vector3(0,0.12,0);world.visitor.velocity=Vector3.ZERO;await frames(8)
		check(world.nearest.has("arrival"),"Shop door reachable: "+shop.title)
		world.inspect_spot();await frames(8)
		check(world.visitor.position.x>180 and world.visitor.is_on_floor(),"Entered furnished room: "+shop.title)
		check(world.square.district(world.visitor.position)==shop.title,"Interior identity")
		check(not world.nearest.has("arrival"),"Entry does not immediately offer exit")
		check(is_equal_approx(world.visitor.arm.spring_length,2.4*world.visitor.camera_scale),"Interior camera shortens")
		world.visitor.position=shop.room+Vector3(0,0.12,3.5);world.visitor.velocity=Vector3.ZERO;await frames(8)
		world.inspect_spot();await frames(8)
		check(world.visitor.position.x<100,"Returned through shop exit")
		check(is_equal_approx(world.visitor.arm.spring_length,3.0*world.visitor.camera_scale),"Outdoor camera restored")
	# Both the island and connecting paths have a floor; no former plaza wall.
	for at in [Vector3(0,0.15,28),Vector3(25,0.15,0),Vector3(38,0.15,-9),Vector3(-39,0.15,-11),Vector3(0,0.15,50)]:
		world.visitor.position=at;world.visitor.velocity=Vector3.ZERO;await frames(12)
		check(world.visitor.is_on_floor(),"District path supports visitor: "+str(at))
	var land=world.square.landscape
	check(land.grass_positions.size()>10000 and land.grass_batches<200,"Bounded chunked meadow covers island")
	check(land.surface_height(Vector3(-13,0,-51))>4,"Island has real hill relief")
	for p in land.grass_positions:
		check(land.grass_allowed(Vector2(p.x,p.z)),"Grass leaves paved routes clear")
	var uphill := Vector3(-13,0,-51);uphill.y=land.surface_height(uphill)+0.1
	world.visitor.position=uphill;world.visitor.velocity=Vector3.ZERO;await frames(16)
	check(world.visitor.is_on_floor() and world.visitor.position.y>4,"Visitor stands on real hill collision")
	var clock_before: float=world.square.life.elapsed
	await frames(8)
	await get_tree().process_frame
	check(world.square.life.elapsed>clock_before,"Fountain simulation advances")
	world.visitor.set_controls(false);world.visitor.set_physics_process(false)
	world.visitor.camera.reparent(world);world.visitor.camera.position=Vector3(125,130,155)
	world.visitor.camera.look_at(Vector3(0,0,-2));await frames(4);await capture("overview")
	var file := FileAccess.open(output+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"failures":failures,"engine":Engine.get_version_info().string,"renderer":DisplayServer.get_name()},"  "));file.close()
	print("BAZAAR CHECKS: ","PASS" if failures.is_empty() else "FAIL")
	await world.leave_bazaar(0 if failures.is_empty() else 1)
