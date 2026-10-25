# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
const Rules = preload("res://scripts/rules.gd")
const Courses = preload("res://scripts/courses.gd")
var key := ""
var worker := Thread.new()
var mutex := Mutex.new()
var cancelled := false
var elapsed := 0.0
var result: Array = []

func cancel() -> void:
	mutex.lock(); cancelled=true; mutex.unlock()
	if worker.is_started(): worker.wait_to_finish()
	key=""; result.clear()

func _cancelled() -> bool:
	mutex.lock(); var stop := cancelled; mutex.unlock(); return stop

func tick(world, delta: float) -> Array:
	if key!=world.digest():
		cancel(); key=world.digest(); elapsed=0; cancelled=false
		# Copy the terrain on the main thread. Worker touches no Node or shared course cache.
		var course: Dictionary = Courses.get_course(world.hole)
		worker.start(_solve.bind(course,world.balls[world.turn].duplicate()))
	elapsed+=delta
	if worker.is_started() and not worker.is_alive(): result=worker.wait_to_finish()
	return result.duplicate() if elapsed>=0.9 else []

func _solve(course: Dictionary, origin: Array) -> Array:
	var best := [0.0,50.0]; var best_score := INF
	var candidates: Array = []
	for a in range(0,360,15):
		for p in range(10,101,10): candidates.append([float(a),float(p)])
	for stage in 2:
		while not candidates.is_empty():
			if _cancelled(): return []
			var command: Array = candidates.pop_back()
			var shot: Dictionary = Rules.trace(course,origin,command[0],command[1])
			var point := Vector2(shot.position[0],shot.position[1])
			var score: float = -1000000.0 if shot.sunk else point.distance_squared_to(Vector2(course.cup[0],course.cup[1]))
			if score<best_score: best_score=score; best=command
		if stage==0:
			for a in range(-12,13,3):
				for p in range(-8,9,2): candidates.append([fposmod(best[0]+a,360),clampf(best[1]+p,10,100)])
	return best
