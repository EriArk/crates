# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures = 0
func check(ok: bool, label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	game.state="test"; game.set_physics_process(false)
	for other in game.cars: other.freeze=true
	var car=game.player(); car.ghost_time=0
	var shots=0; var first_burst=0; var locks=0; var locked_frames=0; var first_lock_frames=0
	# Hold fire for two minutes: heat cycles must never exhaust ammunition.
	for frame in 7200:
		car.tick_weapon(1.0/60)
		var was_locked: bool=car.overheated
		if was_locked: locked_frames+=1
		elif locked_frames>0:
			if first_lock_frames==0: first_lock_frames=locked_frames
			locked_frames=0
		if car.begin_shot():
			check(not was_locked,"No shot while overheated")
			shots+=1
			if car.overheated:
				locks+=1
				if first_burst==0: first_burst=shots
		check(car.weapon_heat>=0 and car.weapon_heat<=100,"Heat stays bounded")
	check(first_burst==12 and locks>10 and shots>150,"Unlimited gun repeatedly overheats and resumes under held trigger")
	check(first_lock_frames>=195 and first_lock_frames<=205,"Full overheat requires about 3.4 seconds cooling")
	car.cool_weapon(); car.fire_cooldown=0; check(car.begin_shot(),"Cold gun fires")
	car.tick_weapon(0.4); check(is_equal_approx(car.weapon_heat,car.HEAT_PER_SHOT),"Cooling delay prevents free heat loss between rapid shots")
	car.tick_weapon(1.0); check(car.weapon_heat==0,"Released trigger fully cools a short burst")
	for blocked in ["replica","disabled","finished","ghost"]:
		car.replica=blocked=="replica"; car.disabled_time=1 if blocked=="disabled" else 0
		car.finish_time=1 if blocked=="finished" else -1; car.ghost_time=1 if blocked=="ghost" else 0
		check(not car.begin_shot() and car.weapon_heat==0,"Blocked actor cannot fire or accumulate heat: "+blocked)
	car.replica=false; car.disabled_time=0; car.finish_time=-1; car.ghost_time=0
	car.weapon_heat=100; car.overheated=true; car.cool_weapon()
	check(car.begin_shot(),"Coolant clears overheat without ammunition")
	car.replica=true; var heat=car.weapon_heat; car.tick_weapon(10)
	check(car.weapon_heat==heat,"Replica cannot independently cool authoritative heat")
	print("WEAPON TEST failures=",failures," shots=",shots," locks=",locks," first_burst=",first_burst," cooling_frames=",first_lock_frames)
	await preload("audio_drain.gd").dispose(game,self); quit(1 if failures else 0)
