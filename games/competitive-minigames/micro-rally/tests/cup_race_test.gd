# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	game.cup.store.load_profile("race","user://cup-race/"+str(Time.get_ticks_usec()))
	game.demo_auto=true; game.cup.start_stage()
	for frame in 60*650:
		await physics_frame
		if game.state=="results": break
	var finishers=game.cars.filter(func(c): return c.finish_time>=0).size()
	var ok=game.state=="results" and finishers>=14 and game.cup.store.data.active.results.size()==1 and game.cup.store.data.wins==0
	print("CUP RACE ",JSON.stringify({"laps":game.laps,"elapsed":game.elapsed,"finishers":finishers,"player_finish":game.player().finish_time,"saved_stages":game.cup.store.data.active.results.size(),"wins":game.cup.store.data.wins,"pass":ok}))
	await preload("audio_drain.gd").dispose(game,self); quit(0 if ok else 1)
