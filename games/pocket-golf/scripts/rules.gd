# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
const Courses = preload("res://scripts/courses.gd")
# Integer coordinates: 1000 units = one metre. No engine physics feeds the rules.
const SIN = [0,872,1736,2588,3420,4226,5000,5736,6428,7071,7660,8192,8660,9063,9397,9659,9848,9962,10000]
const Physics = preload("res://scripts/ball_physics.gd")
const PHYSICS_REVISION := "analog-5"
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
var roster: Array = [] # Ball/team -> participant seats, immutable for a round.
var rotations: Array = [] # Carries across holes, including a teammate's last putt.

static func valid_roster(value: Array, count: int) -> bool:
	if count<1 or count>8 or value.is_empty() or value.size()>4: return false
	var seen: Array = []
	var teams: bool = value.size()!=count
	if teams and count<4: return false
	if not teams and count not in [1,2,4]: return false
	for group in value:
		if not group is Array or group.size()<(2 if teams else 1) or group.size()>(3 if teams else 1): return false
		for member in group:
			if not (member is int or member is float) or not is_finite(float(member)) or member!=int(member) or member<0 or member>=count or seen.has(int(member)): return false
			seen.append(int(member))
	return seen.size()==count

static func default_roster(count: int) -> Array:
	if count in [1,2,4]:
		var result: Array = []
		for i in count: result.append([i])
		return result
	return {5:[[0,1],[2,3,4]],6:[[0,1,2],[3,4,5]],7:[[0,1],[2,3],[4,5,6]],8:[[0,1],[2,3,4],[5,6,7]]}.get(count,[]).duplicate(true)

func actor(ball: int = -1) -> int:
	var index := turn if ball<0 else ball
	return roster[index][rotations[index]%roster[index].size()]

func setup_roster(value: Array, first: int = 0) -> void:
	setup(value.size(),first)
	roster=[]
	for group in value: roster.append(group.map(func(member): return int(member)))

func setup(count: int, first: int = 0) -> void:
	players = count
	roster=[]; rotations=[]
	for i in players: roster.append([i]); rotations.append(0)
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

static func sine_units(centidegrees: int) -> int:
	# Integer interpolation preserves the original five-degree samples, while
	# allowing fine aiming without platform-dependent trigonometry in the rules.
	var d := posmod(centidegrees,36000)
	var polarity := 1 if d<=18000 else -1
	d=posmod(d,18000)
	if d>9000: d=18000-d
	if d==9000: return polarity*10000
	var index := d/500
	return polarity*(SIN[index]+(SIN[index+1]-SIN[index])*(d%500)/500)

static func inside(p: Array, rect: Array, margin: int = 0) -> bool:
	return p[0] > rect[0]-margin and p[0] < rect[2]+margin and p[1] > rect[1]-margin and p[1] < rect[3]+margin

static func trace(course: Dictionary, origin: Array, angle: float, power: float) -> Dictionary:
	return trace_units(course,origin,posmod(roundi(angle*100),36000),roundi(power*100))

static func trace_units(course: Dictionary, origin: Array, angle_units: int, power_units: int) -> Dictionary:
	return Physics.trace(course,origin,[sine_units(angle_units),-sine_units(9000-angle_units)],power_units,100)

func fire(angle: float, power: float) -> Dictionary:
	if not is_finite(angle) or not is_finite(power) or angle<0 or angle>=360 or power<10 or power>100:
		return {}
	return fire_units(posmod(roundi(angle*100),36000),roundi(power*100))

func fire_units(angle_units: int, power_units: int) -> Dictionary:
	if complete or angle_units<0 or angle_units>=36000 or power_units<1000 or power_units>10000:
		return {}
	var shooter := turn
	var participant := actor()
	var result := trace_units(Courses.get_course(hole), balls[turn], angle_units, power_units)
	balls[turn] = result.position.duplicate()
	strokes[turn] += 1
	finished[turn] = result.sunk or strokes[turn] >= CAP
	result["player"] = shooter
	result["actor"] = participant
	rotations[shooter]+=1
	result["angle"] = angle_units/100.0
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
	return [players,hole,turn,starter,ply,balls,strokes,finished,scores,complete,roster,rotations].duplicate(true)

func copy():
	var candidate = get_script().new()
	for key in ["players","hole","turn","starter","ply","complete"]: candidate.set(key,get(key))
	for key in ["balls","strokes","finished","scores","roster","rotations"]: candidate.set(key,get(key).duplicate(true))
	return candidate

func digest() -> String:
	return JSON.stringify([PHYSICS_REVISION,snapshot()]).sha256_text()

func total(player: int) -> int:
	var result := 0
	for score in scores[player]: result += score
	return result
