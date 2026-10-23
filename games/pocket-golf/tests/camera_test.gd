# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var ui
var failed := false
var output := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): output=arg.trim_prefix("--capture=")
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok: failed=true; printerr("FAIL: "+message)

func send(event: InputEvent) -> void:
	Input.parse_input_event(event); Input.flush_buffered_events()

func pad(button: JoyButton) -> void:
	for pressed in [true,false]:
		var event := InputEventJoypadButton.new(); event.button_index=button; event.pressed=pressed; send(event)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed; send(event)

func touch(index: int, pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new(); event.index=index; event.position=pos; event.pressed=pressed; send(event)

func drag(index: int, pos: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new(); event.index=index; event.position=pos; event.relative=relative; send(event)

func capture(name: String) -> void:
	await create_timer(0.8).timeout
	if output.is_empty(): return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"capture "+name)

func run() -> void:
	# Headless windows do not inherit the desktop preview's drawable size reliably.
	root.size=Vector2i(960,540)
	ui=load("res://main.tscn").instantiate(); root.add_child(ui)
	await process_frame
	ui._start_local(1); ui.game.accept_turn(); ui.neutral_required=false
	var state: String = ui.game.world.digest()
	var angle: int = ui.game.angle
	var power: int = ui.game.power
	await capture("overview")
	key(KEY_D,true); await create_timer(0.2).timeout; key(KEY_D,false)
	check(ui.camera.yaw[0]>0.7,"keyboard orbit")
	key(KEY_E,true); await create_timer(0.2).timeout; key(KEY_E,false)
	check(ui.camera.zoom[0]<0.95,"keyboard zoom")
	pad(JOY_BUTTON_RIGHT_STICK); check(is_equal_approx(ui.camera.zoom[0],1.0),"R3 resets view")
	# Same continuous-axis mapping used by physical pad polling, without claiming hardware proof.
	ui._camera_axes(Vector2(0.5,-0.3),1.0,0.3)
	check(ui.camera.yaw[0]>0.61 and ui.camera.pitch[0]<0.77 and ui.camera.zoom[0]<1,"right stick and trigger mapping")
	ui.camera.magnify(100); check(is_equal_approx(ui.camera.zoom[0],0.55),"near limit")
	await capture("zoom")
	ui.camera.magnify(-100); check(is_equal_approx(ui.camera.zoom[0],1.55),"far limit")
	pad(JOY_BUTTON_RIGHT_STICK)
	var mouse := InputEventMouseMotion.new(); mouse.position=Vector2(400,270); mouse.relative=Vector2(30,0); mouse.button_mask=MOUSE_BUTTON_MASK_RIGHT; send(mouse)
	check(ui.camera.yaw[0]>0.61,"mouse right drag")
	var wheel := InputEventMouseButton.new(); wheel.position=Vector2(400,270); wheel.button_index=MOUSE_BUTTON_WHEEL_UP; wheel.pressed=true; send(wheel)
	check(ui.camera.zoom[0]<1,"mouse wheel")
	wheel=InputEventMouseButton.new(); wheel.position=Vector2(400,270); wheel.button_index=MOUSE_BUTTON_WHEEL_UP; wheel.pressed=false; send(wheel)
	pad(JOY_BUTTON_RIGHT_STICK)
	pad(JOY_BUTTON_X); check(ui.camera.view==1,"shoulder shortcut")
	await capture("shoulder")
	key(KEY_TAB,true); key(KEY_TAB,false); check(ui.camera.view==2,"eye shortcut")
	await capture("eyes")
	check(not ui.anchor.visible,"eyes hide temporary head without clearing identity")
	check(ui.camera.position.distance_to(ui.anchor.position+Vector3(0,1.05,0))<0.15,"eye position")
	var on_screen: Vector2 = ui.camera.unproject_position(ui.balls[0].position)
	check(on_screen.x>30 and on_screen.x<930 and on_screen.y>90 and on_screen.y<440,"eyes keep ball clear of HUD")
	check(ui.camera.unproject_position(ui.balls[0].position-Vector3(0,0.18,0)).y<450,"whole ball stays above footer")
	ui.camera.magnify(100); await capture("eyes-zoom")
	check(ui.camera.fov>=37.9 and ui.camera.fov<40,"eye zoom uses bounded lens")
	pad(JOY_BUTTON_RIGHT_STICK)
	check(ui.game.world.digest()==state and ui.game.angle==angle and ui.game.power==power,"camera never changes rules or shot selection")
	# Real scene pointer routing: green gestures, release, HUD exclusion.
	pad(JOY_BUTTON_X)
	touch(0,Vector2(350,260),true); drag(0,Vector2(390,260),Vector2(40,0))
	check(ui.camera.yaw[0]>0.61,"touch orbit on green")
	touch(1,Vector2(490,260),true); drag(1,Vector2(540,260),Vector2(50,0))
	check(ui.camera.zoom[0]<1,"pinch zoom on green")
	touch(0,Vector2(390,260),false); touch(1,Vector2(540,260),false)
	check(ui.touches.is_empty(),"released fingers cleared")
	touch(0,Vector2(40,35),true); check(ui.touches.is_empty(),"HUD touch cannot orbit")
	touch(0,Vector2(40,35),false)
	ui.hud.view_requested.emit(); check(ui.camera.view==1,"touch View action")
	ui.hud.view_requested.emit(); check(ui.camera.view==2,"touch Eyes action")
	pad(JOY_BUTTON_A); await create_timer(0.45).timeout
	check(ui.camera.following and ui.anchor.visible,"putt enters ball follow and restores golfer")
	await capture("follow")
	pad(JOY_BUTTON_START); var position: Vector3 = ui.camera.position
	var zoom: float = ui.camera.zoom[2]
	ui._camera_axes(Vector2.ONE,1,1); ui._cycle_view()
	await create_timer(0.1).timeout
	check(ui.camera.position==position and ui.camera.zoom[2]==zoom and ui.camera.view==2,"pause freezes camera and rejects navigation")
	pad(JOY_BUTTON_B)
	ui.elapsed=20; await process_frame; await process_frame
	ui.game.accept_turn(); await create_timer(1).timeout
	check(ui.camera.view==2 and not ui.camera.following and not ui.anchor.visible,"return to selected eyes after shot")
	ui.neutral_required=true
	ui._camera_axes(Vector2.ONE,1,1)
	check(ui.camera.zoom[2]==zoom,"neutral gate rejects held camera axes")
	ui.neutral_required=false
	ui.camera.magnify(0.2); pad(JOY_BUTTON_START)
	ui.popup_buttons.get_child(2).pressed.emit()
	check(not ui.paused and is_equal_approx(ui.camera.zoom[2],1.0),"touch-accessible reset in Menu")
	root.size=Vector2i(640,440); await capture("small-eyes")
	for hole in 3:
		var course: Dictionary = ui.Courses.get_course(hole)
		for degrees in [0,90,180,270]:
			var radians := deg_to_rad(degrees)
			var ball := Vector3(course.tee[0]/1000.0,0.19,course.tee[1]/1000.0)
			var golfer := ball+Vector3(-cos(radians)*0.85,-0.19,-sin(radians)*0.85)
			ui.camera.reset_view(); ui.camera.frame(10,ball,golfer,radians,false,true)
			check(not ui.camera.is_position_behind(ball),"ball in front for every hole/aim")
			check(ui.camera.position.y>=1.04,"eyes above course obstacles")
	print("CAMERA ","FAIL" if failed else "PASS"," views, zoom, keyboard, injected pad buttons, axis mapping, pointer gestures, follow, pause, rules isolation")
	quit(1 if failed else 0)
