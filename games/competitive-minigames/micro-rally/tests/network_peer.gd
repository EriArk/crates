# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var game
var report_path = ""
var previous_stage = ""
var result: Array = []
var maximum_progress = 0
var round_one = false
var forced_finish = false
var test_started = 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sdk-endpoint="): OS.set_environment("TRAINEROS_SDK_ENDPOINT",arg.trim_prefix("--sdk-endpoint="))
		if arg.begins_with("--report="): report_path=arg.trim_prefix("--report=")
	game=load("res://main.tscn").instantiate(); root.add_child(game); game.demo_auto=true
	game.net.bridge.connected.connect(func(): print("RALLY attached"))
	game.net.bridge.status.connect(func(text): print("SDK ",text))
	test_started=Time.get_ticks_msec()
	while Time.get_ticks_msec()-test_started<480000:
		await process_frame
		if game.net.online:
			round_one=true; maximum_progress=maxi(maximum_progress,game.player().passed)
			if game.net.round_id==1 and game.net.members.size()==16 and game.net.host and game.elapsed>15 and not forced_finish:
				# Only terminal presentation/rematch is accelerated in the 16-process case.
				# Initial driving, admission and all inputs use the real game/SDK/physics.
				forced_finish=true
				for car in game.cars: car.passed=1280; car.laps=4
			if game.state=="results" and game.net.round_id==1 and not game.net.voted:
				result=game.cars.map(func(c): return [c.passed,roundi(c.finish_time*1000),c.did_not_finish])
				if maximum_progress<15: printerr("FAIL no driven progress"); quit(2); return
				game.net.rematch()
			if game.net.round_id==2 and game.state=="race" and game.elapsed>2: report("rematch")
		elif round_one:
			await create_timer(0.5).timeout # Include late SDK replies after the close event.
			report("revoked" if previous_stage=="rematch" else "failed")
			await preload("audio_drain.gd").dispose(game,self)
			quit(0 if previous_stage=="revoked" else 3); return
	printerr("FAIL native peer timeout ",game.state," ",game.net.phase); quit(4)
func report(stage: String) -> void:
	if stage==previous_stage: return
	previous_stage=stage
	var file=FileAccess.open(report_path+".pending",FileAccess.WRITE)
	file.store_string(JSON.stringify({"stage":stage,"result":result,"local":game.player_index,"progress":maximum_progress,"round":game.net.round_id,"replicas":game.cars.filter(func(c): return c.replica).size(),"snapshot":game.net.last_snapshot,"registered":game.net.bridge.registered}))
	file.close(); DirAccess.rename_absolute(report_path+".pending",report_path)
	print("RALLY stage=",stage," round=",game.net.round_id," progress=",maximum_progress)
