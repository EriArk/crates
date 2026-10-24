# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
# Real-render checks and an optional motion sequence, not a handheld performance claim.
var output := ""
var motion := false
var ui
var failed := false
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): output=arg.trim_prefix("--capture=")
		if arg=="--motion": motion=true
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failed=true; printerr("FAIL: "+message)
func picture(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image()
	if not output.is_empty(): result.save_png(output.path_join(name+".png"))
	return result
func frame_camera(delta: float) -> void:
	var ball: Vector3 = ui.balls[0].position
	var angle := deg_to_rad(float(ui.game.angle))
	ui.camera.frame(delta,ball,ball+Vector3(-cos(angle)*0.85,-0.19,-sin(angle)*0.85),angle,false,true)
func run() -> void:
	root.size=Vector2i(960,540)
	ui=load("res://main.tscn").instantiate(); root.add_child(ui)
	await process_frame
	ui._start_local(1); ui.game.accept_turn()
	var state: String = ui.game.world.digest()
	ui.camera.view=2; ui.camera.pitch[2]=-0.08; ui.camera.yaw[2]=0.4; ui._refresh()
	# Freeze controller polling and settle interpolation before A/B screenshots.
	ui.set_process(false); frame_camera(10.0)
	await create_timer(0.8).timeout
	var before: Image = await picture("meadow-eyes")
	var grass: Array[Node] = ui.island.find_children("*","MultiMeshInstance3D",true,false)
	for patch in grass: patch.visible=false
	await process_frame
	var bare: Image = await picture("meadow-bare-reference")
	var changed := 0
	# The hill silhouettes must actually contain visible grass, not merely hidden nodes.
	for y in range(280,370):
		for x in range(50,930):
			var a := before.get_pixel(x,y); var b := bare.get_pixel(x,y)
			if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>0.06: changed+=1
	check(changed>500,"rendered grass visible on distant hills")
	for patch in grass: patch.visible=true
	# Compare AA on the same view; exports use 4x, both renderer paths support it.
	root.msaa_3d=Viewport.MSAA_2X; await create_timer(0.2).timeout; await picture("distance-msaa2")
	root.msaa_3d=Viewport.MSAA_4X; await create_timer(0.2).timeout; await picture("distance-msaa4")
	if motion:
		for i in 96:
			ui.camera.yaw[2]=0.4+sin(i/95.0*TAU)*0.45
			frame_camera(1.0/24.0)
			await create_timer(1.0/24.0).timeout
			await picture("motion-%03d"%i)
	ui.camera.zoom[2]=1.55; ui.camera.yaw[2]=0.4; frame_camera(10.0)
	await picture("meadow-eyes-wide")
	ui.camera.zoom[2]=1.0
	# A second resolution verifies that 3D detail scales with the drawable size.
	root.size=Vector2i(1920,1080); ui.camera.yaw[2]=0.4
	frame_camera(10.0)
	await create_timer(0.8).timeout; await picture("meadow-eyes-1080")
	ui.camera.view=0; ui.camera.reset_view(); ui._refresh()
	frame_camera(10.0)
	await create_timer(0.8).timeout; await picture("meadow-overview-1080")
	ui.camera.zoom[0]=1.55; frame_camera(10.0); await picture("meadow-overview-far")
	check(ui.game.world.digest()==state,"render settings and motion leave game state unchanged")
	print("DISTANCE ","FAIL" if failed else "PASS"," visible grass pixels=",changed," 540p/1080p, MSAA 2x/4x, camera sweep=",motion)
	quit(1 if failed else 0)
