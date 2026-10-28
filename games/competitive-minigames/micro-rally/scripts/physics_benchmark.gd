# SPDX-License-Identifier: GPL-3.0-or-later
extends Node
# Opt-in rendered soak; use an isolated XDG_DATA_HOME. Never writes cup progress.
var game: Node3D
var seconds=1200.0
var output=""
var started=0
var rounds=0
var frames: Array[float]=[]
var physics_times: Array[float]=[]
var wheel_times: Array[float]=[]
var maximum_memory=0
var maximum_loose_wheels=0
var completed=false
var last_report=0.0
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bench-seconds="): seconds=clampf(float(arg.trim_prefix("--bench-seconds=")),10,3600)
		if arg.begins_with("--bench-output="): output=arg.trim_prefix("--bench-output=")
	game.net.bridge.disconnect_host()
	game.demo_auto=true; game.start_race(); started=Time.get_ticks_msec()
func percentile(values: Array[float], fraction: float) -> float:
	values.sort(); return values[mini(values.size()-1,int(values.size()*fraction))]
func _process(delta: float) -> void:
	if started==0 or completed: return
	var elapsed=(Time.get_ticks_msec()-started)/1000.0
	if game.state=="results":
		rounds+=1; game.start_race()
	if elapsed>5:
		frames.append(delta*1000)
		physics_times.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
		var cost=0.0
		for car in game.cars: cost+=car.physics.solve_usec/1000.0
		wheel_times.append(cost)
		maximum_memory=maxi(maximum_memory,int(Performance.get_monitor(Performance.MEMORY_STATIC)))
		maximum_loose_wheels=maxi(maximum_loose_wheels,game.effects.loose_wheels.size())
	if elapsed-last_report>=60 and not frames.is_empty():
		last_report=elapsed
		print("SOAK_PROGRESS ",JSON.stringify({"seconds":elapsed,"races":rounds,"frame_ms_p50":percentile(frames,0.5),"physics_ms_p95":percentile(physics_times,0.95)}))
	if elapsed<seconds: return
	completed=true
	var report={"wall_seconds":elapsed,"frames":frames.size(),"completed_races":rounds,"cars":game.cars.size(),
		"renderer":RenderingServer.get_current_rendering_method(),"scale":get_viewport().scaling_3d_scale,
		"frame_ms_p50":percentile(frames,0.5),"frame_ms_p95":percentile(frames,0.95),"frame_ms_p99":percentile(frames,0.99),
		"physics_ms_p50":percentile(physics_times,0.5),"physics_ms_p95":percentile(physics_times,0.95),"physics_ms_p99":percentile(physics_times,0.99),
		"wheel_solve_ms_p95":percentile(wheel_times,0.95),"wheel_solve_ms_p99":percentile(wheel_times,0.99),
		"engine_static_memory_peak":maximum_memory,"maximum_loose_wheels":maximum_loose_wheels,
		"finite":game.cars.all(func(c): return c.position.is_finite() and c.linear_velocity.is_finite())}
	if not output.is_empty():
		var file=FileAccess.open(output,FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(report,"  "))
	print("SOAK ",JSON.stringify(report))
	call_deferred("finish")
	return
func finish() -> void:
	get_tree().quit()
