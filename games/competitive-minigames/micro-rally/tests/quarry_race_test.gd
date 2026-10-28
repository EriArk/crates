# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	var directory="user://quarry-race/"+str(Time.get_ticks_usec())
	game.cup.store.load_profile("race",directory); game.cup.store.begin()
	# Entry fixture is explicitly only Valley's already-accepted score. Quarry is
	# driven in full, including combat, suspension, recovery and persistent finish.
	var first: Array=[]
	for i in 16: first.append({"slot":i,"ms":240000+i*1000,"progress":1600})
	game.cup.store.finish(0,first)
	var roster=game.cup.store.data.active.roster.duplicate(); var id=game.cup.store.data.active.id
	game.demo_auto=true; game.cup.start_stage()
	var length=game.track.length
	for frame in 60*910:
		await physics_frame
		if game.state=="results": break
	var finishers=game.cars.filter(func(c): return c.finish_time>=0).size()
	var falls=0; var recoveries=0
	for car in game.cars: falls+=car.fall_count; recoveries+=car.recovery_count
	var ok=game.state=="results" and finishers>=14 and game.player().finish_time>=360 and game.player().finish_time<=480 and game.cup.store.data.active.results.size()==2 and game.cup.store.data.wins==0
	var report={"pass":ok,"length":length,"laps":game.laps,"elapsed":game.elapsed,"finishers":finishers,"player_finish":game.player().finish_time,"falls":falls,"recoveries":recoveries,"saved_stages":game.cup.store.data.active.results.size()}
	report.cars=game.cars.map(func(c): return {"slot":c.index,"finish":c.finish_time,"progress":c.passed,"recoveries":c.recovery_count})
	game.cup.leave_stage(); game.cup.store.load_profile("race",directory)
	ok=ok and game.cup.store.data.active.id==id and game.cup.store.data.active.roster==roster and game.cup.store.data.active.results.size()==2
	game.cup.start_stage(); ok=ok and game.state=="menu" and not game.cup.running
	report.pass=ok; report.next_stage_locked=not game.cup.running
	print("QUARRY RACE ",JSON.stringify(report))
	await preload("audio_drain.gd").dispose(game,self); quit(0 if ok else 1)
