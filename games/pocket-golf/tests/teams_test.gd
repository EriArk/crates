# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Rules = preload("res://scripts/rules.gd")
const Bot = preload("res://scripts/golf_bot.gd")
var failures := 0
func check(ok: bool, what: String) -> void:
	if not ok: failures+=1; printerr("FAIL ",what)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for count in [2,4,5,6,7,8]:
		var roster: Array = Rules.default_roster(count)
		check(Rules.valid_roster(roster,count),"accepted roster")
		var world = Rules.new(); world.setup_roster(roster)
		var turns: Array = []; turns.resize(count); turns.fill(0)
		while not world.complete:
			var actor: int = world.actor(); var ball: int = world.turn
			var other = world.copy(); var shot: Dictionary = world.fire(90,10); other.fire(90,10)
			check(world.digest()==other.digest(),"deterministic team replay")
			check(shot.actor==actor and shot.player==ball,"person and shared ball remain distinct")
			turns[actor]+=1
		check(not turns.has(0),"every teammate gets turns")
		for scores in world.scores: check(scores==[8,8,8],"cap applies per ball, not per member")
		print("TEAMS count=",count," roster=",roster," turns=",turns)
	for roster in [[[0],[1,2]],[[0,1],[1,2,3]],[[0,1,2,3],[4,5]],[[0,1],[2,3,9]],[[0,1],[2.5,3]]]:
		check(not Rules.valid_roster(roster,5),"invalid roster rejected")
	var parsed = Rules.new(); parsed.setup_roster(JSON.parse_string("[[0,1],[2,3,4]]"))
	var integer = Rules.new(); integer.setup_roster([[0,1],[2,3,4]])
	check(parsed.digest()==integer.digest(),"JSON numbers normalize before hashing roster")
	var team = Rules.new(); team.setup_roster([[0,1],[2,3,4]])
	team.balls[0]=[0,-4600]; team.fire(0,20)
	check(team.finished[0] and team.turn==1,"sunk shared ball skips entire team")
	var ai = Bot.new(); var solo = Rules.new(); solo.setup(1)
	var cups := 0; var maximum := 0
	while not solo.complete:
		var command: Array = []
		while command.is_empty():
			var before := Time.get_ticks_usec(); command=ai.tick(solo,0.05); maximum=maxi(maximum,Time.get_ticks_usec()-before)
			if command.is_empty(): OS.delay_msec(1)
		var shot: Dictionary = solo.fire(command[0],command[1]); cups+=int(shot.sunk)
	check(cups==3,"rival can complete all actual courses")
	ai.cancel()
	print("BOT scores=",solo.scores," cups=",cups," max planning slice us=",maximum)
	print("TEAMS ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
