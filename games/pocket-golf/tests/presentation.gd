# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Solver = preload("res://tests/rules_test.gd")
var ui
var output := ""
var failed := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): output=arg.trim_prefix("--capture=")
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value: failed=true; printerr("FAIL: "+message)

func pad(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new(); event.button_index=button; event.pressed=true; Input.parse_input_event(event); Input.flush_buffered_events()
	event=InputEventJoypadButton.new(); event.button_index=button; event.pressed=false; Input.parse_input_event(event); Input.flush_buffered_events()

func capture(name: String) -> void:
	if output.is_empty(): return
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"save "+name)

func run() -> void:
	ui=load("res://main.tscn").instantiate(); root.add_child(ui)
	await create_timer(0.3).timeout
	await capture("menu")
	pad(JOY_BUTTON_DPAD_DOWN); pad(JOY_BUTTON_A)
	print("INPUT state=",ui.game.phase," players=",ui.game.world.players," neutral=",ui.neutral_required," focus=",root.gui_get_focus_owner())
	check(ui.game.world.players==2 and ui.game.phase=="handoff","pad starts two players")
	if failed: quit(1); return
	pad(JOY_BUTTON_A); check(ui.game.can_fire(),"pad accepts handoff")
	pad(JOY_BUTTON_DPAD_RIGHT); check(ui.game.angle==5,"pad aiming")
	pad(JOY_BUTTON_DPAD_UP); check(ui.game.power==80,"pad power")
	pad(JOY_BUTTON_X); check(ui.camera.view==1,"pad shoulder view"); pad(JOY_BUTTON_X)
	check(ui.camera.view==2,"pad eye view"); pad(JOY_BUTTON_X)
	pad(JOY_BUTTON_START); check(ui.paused,"pad menu"); pad(JOY_BUTTON_B); check(not ui.paused,"pad resume")
	await capture("first-green")
	var last_hole := -1
	while not ui.game.world.complete:
		if ui.game.phase=="handoff": pad(JOY_BUTTON_A)
		var command: Array = Solver.best_shot(ui.game.world)
		while ui.game.angle!=command[0]: pad(JOY_BUTTON_DPAD_RIGHT)
		while ui.game.power!=command[1]: pad(JOY_BUTTON_DPAD_UP if ui.game.power<command[1] else JOY_BUTTON_DPAD_DOWN)
		if ui.game.world.hole!=last_hole:
			last_hole=ui.game.world.hole; await capture("hole-"+str(last_hole+1))
		pad(JOY_BUTTON_A); check(ui.game.phase=="moving","pad putt")
		var ply: int = ui.game.world.ply; pad(JOY_BUTTON_A); check(ui.game.world.ply==ply,"double confirm cannot fire twice")
		if ply==1:
			await create_timer(0.5).timeout
			check(ui.game.phase=="moving","visible rolling time")
			await capture("rolling")
		ui.elapsed=20; await process_frame; await process_frame
	check(ui.game.phase=="result","result reached")
	await capture("scorecard")
	pad(JOY_BUTTON_A); check(ui.game.phase=="handoff" and ui.game.world.turn==1,"pad rematch alternates starter")
	pad(JOY_BUTTON_A)
	root.size=Vector2i(640,440); await create_timer(0.3).timeout
	await capture("small-controller")
	ui.touch_mode=true; ui._refresh(); await capture("small-touch")
	check(ui.hud.visible and ui.hud.regions().has("aim"),"contextual touch aim control")
	ui.get_window().focus_exited.emit(); check(ui.paused,"focus loss opens pause")
	ui.get_window().focus_exited.emit(); check(ui.paused,"repeated focus loss never resumes")
	ui.neutral_required=false; pad(JOY_BUTTON_B); check(not ui.paused,"resume after focus")
	pad(JOY_BUTTON_START); pad(JOY_BUTTON_DPAD_DOWN); pad(JOY_BUTTON_A)
	check(ui.game.phase=="menu","pad leave round")
	ui.anchor.install_visual(Node3D.new(),"fixture-owner")
	ui.game.online=true; ui.game.bridge.active=true
	ui.game.bridge._packet({"event":"context.revoked","reason":"profile_changed"})
	check(ui.game.phase=="menu" and ui.anchor.player_id.is_empty(),"profile revocation removes old avatar identity")
	ui._start_local(1); check(ui.anchor.visual!=null and ui.anchor.player_id.is_empty(),"local fallback stays usable without identity")
	print("PRESENTATION ","FAIL" if failed else "PASS", " Godot injected joy events; physical controller not tested")
	quit(1 if failed else 0)
