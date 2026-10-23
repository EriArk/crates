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
func capture(name: String) -> void:
	await create_timer(0.8).timeout
	if output.is_empty(): return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"capture "+name)
func run() -> void:
	root.size=Vector2i(960,540)
	ui=load("res://main.tscn").instantiate(); root.add_child(ui)
	await process_frame
	ui._start_local(1); ui.game.accept_turn()
	var state: String = ui.game.world.digest()
	var environment=ui.island
	check(environment.imported_count>90,"actual GLB props instantiated")
	check(environment.find_children("*","CollisionObject3D",true,false).is_empty(),"decoration never adds gameplay collisions")
	for tree in environment.trees:
		var b: AABB = environment.visual_bounds(tree)
		check(b.position.x>5.3 or b.end.x< -5.3 or b.position.z>8.3 or b.end.z< -8.3,"canopy clear of playable rectangle")
	var terrain: MeshInstance3D = environment.get_node("IslandTerrain")
	var normals: PackedVector3Array = terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	check(normals[0].y>0.9,"terrain faces up, not culled from overview")
	await capture("island-overview")
	check(ui.game.world.digest()==state,"wind and water do not change game state")
	ui.camera.zoom[0]=1.2; await capture("island-wide")
	ui.camera.yaw[0]=-1.0; await capture("island-reverse")
	ui.camera.view=1; ui._refresh(); await capture("island-shoulder")
	ui.camera.view=2; ui.camera.pitch[2]=-0.08; ui.camera.yaw[2]=0.4; ui._refresh()
	await capture("island-horizon")
	ui.camera.view=0; ui.camera.reset_view()
	# Rebuild at an actual hole boundary and ensure old scenery is released.
	var old: WeakRef = weakref(environment)
	ui.game.world.hole=2; ui.game.world._begin_hole(); ui._refresh()
	await process_frame; await process_frame
	check(old.get_ref()==null,"old island freed at hole transition")
	await capture("island-sand")
	print("ISLAND ","FAIL" if failed else "PASS"," imported models, clear canopy, visible terrain, decorative isolation, lifecycle")
	quit(1 if failed else 0)
