# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Rules = preload("res://scripts/rules.gd")
const Courses = preload("res://scripts/courses.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value: failures+=1; printerr("FAIL: "+message)

static func best_shot(world) -> Array:
	var course: Dictionary = Courses.get_course(world.hole)
	var best := [0,10]
	var distance := 1.0e30
	for angle in range(0,360,5):
		for power in range(10,101,5):
			var shot: Dictionary = Rules.trace(course,world.balls[world.turn],angle,power)
			if shot.sunk: return [angle,power]
			var dx: int = shot.position[0]-course.cup[0]
			var dz: int = shot.position[1]-course.cup[1]
			var score: float = dx*dx+dz*dz
			if score<distance: distance=score; best=[angle,power]
	return best

func _initialize() -> void:
	var a := Rules.new(); a.setup(2)
	var b := Rules.new(); b.setup(2)
	var initial: String = a.digest()
	check(a.fire(1,50).is_empty(),"invalid angle")
	check(a.fire(0,101).is_empty(),"invalid power")
	check(a.digest()==initial,"invalid shot leaves state untouched")
	var bounces := 0; var cups := 0
	while not a.complete and a.ply<48:
		var command := best_shot(a)
		var result: Dictionary = a.fire(command[0],command[1])
		b.fire(command[0],command[1])
		check(a.digest()==b.digest(),"identical simulation")
		for point in result.path: check(absi(point[0])<=4820 and absi(point[1])<=7820,"ball inside rails")
		bounces+=result.bounces.size()
		cups+=int(result.sunk)
	check(a.complete,"complete course")
	check(cups==6,"all six player/holes can be sunk")
	check(a.scores[0].size()==3 and a.scores[1].size()==3,"scorecard complete")
	check(a.fire(0,50).is_empty(),"finished game rejects more shots")
	print("SOLVED scores=",a.scores," cups=",cups," bounces=",bounces," digest=",a.digest())
	var wall := Rules.trace(Courses.get_course(1),[-2500,6000],0,100)
	check(not wall.bounces.is_empty(),"obstacle bounce")
	var grass := Courses.get_course(0)
	var sand := grass.duplicate(true); sand.sand=[[-5000,-8000,5000,8000]]
	check(Rules.trace(sand,[0,6000],0,75).position[1]>Rules.trace(grass,[0,6000],0,75).position[1],"sand slows ball")
	var capped := Rules.new(); capped.setup(1)
	while not capped.complete: capped.fire(90,10)
	check(capped.scores==[[8,8,8]],"eight-stroke cap finishes a round")
	print("RULES ","PASS" if failures==0 else "FAIL", " failures=",failures)
	quit(0 if failures==0 else 1)
