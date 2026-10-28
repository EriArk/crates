# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var game
var report_path = ""
var previous_stage = ""
var result: Array = []
var maximum_progress = 0
var driven_distance = 0.0
var last_position = Vector3.INF
var last_reset = -1
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
	while Time.get_ticks_msec()-test_started<600000:
		await process_frame
		if game.net.online:
			if game.net.host and game.net.phase=="waiting": game.net.select_event("arena" if OS.get_environment("RALLY_TEST_MODE")=="arena" else "race")
			round_one=true
			if game.is_arena():
				var car=game.player()
				if last_position.is_finite() and last_reset==car.reset_serial:
					var distance=last_position.distance_to(car.position)
					if distance<4: driven_distance+=distance
				last_position=car.position; last_reset=car.reset_serial
			maximum_progress=maxi(maximum_progress,int(driven_distance) if game.is_arena() else game.player().passed)
			if game.net.round_id==1 and game.net.members.size()==16 and game.net.host and game.elapsed>(60 if game.is_arena() else 15) and not forced_finish:
				# Only terminal presentation/rematch is accelerated in the 16-process case.
				# Initial driving, admission and all inputs use the real game/SDK/physics.
				forced_finish=true
				if game.is_arena(): game.elapsed=game.arena.Rules.DURATION
				else:
					for car in game.cars: car.passed=1280; car.laps=4
			if game.state=="results" and game.net.round_id==1 and not game.net.voted:
				result=game.arena.snapshot().scores if game.is_arena() else game.cars.map(func(c): return [c.passed,roundi(c.finish_time*1000),c.did_not_finish])
				print("RALLY movement slot=",game.player_index," distance=",maximum_progress," position=",game.player().position," health=",game.player().health)
				if maximum_progress<15: printerr("FAIL no driven progress slot=",game.player_index); quit(2); return
				game.net.rematch()
			if game.net.round_id==2 and game.state=="race" and game.elapsed>2: report("rematch")
		elif round_one:
			print("RALLY session ended: ",game.hud.message," / ",game.net.info)
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
