# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
const Courses = preload("res://scripts/courses.gd")
# Integer coordinates: 1000 units = one metre. No engine physics feeds the rules.
const SIN = [0,872,1736,2588,3420,4226,5000,5736,6428,7071,7660,8192,8660,9063,9397,9659,9848,9962,10000]
const Physics = preload("res://scripts/ball_physics.gd")
const PHYSICS_REVISION := "scale-4"
const CAP = 8
var players := 1
var hole := 0
var turn := 0
var starter := 0
var ply := 0
var balls: Array = []
var strokes: Array = []
var finished: Array = []
var scores: Array = []
var complete := false

func setup(count: int, first: int = 0) -> void:
	players = count
	starter = first % players
	hole = 0
	ply = 0
	complete = false
	scores = []
	for i in players: scores.append([])
	_begin_hole()

func _begin_hole() -> void:
	balls = []
	strokes = []
	finished = []
	for i in players:
		balls.append(Courses.get_course(hole).tee.duplicate())
		strokes.append(0)
		finished.append(false)
	turn = (starter + hole) % players

static func sine(degrees: int) -> int:
	var d := posmod(degrees, 360)
	if d <= 90: return SIN[d / 5]
	if d <= 180: return SIN[(180-d) / 5]
	if d <= 270: return -SIN[(d-180) / 5]
	return -SIN[(360-d) / 5]

static func inside(p: Array, rect: Array, margin: int = 0) -> bool:
	return p[0] > rect[0]-margin and p[0] < rect[2]+margin and p[1] > rect[1]-margin and p[1] < rect[3]+margin

static func trace(course: Dictionary, origin: Array, angle: int, power: int) -> Dictionary:
	return Physics.trace(course,origin,[sine(angle),-sine(90-angle)],power)

func fire(angle: int, power: int) -> Dictionary:
	if complete or angle < 0 or angle >= 360 or angle % 5 != 0 or power < 10 or power > 100 or power % 5 != 0:
		return {}
	var shooter := turn
	var result := trace(Courses.get_course(hole), balls[turn], angle, power)
	balls[turn] = result.position.duplicate()
	strokes[turn] += 1
	finished[turn] = result.sunk or strokes[turn] >= CAP
	result["player"] = shooter
	result["angle"] = angle
	result["hole"] = hole
	result["capped"] = not result.sunk and finished[turn]
	result["strokes"] = strokes.duplicate()
	ply += 1
	if not finished.has(false):
		for i in players: scores[i].append(strokes[i])
		result["hole_done"] = true
		if hole == 2:
			complete = true
		else:
			hole += 1
			_begin_hole()
	else:
		result["hole_done"] = false
		for offset in range(1,players+1):
			var candidate: int = (turn+offset)%players
			if not finished[candidate]:
				turn = candidate
				break
	return result

func snapshot() -> Array:
	return [players,hole,turn,starter,ply,balls,strokes,finished,scores,complete].duplicate(true)

func digest() -> String:
	return JSON.stringify([PHYSICS_REVISION,snapshot()]).sha256_text()

func total(player: int) -> int:
	var result := 0
	for score in scores[player]: result += score
	return result
