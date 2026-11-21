# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures=0
func check(ok: bool, label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	game.state="test"
	for car in game.cars: car.freeze=true; car.position=Vector3(200+car.index*5,30,0)
	var a=game.cars[1]; var b=game.cars[2]; var summary=[]
	for level in 3:
		a.bot=game.Car.BotDriver.new(); a.bot.configure(game.BotSettings.preset(level))
		a.position=game.track.points[45]+Vector3.UP*0.7; a.checkpoint=45; a.last_forward=game.track.tangents[45]
		a.linear_velocity=a.last_forward*12; a.surface_grip=1; a.stuck_time=0
		var before=a.transform; var velocity=a.linear_velocity
		for i in 120: a.bot.drive(a,[],1.0/60)
		var pace=a.bot.target_speed; var decisions=a.bot.decision_count
		check(a.transform==before and a.linear_velocity==velocity,"Difficulty never injects physical advantage")
		a.position=Vector3(0,30,0); b.position=Vector3(0,30,-10); a.aim=Vector3.RIGHT; a.weapon_heat=0; a.overheated=false
		await physics_frame; await physics_frame
		var fire_frames=0; var aim_error=0.0
		for i in 360:
			a.bot.combat(a,game.cars,1.0/60)
			if a.firing: fire_frames+=1
			if i>180: aim_error+=absf(a.aim.signed_angle_to(Vector3.FORWARD,Vector3.UP))
		summary.append({"level":level,"target_speed":pace,"decisions":decisions,"fire_frames":fire_frames,"aim_error":aim_error})
	check(summary[0].target_speed<summary[1].target_speed and summary[1].target_speed<summary[2].target_speed,"Difficulty changes actual pace planning")
	check(summary[0].decisions<summary[1].decisions and summary[1].decisions<summary[2].decisions,"Reaction changes real decision cadence")
	check(summary[0].fire_frames<summary[1].fire_frames and summary[1].fire_frames<summary[2].fire_frames,"Accuracy and aggression change delivered firing controls")
	check(summary[0].aim_error>summary[1].aim_error+1,"Easy aim is visibly less accurate")
	print("DIFFICULTY BEHAVIOR ",JSON.stringify({"failures":failures,"levels":summary}))
	await preload("audio_drain.gd").dispose(game,self); quit(1 if failures else 0)
