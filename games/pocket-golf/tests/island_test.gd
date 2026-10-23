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
func check_landscape(environment) -> void:
	var terrain: MeshInstance3D = environment.get_node("IslandTerrain")
	var vertices: PackedVector3Array = terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var highest := -10.0
	for vertex in vertices:
		highest=maxf(highest,vertex.y)
		if absf(vertex.x)<5.35 and absf(vertex.z)<8.35:
			check(vertex.y< -0.1,"landscaping stays below playable green")
	check(highest>1.0,"real terrain has raised hills")
	check(environment.grass_positions.size()>250,"dense meadow present")
	var batches: Array[Node] = environment.find_children("*","MultiMeshInstance3D",true,false)
	check(batches.size()>0 and batches.size()<5,"grass uses bounded GPU batches")
	for plant in environment.planting:
		var box: AABB = environment.visual_bounds(plant)
		check(box.position.x>5.3 or box.end.x< -5.3 or box.position.z>8.3 or box.end.z< -8.3,"plant clear of playable rectangle")
		check(absf(box.position.y-surface_height(vertices,plant.position))<0.08,"plant grounded on rendered slope")
	for point in environment.grass_positions:
		check(absf(point.x)>=5.8 or absf(point.z)>=8.8,"grass clear of green")
		check(not (point.x>5.5 and absf(point.z-3.8)<0.9),"dock path clear of grass")
	# Sample across every cluster; avoid repeating a brute-force mesh query for every blade.
	for i in range(0,environment.grass_positions.size(),11):
		var point: Vector3 = environment.grass_positions[i]
		check(absf(point.y-surface_height(vertices,point))<0.08,"grass grounded on rendered slope")
	print("LANDSCAPE hills=",snappedf(highest,0.01)," plants=",environment.planting.size()," grass=",environment.grass_positions.size()," batches=",batches.size())
func surface_height(vertices: PackedVector3Array, point: Vector3) -> float:
	# Independently sample the triangles actually sent to the renderer.
	for i in range(0,vertices.size(),3):
		var a := vertices[i]; var b := vertices[i+1]; var c := vertices[i+2]
		var divisor := (b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)
		if absf(divisor)<0.000001: continue
		var u := ((b.z-c.z)*(point.x-c.x)+(c.x-b.x)*(point.z-c.z))/divisor
		var v := ((c.z-a.z)*(point.x-c.x)+(a.x-c.x)*(point.z-c.z))/divisor
		if u>=-0.00001 and v>=-0.00001 and u+v<=1.00001:
			return a.y*u+b.y*v+c.y*(1.0-u-v)
	return -100.0
func run() -> void:
	root.size=Vector2i(960,540)
	ui=load("res://main.tscn").instantiate(); root.add_child(ui)
	await process_frame
	ui._start_local(1); ui.game.accept_turn()
	var state: String = ui.game.world.digest()
	var environment=ui.island
	check_landscape(environment)
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
	check_landscape(ui.island)
	await capture("island-sand")
	ui.game.world.hole=1; ui.game.world._begin_hole(); ui._refresh()
	await process_frame; check_landscape(ui.island)
	print("ISLAND ","FAIL" if failed else "PASS"," imported models, clear canopy, visible terrain, decorative isolation, lifecycle")
	quit(1 if failed else 0)
