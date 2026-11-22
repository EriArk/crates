# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

var failures:=0
var world
var desk
var ground

func check(ok: bool, label: String) -> void:
	if not ok:push_error(label);failures+=1

func _initialize() -> void:
	run.call_deferred()

func visit(at: Vector3, kind: String) -> void:
	world.visitor.enter_space(at+Vector3.UP*.15,0)
	await process_frame
	await process_frame
	check(world.nearest.get("festival")==kind,"Approach "+kind)
	world.inspect_spot()
	check(world.modal and desk.mode==kind,"Open "+kind)

func tap_pad(button: JoyButton) -> void:
	var event:=InputEventJoypadButton.new()
	event.button_index=button
	event.pressed=true
	root.push_input(event,true)
	event.pressed=false
	root.push_input(event,true)

func snapshot_for(game: String, shots: Array, maximum: int) -> Dictionary:
	return {"game":game,"player_id":"qa","price":10,"limit":maximum,"payments_available":true,"round":{
		"id":"qa-ticket","complete":shots.size()==maximum,"attempts":shots,"prize":"Honey Bear" if game=="gallery" and shots.size()>=3 else null}}

func capture(name_: String) -> void:
	var path:=OS.get_environment("FESTIVAL_CAPTURE")
	if path.is_empty() or DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(path.path_join(name_+".jpg"))

func run() -> void:
	world=load("res://main.tscn").instantiate()
	root.add_child(world)
	desk=world.festival
	ground=world.square.festival
	for i in 3:await physics_frame
	tap_pad(JOY_BUTTON_B)
	check(not world.modal,"Back while walking leaves the field menu closed")
	tap_pad(JOY_BUTTON_START)
	check(world.modal and world.panel.visible,"Start opens the field menu")
	tap_pad(JOY_BUTTON_B)
	check(not world.modal,"Back closes the field menu")
	await visit(ground.STALL+Vector3(0,0,1.45),"rings")
	check(not ground.active and not desk.wallet.playable(),"No free ring round")
	# Recorded SDK replies drive the same throw, resume and result UI as the live host.
	var shots:Array=[]
	desk.wallet._received("bazaar.festival",snapshot_for("rings",shots.duplicate(),3))
	desk.play.grab_focus()
	tap_pad(JOY_BUTTON_DPAD_DOWN)
	check(desk.play.has_focus() and world.modal,"Ring aim does not move focus to Back")
	ground.aim=ground.TARGETS[1];ground.clock=PI/5.6;ground._update_cursor()
	check(ground.endpoint.distance_to(ground.TARGETS[1])>.09,"Timing a ring changes whether it clears the peg")
	await capture("wanage")
	for i in 3:
		var peg:Vector2=ground.TARGETS[i]
		shots.append({"x":roundi(peg.x*100),"y":roundi(peg.y*100),"target":i,"points":ground.AWARDS[i]})
		desk.wallet._received("bazaar.festival.attempt",snapshot_for("rings",shots.duplicate(),3))
		check(ground.flight_point(peg,ground.catch_time,ground.catch_time,true,ground.HAND).distance_to(ground.board_point(peg)+Vector3.UP*ground.PEG_HEIGHT)<.001,"Ring crosses the top of the peg")
		var fps:int=[30,60,120][i]
		for frame in fps*2:ground._process(1.0/fps)
		check(ground.rings.back().position.distance_to(ground.board_point(peg))<.10,"Caught ring rests around its peg")
	check(ground.thrown==3 and ground.score==6 and desk.play.text.contains("10 Sparks"),"Three rings score and replay needs a ticket")
	var center:Vector2=ground.TARGETS[1]
	check(ground.catches(center+Vector2(.09,0)) and not ground.catches(center+Vector2(.10,0)),"One centimetre outside the ring misses")
	ground.begin()
	ground.start_throw(center+Vector2(.18,.0))
	ground._process(2.0)
	check(ground.awaiting_throw and ground.score==0 and not ground.flying,"Finishing the flight cannot award points before the receipt")
	var missed_at:Vector3=ground.rings.back().position
	var miss:={"x":roundi((center.x+.18)*100),"y":roundi(center.y*100),"target":-1,"points":0}
	ground.confirm_throw(miss)
	ground.restore([miss])
	check(ground.rings.back().position.distance_to(missed_at)<.001 and ground.score==0,"Reopening reproduces a missed throw and its resting place")
	desk.close()
	check(not world.modal and world.visitor.input_enabled and ground.rings.is_empty(),"Walking and camera restored")
	await visit(ground.gallery.SITE+Vector3(0,0,1.28),"gallery")
	desk.wallet.message=""
	desk.wallet._received("bazaar.festival",snapshot_for("gallery",[],5))
	check(ground.gallery.sight.visible and world.service_camera.current,"First-person sights")
	var relative:Vector2=ground.gallery.MARKS[0]
	var screen:Vector2=world.service_camera.unproject_position(ground.gallery.to_global(Vector3(relative.x,relative.y,ground.gallery.RACK_Z)))
	ground.gallery.pointer(world.service_camera,screen)
	check(ground.gallery.aim.distance_to(relative)<.01,"Pointer hits target plane")
	check(world.service_camera.global_position.z-ground.gallery.to_global(Vector3.BACK*ground.gallery.RACK_Z).z>6,"Gallery has a real shooting lane")
	ground.gallery.rail_time=0
	ground.gallery.point(relative)
	check(absf(ground.gallery.ticket_impact().x-relative.x)>.25,"A moving toy leaves the original aim")
	var misses:=0
	for row in 2:
		misses=0
		for n in 120:
			var t:float=n*TAU/(120.0*(2.7 if row==0 else 2.2))
			if absf(ground.gallery.rail_offset(row,t+ground.gallery.TRAVEL)-ground.gallery.rail_offset(row,t))>.25:misses+=1
		check(misses>=50 and misses<=90,"Tracking the current centre sometimes misses and near the turn still works")
	var lead:float=ground.gallery.rail_offset(0,ground.gallery.TRAVEL)
	ground.gallery.point(relative+Vector2(lead,0))
	check(ground.gallery.ticket_impact().distance_to(relative)<.001,"Leading the moving toy hits its centre")
	await capture("gallery")
	shots.clear()
	for i in 3:
		shots.append({"x":0,"y":0,"target":i,"points":1})
		desk.wallet._received("bazaar.festival.attempt",snapshot_for("gallery",shots.duplicate(),5))
	await create_timer(.4).timeout
	check(ground.gallery.ribbons.size()==5 and ground.gallery.ribbons[2].visible and not ground.gallery.ribbons[1].visible,"Only the won plush has a ribbon")
	check(not ground.gallery.toys[2].visible and desk.bag.visible and desk.info.text.contains("Honey Bear"),"Prize announced on third hit")
	desk.close()
	check(ground.gallery.toys[2].visible and not ground.gallery.launcher.visible,"Booth resets for passers-by")
	await visit(ground.gallery.SITE+Vector3(0,0,1.28),"gallery")
	desk.wallet._received("bazaar.festival",snapshot_for("gallery",shots,5))
	check(not ground.gallery.toys[0].visible and desk.info.text.contains("2 / 5 left"),"Resume the same paid round")
	desk.close()
	await visit(ground.ARENA+Vector3(0,0,-.55),"arena")
	check(not desk.join.visible or desk.join.disabled,"Online entry requires a pair")
	desk.open("golf_local")
	check(desk.local_pid<0 and desk.wallet.game=="golf_local","Local pair needs a ticket before launch")
	print("FESTIVAL integration failures=",failures)
	await world.leave_bazaar(1 if failures else 0)
