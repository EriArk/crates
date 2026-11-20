# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
## Exercise Bazaar's live subscription or a revision-13 resolved test model.
var failures: Array[String]=[]
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:run.call_deferred()

func run() -> void:
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.smoke_mode=true
	scene.square.life.stop_sound()
	var walker=scene.visitor
	var fixture := OS.get_environment("BAZAAR_TEST_DESCRIPTOR")
	if not fixture.is_empty():
		walker.client.disconnect_host()
		walker.appearance(JSON.parse_string(FileAccess.get_file_as_string(fixture)))
	var deadline := Time.get_ticks_msec()+25000
	while not is_instance_valid(walker.visual) and Time.get_ticks_msec()<deadline:
		await process_frame
	if not is_instance_valid(walker.visual):
		push_error("No SDK avatar from Bazaar subscription");quit(1);return
	var avatar=walker.visual
	check(avatar._face_bindings.has("gaze_right") and avatar._face_bindings.has("eyes_closed"),"Current pack supplies directional irises and eyelids")
	check(avatar._head!=null and avatar._head.index>=0,"Head modifier bound to SDK rig")
	walker.set_physics_process(false)
	var layout: Dictionary=scene.square.stall_layout(2)
	walker.position=layout.approach
	walker.anchor.rotation.y=-PI/2+.3
	scene._process(0)
	avatar._process(.05)
	check(scene.nearest.get("slot")==2 and avatar._gaze.x<0 and absf(avatar._gaze.x)>absf(avatar._turn.x),"Eyes lead head toward actionable stall")
	avatar._process(2)
	check(not avatar._head.offset.is_equal_approx(Quaternion.IDENTITY),"Head turn overlays locomotion")
	walker.anchor.rotate_y(PI);scene._process(0);avatar._process(2)
	check(avatar._gaze==Vector2.ZERO and avatar._turn==Vector2.ZERO,"Rear target releases gaze")
	walker.position=Vector3(230,0,-1.65);scene._process(0);scene.inspect_spot()
	var booth=scene.square.fitting_booth
	for i in 14:booth._process(.1)
	var menu=scene.services
	var tile=menu.content.get_child(1).get_child(1).get_child(1)
	tile.grab_focus()
	await process_frame
	for i in 14:booth._process(.1)
	scene._process(0);avatar._process(2)
	check(menu.attention_control()==tile and not avatar._gaze.is_zero_approx(),"Fitting gaze follows selected pattern")
	avatar.set_expression("content",1,0)
	check(avatar._face_values.eyes_closed>0.9 and is_zero_approx(avatar._face_values.gaze_right),"Closed lids cover directional eyes")
	avatar.reset_face(0)
	var dir := OS.get_environment("BAZAAR_TEST_CAPTURE")
	if not dir.is_empty() and DisplayServer.get_name()!="headless":
		await process_frame;await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(dir)==OK,"Save device fitting capture")
	scene.hide_menu();avatar._process(2)
	check(avatar._gaze==Vector2.ZERO and avatar._turn==Vector2.ZERO,"Leaving fitting room releases focus")
	walker.clear_identity("test");scene._process(0)
	check(walker.fallback.visible and walker.appearance_hash.is_empty(),"Revocation clears face and digest")
	print("BAZAAR_SDK_FACE ",JSON.stringify({"pass":failures.is_empty(),"failures":failures}))
	scene.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
