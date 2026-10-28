# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Feedback=preload("res://scripts/driver_feedback.gd")
class Car extends Node3D:
	var throttle=0.0
	var brake=0.0
	var passed=0.0
	var reset_serial=0
	var physics={"steer":0.0}
	var linear_velocity=Vector3.ZERO
	var grounded=true
	var ghost_time=0.0
	var finish_time=-1.0
	var disabled_time=0.0
class Race extends Node:
	var cars: Array=[]
	var state="race"
	var elapsed=5.0
	func player(): return cars[0]
var failures=0
func check(value: bool,label: String) -> void:
	if not value: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func advance(f,game,frames: int) -> Array:
	var events=[]
	for i in frames:
		game.elapsed+=1.0/60
		var event=f.observe(game,1.0/60)
		if not event.is_empty(): events.append(event)
	return events
func run() -> void:
	var game=Race.new(); root.add_child(game)
	var player=Car.new(); var rival=Car.new(); game.cars=[player,rival]; game.add_child(player); game.add_child(rival)
	var f=Feedback.new(); rival.passed=10
	check(advance(f,game,60).is_empty(),"Initial order is not an overtake")
	rival.passed=-3
	check(advance(f,game,10).is_empty(),"Brief order reversal is debounced")
	rival.passed=3; check(advance(f,game,30).is_empty(),"Canceled reversal is silent")
	rival.passed=-3; check(advance(f,game,30)==["happy"],"Confirmed overtake celebrates once")
	check(advance(f,game,60).is_empty(),"Held position cannot replay celebration")
	for i in 30:
		rival.passed=1 if i%2 else -1
		check(advance(f,game,1).is_empty(),"Equal-progress jitter has no emotion")
	rival.passed=3; check(advance(f,game,30)==["sad"],"Being passed shows sadness")
	rival.passed=-8; rival.reset_serial+=1
	check(advance(f,game,30).is_empty(),"Opponent recovery is not an overtake")
	rival.passed=8; player.reset_serial+=1
	check(advance(f,game,30).is_empty(),"Local recovery resets comparison")
	game.state="countdown"; rival.passed=-8
	check(advance(f,game,30).is_empty(),"Countdown sorting is silent")
	game.state="race"; rival.passed=8; player.ghost_time=1
	check(advance(f,game,30).is_empty(),"Respawn immunity suppresses reactions")
	player.ghost_time=0; game.elapsed=0
	check(advance(f,game,60).is_empty(),"New round cannot reuse old standings")
	game.elapsed=5; rival.finish_time=1; rival.passed=-8
	check(advance(f,game,30).is_empty(),"Finish order is not a track overtake")
	for steer in [-1.0,1.0]:
		f.reset()
		for i in 180: f.motion(1.0/60,steer,0,true,false)
		check(absf(rad_to_deg(f.yaw))>34 and absf(rad_to_deg(f.yaw))<=35.01,"Full steering reaches bounded 35 degrees")
	f.reset()
	for i in 180: f.motion(1.0/60,0.2,0,true,false)
	check(absf(rad_to_deg(f.yaw))>15 and absf(rad_to_deg(f.yaw))<22,"Gentle steering stays in requested 15-35 range")
	for i in 180: f.motion(1.0/60,0,0,true,false)
	check(absf(f.yaw)<0.001 and absf(f.bounce)<0.001,"Steady driving settles without fake idle bounce")
	f.motion(1.0/60,0,-10,false,false); f.motion(1.0/60,0,0,true,false)
	check(f.bounce_velocity>0,"Landing generates upward reaction")
	for i in 60: f.motion(1.0/60,1,100 if i%2 else -100,true,false)
	check(absf(f.bounce)<=0.045,"Violent motion remains bounded")
	f.motion(1.0/60,0,200,true,true)
	check(f.bounce==0,"Teleport clears spring instead of launching portrait")
	game.state="pause"; var yaw=f.yaw; advance(f,game,60); check(f.yaw==yaw,"Paused game freezes driver")
	game.state="race"; player.throttle=1; player.brake=0; advance(f,game,60)
	check(f.throttle>0.99 and f.brake==0,"Throttle drives only gas pedal")
	player.throttle=0; player.brake=0.65; advance(f,game,60)
	check(f.throttle<0.01 and absf(f.brake-0.65)<0.01,"Analog brake follows input independently")
	game.free(); print("DRIVER_FEEDBACK_TEST ","PASS" if failures==0 else "FAIL"," failures=",failures); quit(0 if failures==0 else 1)
