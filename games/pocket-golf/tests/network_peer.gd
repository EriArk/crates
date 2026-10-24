# SPDX-License-Identifier: GPL-3.0-or-later
# Headless client used only by the real-host integration test.
extends SceneTree
const Match = preload("res://scripts/match.gd")
const Solver = preload("res://tests/rules_test.gd")
var game
var report := ""
var deadline := 0
var completed := false
var result_hash := ""
var stage := 0
var strokes: Array = []
var prepared_ply := -1
var fire_at := 0
var saw_preview := false

func _initialize() -> void: call_deferred("run")

func run() -> void:
	game=Match.new()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sdk-endpoint="): game.bridge.endpoint_override=arg.trim_prefix("--sdk-endpoint=")
		if arg.begins_with("--report="): report=arg.trim_prefix("--report=")
	root.add_child(game)
	game.bridge.record.connect(func(data):
		if data.get("type")=="aim": saw_preview=true)
	game.shot_started.connect(func(_shot): game.call_deferred("finish_shot"))
	game.join()
	deadline=Time.get_ticks_msec()+45000

func write_report(data: Dictionary) -> void:
	var file := FileAccess.open(report,FileAccess.WRITE)
	file.store_string(JSON.stringify(data))

func _process(_delta: float) -> bool:
	if game==null: return false
	if Time.get_ticks_msec()>deadline:
		printerr("NETWORK TIMEOUT phase=",game.phase," info=",game.info); quit(1); return false
	if game.round_id==1 and game.can_fire():
		if prepared_ply!=game.world.ply:
			var command: Array = [0.37,65.23] if game.world.ply==0 else Solver.best_shot(game.world)
			game.adjust_continuous(command[0]-game.angle,command[1]-game.power)
			prepared_ply=game.world.ply; fire_at=Time.get_ticks_msec()+200
		elif Time.get_ticks_msec()>=fire_at: game.fire()
	elif game.phase=="result" and not game.voted:
		completed=true; result_hash=game.world.digest(); strokes=game.world.scores.duplicate(true)
		game.rematch()
	elif completed and game.round_id==2 and game.phase=="aim" and stage==0:
		if not saw_preview: printerr("No opponent preparation received"); quit(1); return false
		stage=1
		write_report({"stage":"rematch","result":result_hash,"scores":strokes,"starter":game.world.turn})
	elif stage==1 and game.phase=="menu":
		stage=2
		write_report({"stage":"revoked","result":result_hash,"scores":strokes,"starter":1})
		quit(0)
	return false
