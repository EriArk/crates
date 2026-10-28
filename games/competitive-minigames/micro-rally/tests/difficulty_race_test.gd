# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	game.cup.store.load_profile("difficulty-race","user://difficulty-race/"+str(Time.get_ticks_usec()))
	game.demo_auto=true; var failures=0; var reports=[]
	for track in [game.Tracks.VALLEY,game.Tracks.QUARRY]:
		for level in [0,2]:
			game.return_menu(); game.quick_track=track
			game.cup.store.set_bot_settings("quick",game.BotSettings.preset(level))
			game.start_race(); game.laps=1
			for frame in 60*240:
				await physics_frame
				if game.state=="results": break
			var finishers=game.cars.filter(func(c): return c.finish_time>=0).size()
			var falls=0; var recoveries=0
			for car in game.cars: falls+=car.fall_count; recoveries+=car.recovery_count
			var ok=game.state=="results" and finishers>=12 and game.player().finish_time>0 and falls==0
			if not ok: failures+=1
			reports.append({"track":track,"level":level,"finishers":finishers,"player_finish":game.player().finish_time,"elapsed":game.elapsed,"falls":falls,"recoveries":recoveries,"pass":ok})
	print("DIFFICULTY RACES ",JSON.stringify({"failures":failures,"races":reports}))
	await preload("audio_drain.gd").dispose(game,self); quit(1 if failures else 0)
