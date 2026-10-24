# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var ui
var failed := false
var output := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): output=arg.trim_prefix("--capture=")
	call_deferred("run")

func check(value: bool, label: String) -> void:
	if not value: failed=true; printerr("FAIL: "+label)

func capture(name: String) -> void:
	if output.is_empty(): return
	await process_frame; await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"capture "+name)

func begin(origin: Array, power: int) -> void:
	ui._start_local(1); ui.game.accept_turn()
	ui.game.world.balls[0]=origin
	ui.game.power=power; ui.game.angle=0; ui._refresh()
	ui.game.fire()

func run() -> void:
	ui=load("res://main.tscn").instantiate(); root.add_child(ui)
	await process_frame
	ui.set_process(false)
	begin([0,6000],75)
	var state: String = ui.game.world.digest()
	ui.elapsed=ui.Stroke.CONTACT+8.5/ui.shot.hz; ui._process(0)
	var expected: float = (ui.shot.path[8][1]+ui.shot.path[9][1])/2000.0
	check(absf(ui.balls[0].position.z-expected)<0.00001,"sub-tick interpolation")
	check(not ui.balls[0].get_node("RollingBall").basis.is_equal_approx(Basis.IDENTITY),"visible rolling rotation")
	ui.paused=true
	var position: Vector3 = ui.balls[0].position
	ui._process(0.5)
	check(ui.balls[0].position==position,"local pause freezes ball")
	ui.paused=false
	var trajectory: Dictionary = ui.shot
	var positions: Array = []
	for fps in [30,60,144]:
		ui._shot_started(trajectory)
		for frame in fps: ui._process(1.0/fps)
		positions.append(ui.balls[0].position)
	check(positions[0].distance_to(positions[2])<0.00001 and positions[1].distance_to(positions[2])<0.00001,"30/60/144 Hz presentation agrees")
	check(ui.game.world.digest()==state,"render rate and pause do not change result")
	await capture("physics-rolling")
	begin([0,-4600],20)
	check(ui.shot.sunk,"cup fixture sinks through real Match")
	ui.elapsed=ui.Stroke.CONTACT+(ui.shot.capture_frame+18.5)/float(ui.shot.hz); ui._process(0)
	check(ui.balls[0].position.y<ui.cup.position.y+ui.Size.BALL and ui.balls[0].scale==Vector3.ONE,"ball descends without shrinking")
	check(not ui.balls[0].get_child(1).visible,"floor marker disappears inside cup")
	await capture("physics-cup")
	ui.elapsed=20; ui._process(0)
	check(ui.game.phase=="handoff" and ui.game.world.hole==1,"cup finishes turn and advances hole")
	print("PHYSICS PRESENTATION ","FAIL" if failed else "PASS"," interpolation, rolling, pause, 30/60/144 Hz, cup drop, handoff")
	quit(1 if failed else 0)
