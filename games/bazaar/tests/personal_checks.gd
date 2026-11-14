# SPDX-License-Identifier: GPL-3.0-or-later
extends Node
var failures: Array[String]=[]
func check(ok: bool, message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func frames(count: int) -> void:
	for i in count:await get_tree().physics_frame
func run(world: Node3D) -> void:
	await frames(40)
	check(world.personal,"Personal world selected")
	check(world.visitor.is_on_floor(),"Arrival has real collision")
	check(not is_instance_valid(world.services) and not is_instance_valid(world.population),"No official services, merchants or ownership in empty world")
	check(world.square.destinations.is_empty(),"Empty square has no paid facilities")
	for x in [-16.0,0.0,16.0]:
		for z in [-12.0,0.0,12.0]:
			world.visitor.enter_space(Vector3(x,1.65 if world.world_kind=="island" else 0.2,z),0);await frames(30)
			check(world.visitor.is_on_floor(),"Buildable square supports visitor")
	world.visitor.enter_space(world.square.spawn,0);await frames(30)
	world.visitor.touch_move=Vector2(0,-1);await frames(90);world.visitor.touch_move=Vector2.ZERO
	check(world.visitor.position.z<world.square.spawn.z-4,"Shared motor moves freely")
	world.show_menu();var before: Vector3=world.visitor.position
	world.visitor.touch_move=Vector2(0,1);await frames(20)
	check(world.visitor.position.distance_to(before)<0.1,"Menu stops movement")
	check(world.menu_body.text.contains("no purchases"),"Menu explains unavailable economy")
	world.hide_menu();world.visitor.enter_space(Vector3(0,-8,0),0);await frames(40)
	check(world.visitor.is_on_floor() and world.visitor.position.distance_to(world.square.spawn)<0.3,"Fall returns to correct world arrival")
	if world.world_kind=="island":
		world.visitor.enter_space(Vector3(0,0.6,43),0);await frames(40)
		check(world.visitor.is_on_floor(),"Beach is walkable")
	else:
		world.visitor.enter_space(Vector3(0,0.2,32),0);await frames(20)
		world.visitor.touch_move=Vector2(0,1);await frames(90);world.visitor.touch_move=Vector2.ZERO
		check(world.visitor.position.z<33.8,"Station perimeter stops walking into space")
	var output:="user://personal-checks"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	var f:=FileAccess.open(output+"/"+world.world_kind+"-checks.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"success":failures.is_empty(),"failures":failures,"world":world.world_kind},"  "));f.close()
	print("PERSONAL WORLD ",world.world_kind,": ","PASS" if failures.is_empty() else "FAIL")
	await world.leave_bazaar(0 if failures.is_empty() else 1)
