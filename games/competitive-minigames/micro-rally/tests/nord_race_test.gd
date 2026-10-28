# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	var directory="user://nord-race/"+str(Time.get_ticks_usec())
	game.cup.store.load_profile("race",directory); game.cup.store.begin()
	# Entry scores are fixtures; only this fourth stage is driven in full here.
	var first: Array=[]
	for i in 16: first.append({"slot":i,"ms":300000+i*1000,"progress":1600})
	for i in 3: game.cup.store.finish(i,first)
	var roster=game.cup.store.data.active.roster.duplicate(); var id=game.cup.store.data.active.id
	game.demo_auto=true; game.cup.start_stage(); var length=game.track.length
	for frame in 60*3610:
		await physics_frame
		if frame%(60*300)==0: print("NORD PROGRESS ",game.elapsed," position=",game.player().checkpoint," / ",game.track.COUNT)
		if game.state=="results": break
	var finishers=game.cars.filter(func(c): return c.finish_time>=0).size(); var falls=0; var recoveries=0
	for car in game.cars: falls+=car.fall_count; recoveries+=car.recovery_count
	var ok=game.state=="results" and falls==0 and finishers>=14 and game.player().finish_time>=1200 and game.player().finish_time<=2700 and game.cup.store.data.active.settled
	var report={"pass":ok,"length":length,"elapsed":game.elapsed,"finishers":finishers,"player_finish":game.player().finish_time,"falls":falls,"recoveries":recoveries,"max_scenery":game.track.max_scenery,"wins":game.cup.store.data.wins}
	report.cars=game.cars.map(func(c): return {"slot":c.index,"finish":c.finish_time,"progress":c.passed,"recoveries":c.recovery_count})
	var expected_win=game.cup.Rules.won(game.cup.store.data.active.results)
	game.cup.leave_stage(); game.cup.store.load_profile("race",directory)
	ok=ok and game.cup.store.data.active.id==id and game.cup.store.data.active.roster==roster and game.cup.store.data.active.results.size()==4
	ok=ok and game.cup.store.data.wins==int(expected_win) and game.cup.store.owned("vortex")==expected_win
	game.cup.start_stage(); ok=ok and game.state=="menu" and not game.cup.running
	report.pass=ok; print("NORD RACE ",JSON.stringify(report))
	await preload("audio_drain.gd").dispose(game,self); quit(0 if ok else 1)
