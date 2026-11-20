# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
## Live host by default. Optional SDK fixture and turntable captures for visual QA.
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
	var deadline:=Time.get_ticks_msec()+25000
	while not is_instance_valid(walker.visual) and Time.get_ticks_msec()<deadline:await process_frame
	if not is_instance_valid(walker.visual):
		push_error("Expected a resolved SDK avatar");quit(1);return
	var original_id: int=walker.visual.get_instance_id()
	var before := {}
	for node in walker.visual.find_children("*","MeshInstance3D",true,false):
		before[node]=node.visible
	walker.set_physics_process(false)
	walker.position=Vector3(230,0,-1.65)
	scene._process(0);scene.inspect_spot()
	var menu=scene.services
	var booth=scene.square.fitting_booth
	var dir:=OS.get_environment("BAZAAR_SET_CAPTURES")
	if not dir.is_empty():DirAccess.make_dir_recursive_absolute(dir)
	for style: String in booth.Garment.STYLES:
		var tile: Button
		for button in menu.find_children("*","Button",true,false):
			if button.get_meta("service_key","")=="pattern-"+style:tile=button
		if not tile:
			check(false,"Missing preset "+style)
			continue
		tile.grab_focus();tile.pressed.emit()
		await create_timer(1.15).timeout
		check(booth.displayed==booth.Garment.full_set(style),"Preset "+style)
		var outfit=booth.garment
		if not is_instance_valid(outfit):
			check(false,"Missing model "+style)
			continue
		for slot in ["Top","Bottom","Boots"]:check(outfit.has_node(NodePath(slot)),"Mesh "+slot)
		check(is_instance_valid(outfit.head_attachment) and outfit.head_attachment.has_node("Hat"),"Hat follows SDK head")
		check(not booth.hidden_clothes.is_empty(),"Original clothes replaced")
		var yaw: float=walker.anchor.rotation.y
		if not dir.is_empty() and DisplayServer.get_name()!="headless":
			for angle in [0,90,180,270]:
				walker.anchor.rotation.y=yaw+deg_to_rad(angle)
				for frame in 5:await process_frame
				await RenderingServer.frame_post_draw
				var file:=style+("-%d"%angle if angle else "")+".png"
				check(root.get_texture().get_image().save_png(dir.path_join(file))==OK,"Capture "+file)
		walker.anchor.rotation.y=yaw
		for index in 4:
			var previous: Dictionary=booth.displayed.duplicate()
			var piece: Button=menu.content.get_child(4).get_child(index)
			piece.grab_focus();piece.pressed.emit()
			await create_timer(1.05).timeout
			for i in 4:
				var slot: String=booth.Garment.SLOTS[i]
				check((booth.displayed[slot]!=previous[slot])==(index==i),"Independent "+slot)
		menu.content.get_child(3).get_child(2).pressed.emit()
		await create_timer(1.05).timeout
		check(not is_instance_valid(booth.garment),"Own outfit clears preview")
		for node in before:check(node.visible==before[node],"Restore "+str(node.name))
	scene.hide_menu()
	check(walker.visual.get_instance_id()==original_id,"Preserve profile avatar")
	print("BAZAAR_OUTFIT_SETS ",JSON.stringify({"pass":failures.is_empty(),"failures":failures}))
	scene.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
