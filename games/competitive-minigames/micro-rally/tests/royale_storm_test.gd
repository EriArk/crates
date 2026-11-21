# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
# Controlled non-combat drivers exercise the entire storm journey, not match balance.
class SurvivalDriver extends "res://scripts/arena_bot.gd":
	func combat(car: Node3D,_others: Array,_delta: float) -> void: car.firing=false
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	game.net.platform_enabled=false; game.select_mode("royale"); game.demo_auto=true; game.start_race()
	for car in game.cars: car.bot=SurvivalDriver.new(); car.immune=10000
	var failures=0; var phase=0; var falls=0; var samples=[]
	for frame in 60*710:
		await physics_frame
		phase=maxi(phase,game.royale.phase)
		for car in game.cars:
			if car.position.y< -4: falls+=1
		if frame%3600==0:
			var sample={"time":snappedf(game.elapsed,0.1),"alive":game.royale.alive(),"phase":game.royale.phase}; samples.append(sample); print("STORM ",JSON.stringify(sample))
		if game.state=="results": break
	if game.state!="results" or game.elapsed>705 or falls>0: failures+=1; push_error("Storm resolves the match without floor failures")
	if phase<5: failures+=1; push_error("Non-combat route must reach late storm phases")
	if game.cars.any(func(c): return game.arena.rules.rows[c.index].life!=0): failures+=1; push_error("No resurrection during the storm")
	print("ROYALE STORM ",JSON.stringify({"elapsed":game.elapsed,"phase":phase,"alive":game.royale.alive(),"falls":falls,"places":game.arena.rules.places,"failures":failures}))
	await preload("audio_drain.gd").dispose(game,self); quit(1 if failures else 0)
