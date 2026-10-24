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
func picture(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image()
	if not output.is_empty(): result.save_png(output.path_join(name+".png"))
	return result
func difference(a: Image, b: Image, area: Rect2i, threshold: float) -> int:
	var count := 0
	for y in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			var p := a.get_pixel(x,y); var q := b.get_pixel(x,y)
			if absf(p.r-q.r)+absf(p.g-q.g)+absf(p.b-q.b)>threshold: count+=1
	return count
func pose(delta: float=10.0, rolling: bool=false) -> void:
	var ball: Vector3 = ui.balls[0].position
	ui.camera.frame(delta,ball,ball+Vector3(-0.85,-0.19,0),0,rolling,true)
func run() -> void:
	root.size=Vector2i(960,540)
	ui=load("res://main.tscn").instantiate(); root.add_child(ui)
	await process_frame
	ui._start_local(1); ui.game.accept_turn(); ui.set_process(false)
	var state: String = ui.game.world.digest()
	ui.camera.view=0; pose(); ui._refresh()
	await create_timer(0.8).timeout
	var shadows: Image = await picture("lighting-overview-540")
	ui.get_node("Sun").shadow_enabled=false
	await process_frame; await process_frame
	var flat: Image = await picture("lighting-no-shadows-reference")
	var shadow_pixels := difference(shadows,flat,Rect2i(350,190,210,200),0.08)
	check(shadow_pixels>200,"sun shadows visibly reach playable field")
	ui.get_node("Sun").shadow_enabled=true
	ui.camera.view=2; ui.camera.pitch[2]=-0.08; ui.camera.yaw[2]=0.4; pose(); ui._refresh()
	await create_timer(0.4).timeout
	var focused: Image = await picture("lighting-eyes-540")
	var far_pixels := 0
	var near_pixels := 0
	if ui.camera.optics!=null:
		ui.camera.optics.dof_blur_far_enabled=false
		await process_frame; await process_frame
		var sharp: Image = await picture("lighting-no-dof-reference")
		far_pixels=difference(focused,sharp,Rect2i(0,140,750,95),0.025)
		near_pixels=difference(focused,sharp,Rect2i(200,390,550,55),0.025)
		check(far_pixels>100,"distant scenery receives real DOF")
		check(near_pixels<100,"putting surface stays sharp")
		ui.camera.optics.dof_blur_far_enabled=true
		# Check protected ball/cup depths at extremes AND during view transitions.
		for view in 3:
			ui.camera.view=view
			for zoom in [0.55,1.55]:
				ui.camera.zoom[view]=zoom
				for yaw in [-2.0,0.0,2.0]:
					ui.camera.yaw[view]=yaw
					for rolling in [false,true]:
						for tick in 8:
							pose(0.08,rolling)
							for point in [ui.balls[0].position,ui.cup.position,Vector3(-5,0,-8),Vector3(5,0,8)]:
								check(-ui.camera.to_local(point).z+1.0<ui.camera.optics.dof_blur_far_distance,"gameplay remains within clear focus")
	else:
		check(RenderingServer.get_current_rendering_method()=="gl_compatibility","DOF absent only in compatibility")
	root.size=Vector2i(1920,1080)
	ui.camera.view=0; ui.camera.reset_view(); pose(); ui._refresh()
	await create_timer(0.4).timeout; await picture("lighting-overview")
	ui.camera.view=2; ui.camera.reset_view(); ui.camera.pitch[2]=-0.08; ui.camera.yaw[2]=0.4; pose(); ui._refresh()
	await create_timer(0.4).timeout; await picture("lighting-eyes")
	ui.camera.pitch[2]=0.65; pose()
	await picture("lighting-turf")
	check(ui.game.world.digest()==state,"lighting and focus never mutate match state")
	# Close material view of the third course's sand and stone obstacle.
	ui.game.world.hole=2; ui._build_course(); ui._refresh()
	ui.camera.position=Vector3(4.0,2.5,4.0); ui.camera.look_at(Vector3(0,0,0))
	ui.camera.fov=60; ui.camera._update_focus(Vector3.ZERO)
	await create_timer(0.4).timeout; await picture("lighting-materials")
	print("LIGHTING ","FAIL" if failed else "PASS"," shadow pixels=",shadow_pixels," DOF far=",far_pixels," clear turf differences=",near_pixels," renderer=",RenderingServer.get_current_rendering_method())
	quit(1 if failed else 0)
