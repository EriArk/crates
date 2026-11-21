# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures:=0

func check(ok: bool, label: String) -> void:
	if not ok:push_error(label);failures+=1

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var world=load("res://main.tscn").instantiate()
	root.add_child(world)
	var ground=world.square.festival
	for i in 3:await physics_frame
	world.visitor.enter_space(ground.STALL+Vector3(0,.15,1.45),0)
	await process_frame
	await process_frame
	check(world.nearest.get("festival")=="rings","Reach ring stall from the path")
	world.inspect_spot()
	check(world.modal and ground.active,"Ring game entered")
	for i in 3:
		ground.aim=ground.TARGETS[i]-Vector2(0,.05)
		ground.clock=0
		ground.toss()
		ground.toss()
		ground._process(.73)
	check(ground.thrown==3 and ground.score==6,"Three throws score once each")
	world.festival._play()
	ground.aim=Vector2(1.1,.6)
	ground.toss()
	ground._process(1)
	check(ground.score==0 and ground.thrown==1,"Miss scores zero in a fresh round")
	world.festival.close()
	check(not world.modal and world.visitor.input_enabled and ground.rings.is_empty(),"Walking and camera restored")
	world.visitor.enter_space(ground.ARENA+Vector3(0,.15,-.55),0)
	await process_frame
	await process_frame
	world.inspect_spot()
	check(world.festival.visible and world.festival.mode=="arena","Physical arena desk is accessible")
	if OS.has_environment("FESTIVAL_TEST_PAIR"):
		world.festival.play.pressed.emit()
		check(world.festival.local_pid>0,"Golf was launched from the arena")
		var until:=Time.get_ticks_msec()+35000
		while world.festival.local_pid>0 and Time.get_ticks_msec()<until:
			await create_timer(.1).timeout
		check(world.festival.local_line.begins_with("LOCAL CUP    Mint "),"Completed score returned to the board")
		check(world.festival.visible and world.festival.mode=="arena","Seats return to the arena")
		print("ARENA receipt: ",world.festival.local_line)
	print("FESTIVAL integration failures=",failures)
	if OS.has_environment("FESTIVAL_CAPTURE") and DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg(OS.get_environment("FESTIVAL_CAPTURE")+"/arena.jpg")
		world.festival.close()
		world.visitor.enter_space(ground.STALL+Vector3(0,.15,1.45),0)
		await process_frame
		await process_frame
		world.inspect_spot()
		ground.toss()
		ground._process(.34)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg(OS.get_environment("FESTIVAL_CAPTURE")+"/rings.jpg")
	await world.leave_bazaar(1 if failures else 0)
