# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures = 0
func check(ok: bool, label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	game.state="test"
	for car in game.cars: car.freeze=true; car.position=Vector3(200+car.index*5,30,0)
	var a=game.cars[1]; var b=game.cars[2]
	a.position=Vector3(0,30,0); b.position=Vector3(0,30,-10); a.aim=Vector3.FORWARD
	await physics_frame; await physics_frame
	a.bot.combat(a,game.cars,0.25)
	check(a.firing,"Bot can aim and fire at visible opponent")
	var wall=game.Art.collider(game,Vector3(4,4,1),Vector3(0,30,-5))
	await physics_frame; await physics_frame
	a.bot.combat(a,game.cars,0.25)
	check(not a.firing,"Bot does not waste shots through a wall")
	wall.queue_free(); await physics_frame; await physics_frame
	a.shield_item=true; a.shield=0; b.firing=true; b.aim=Vector3.BACK
	a.bot.combat(a,game.cars,0.25)
	check(a.shield>0 and not a.shield_item,"Bot spends shield when opponent aims and fires at it")
	b.firing=false; b.ghost_time=2; a.bot.combat(a,game.cars,0.25)
	check(a.bot.opponent==null and not a.firing,"Bot drops protected recovery target")
	# Compare identical road poses under different grip, without any speed/position injection by AI.
	a.position=game.track.points[45]+Vector3.UP*0.7; a.checkpoint=45; a.last_forward=game.track.tangents[45]
	a.linear_velocity=a.last_forward*12; a.surface_grip=1
	var before: Vector3=a.position; var velocity: Vector3=a.linear_velocity
	a.bot.drive(a,[],0.25); var dry: float=a.bot.target_speed
	a.surface_grip=0.84; a.bot.drive(a,[],0.25)
	check(a.bot.target_speed<=dry,"Wet-road planning never demands a higher corner speed")
	check(a.position==before and a.linear_velocity==velocity,"AI only produces controls, never changes physical pose or velocity")
	print("BOT TEST failures=",failures)
	await preload("audio_drain.gd").dispose(game,self); quit(1 if failures else 0)
