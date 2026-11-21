# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures:=0
func check(value: bool, label_text: String) -> void:
	if not value: failures+=1; push_error(label_text)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.net.platform_enabled=false
	game.bot_count=0
	game.quick_track=game.Tracks.QUARRY
	game.start_race()
	game.set_physics_process(false)
	var road=game.track
	var car=game.player()
	check(Array(road.half_widths).min()<5.0 and Array(road.half_widths).max()>8.1,"Loading bay is wider than the quarry cut")
	check(road.props.size()==21,"All seven sites have breakable equipment")
	for i in range(0,road.COUNT,8):
		var side:=Vector3(-road.tangents[i].z,0,road.tangents[i].x)
		var edge: float=road.half_width(i)
		check(road.tire_surface_at(road.points[i]+side*(edge-0.35))==road.Tires.Kind.GRAVEL,"Inside wheel on gravel")
		check(road.tire_surface_at(road.points[i]+side*(edge+0.35))==road.Tires.Kind.GRASS,"Outside wheel on grass")
	# Cross an actual Area3D with the vehicle's chassis.
	var cone=road.props[0]
	car.freeze=false
	car.gravity_scale=0
	car.collision_mask=0
	car.position=cone.position+Vector3.UP*0.35+Vector3(0,0,2.8)
	car.linear_velocity=Vector3(0,0,-8)
	for tick in 35: await physics_frame
	check((road.broken_mask&1)!=0,"Chassis knocked down the cone")
	car.freeze=true
	# Fire the ordinary game weapon into the next crate, away from terrain.
	var crate=road.props[1]
	var target: Vector3=crate.position+Vector3.UP*0.54
	car.position=target+Vector3(0.4,2.4,0)
	car.aim=(target-car.muzzle_origin()).normalized()
	car.aim_3d=false
	car.fire_cooldown=0
	game._shoot(car)
	check((road.broken_mask&2)!=0,"Shot split the crate")
	for tick in 45: await physics_frame
	check(not crate.visible and not cone.visible and crate.collision_layer==0,"Debris clears and destroyed equipment stays gone")
	game.start_race()
	await physics_frame
	check(road.broken_mask==0 and crate.visible and cone.collision_layer==8,"Rematch restores equipment")
	print("ROADSIDE ",JSON.stringify({"failures":failures,"props":road.props.size(),"width_min":2*Array(road.half_widths).min(),"width_max":2*Array(road.half_widths).max()}))
	await preload("audio_drain.gd").dispose(game,self)
	quit(1 if failures else 0)
