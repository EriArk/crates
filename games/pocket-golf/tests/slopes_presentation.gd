# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Surface = preload("res://scripts/green_surface.gd")
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
	check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"save "+name)

func run() -> void:
	ui=load("res://main.tscn").instantiate(); root.add_child(ui)
	await process_frame
	ui._start_local(1); ui.game.accept_turn(); ui.set_process(false)
	var positions := [[-2000,1500],[1800,-2200],[2000,1200]]
	for hole in 3:
		ui.game.world.hole=hole; ui.game.world._begin_hole()
		ui.game.world.balls[0]=positions[hole]
		ui.game.phase="aim"; ui._build_course(); ui._refresh()
		var state: String = ui.game.world.digest()
		var ball: Vector3 = ui.balls[0].position
		check(ball.y>0.25,"resting ball raised with green")
		check(absf(ui.anchor.position.y-ui._ground(ui.anchor.position))<0.001,"golfer feet meet their own ground height")
		for dot in ui.aim_root.get_children():
			check(absf(dot.position.y-ui._ground(dot.position)-0.055)<0.001,"aim dots follow the surface")
		var p: Array = ui.Courses.get_course(hole).cup
		check(absf(ui.cup.position.y-Surface.sample(ui.green_grid,p[0],p[1])[0]/1000.0)<0.001,"cup seated on level pad")
		check(ui.green_mesh.material_override.get_shader_parameter("sand_count")==ui.Courses.get_course(hole).sand.size(),"sand shares height mesh")
		for node in ui.course_root.get_children():
			if not node is MeshInstance3D or not node.mesh is BoxMesh or not node.material_override is ShaderMaterial: continue
			if node.material_override.get_shader_parameter("kind")!=3: continue
			var low: Vector3 = node.position-node.mesh.size/2
			var high: Vector3 = node.position+node.mesh.size/2
			for x in [low.x,node.position.x,high.x]:
				for z in [low.z,node.position.z,high.z]:
					var level: float = ui._ground(Vector3(x,0,z))
					check(low.y<=level and high.y>=level+0.59,"stone walls extend below ground and clear hill")
		ui.camera.view=ui.GolfCamera.View.EYES; ui._refresh(); ui._process(10)
		check(absf(ui.camera.position.y-ui.anchor.position.y-1.05)<0.002,"eye camera uses golfer floor height")
		check(absf(ui.hud.elevation-(ui.cup.position.y-ui._ground(ball)))<0.011,"HUD shows signed rise to pin")
		await capture("slopes-eyes-"+str(hole+1))
		# Look along the green towards the flag using the normal orbit controls.
		var to_pin: Vector3 = ui.cup.position-ui.anchor.position
		ui.camera.yaw[2]=atan2(-to_pin.x,-to_pin.z)+atan2(0.85,0.75)
		ui.camera.pitch[2]=0.16; ui._process(10)
		await capture("slopes-low-"+str(hole+1))
		ui.camera.reset_view()
		ui.camera.view=ui.GolfCamera.View.SHOULDER
		ui.camera.pitch[1]=0.30; ui.camera.zoom[1]=0.55; ui._process(10)
		check(ui.camera.position.y>ui.camera.obstruction_height+0.54,"closest shoulder view clears raised obstacles")
		ui.camera.reset_view()
		ui.camera.view=ui.GolfCamera.View.OVERVIEW; ui.camera.zoom[0]=0.65
		ui.camera.pitch[0]=0.46; ui.camera.yaw[0]=0.8; ui._refresh(); ui._process(10)
		await capture("slopes-green-"+str(hole+1))
		check(ui.game.world.digest()==state,"camera and HUD leave rules intact")
	# Inspect real moving presentation on a hillside rather than only the tee.
	ui.game.angle=0; ui.game.power=35; ui.game.fire()
	var settled_state: String = ui.game.world.digest()
	for frame in 240:
		if ui.game.phase!="moving": break
		ui._process(1.0/120)
		if ui.shot.capture_frame<0 or ui.elapsed*ui.shot.hz<ui.shot.capture_frame:
			var ball: Vector3 = ui.balls[0].position
			var n := Surface.normal(ui.green_grid,roundi(ball.x*1000),roundi(ball.z*1000))
			check((ball.y-ui._ground(ball))*n.y>0.178,"rolling ball clears hill within sampling tolerance")
	check(ui.game.world.digest()==settled_state,"animation never changes slope result")
	await capture("slopes-rolling")
	root.size=Vector2i(640,440); ui._process(0); await capture("slopes-small")
	print("SLOPES PRESENTATION ","FAIL" if failed else "PASS"," terrain, feet, aim, cup, eyes, HUD elevation, rolling clearance, small layout")
	quit(1 if failed else 0)
