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
var backend := false
var server_match := ""
var decision := ""
var board_rows := 0
var board_requested := false
var appearances
var avatar_binding
class AvatarEndpoint extends Node:
	var client = preload("res://addons/traineros/avatar_client.gd").new()
	func clear_peer() -> void: pass

func _initialize() -> void: call_deferred("run")

func run() -> void:
	backend=not OS.get_environment("GOLF_TEST_BACKEND_FIXTURES").is_empty() and OS.get_environment("GOLF_TEST_CASUAL").is_empty()
	game=Match.new()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sdk-endpoint="): game.bridge.endpoint_override=arg.trim_prefix("--sdk-endpoint=")
		if arg.begins_with("--report="): report=arg.trim_prefix("--report=")
	root.add_child(game)
	game.bridge.member_record.connect(func(_peer,data):
		if data.get("type")=="aim": saw_preview=true)
	game.shot_started.connect(func(_shot): game.call_deferred("finish_shot"))
	game.changed.connect(func():
		if game.phase in ["menu","setup","waiting","result"]: print("GOLF phase=",game.phase," sync=",game.sync," info=",game.info))
	avatar_binding=AvatarEndpoint.new(); root.add_child(avatar_binding); avatar_binding.add_child(avatar_binding.client)
	avatar_binding.client.app_id="art.abysstail.pocket-golf.avatar-test"
	avatar_binding.client.endpoint_override=game.bridge.endpoint_override
	appearances=preload("res://scripts/avatar_roster.gd").new(); root.add_child(appearances); appearances.start(avatar_binding,game)
	avatar_binding.client.connect_host()
	game.join()
	deadline=Time.get_ticks_msec()+120000

func write_report(data: Dictionary) -> void:
	var file := FileAccess.open(report,FileAccess.WRITE)
	file.store_string(JSON.stringify(data))

func _process(_delta: float) -> bool:
	if game==null: return false
	if Time.get_ticks_msec()>deadline:
		printerr("NETWORK TIMEOUT phase=",game.phase," info=",game.info); quit(1); return false
	if game.phase=="setup":
		game.start_group(game.chosen_roster)
	if game.round_id==1 and game.can_fire():
		if prepared_ply!=game.world.ply:
			var command: Array = [0.37,65.23] if game.world.ply==0 else [90.0,10.0]
			game.adjust_continuous(command[0]-game.angle,command[1]-game.power)
			prepared_ply=game.world.ply; fire_at=Time.get_ticks_msec()+80
		elif Time.get_ticks_msec()>=fire_at: game.fire()
	elif game.phase=="result" and not game.voted:
		if backend:
			if game.scorecards.decision!="confirmed": return false
			if not board_requested and not game.scorecards.busy:
				board_requested=true
				game.scorecards.fetch_board("individual" if game.world.players==game.participant_count else "teams","records")
			if game.scorecards.busy or game.scorecards.board.is_empty(): return false
			server_match=game.scorecards.match_id; decision=game.scorecards.decision
			board_rows=game.scorecards.board.items.size()
			var profiles: Dictionary = game.scorecards.board.get("profiles",{})
			if profiles.size()!=game.participant_count: printerr("Missing public profiles"); quit(1); return false
			for profile in profiles.values():
				if not str(profile.get("display_name","")).begins_with("Test player "): printerr("Missing verified name"); quit(1); return false
				if game.participant_count in [4,8] and not profile.get("avatar") is Dictionary: printerr("Missing shared avatar recipe"); quit(1); return false
			print("BOARD PROFILES PASS players=",profiles.size())
		completed=true; result_hash=game.world.digest(); strokes=game.world.scores.duplicate(true)
		game.rematch()
	elif completed and game.round_id==2 and game.phase=="aim" and stage==0:
		if not saw_preview: printerr("No opponent preparation received"); quit(1); return false
		if game.participant_count in [4,8]:
			if appearances.descriptions.size()!=game.participant_count-1: return false
			var hashes: Array = []
			for member in appearances.descriptions:
				var descriptor: Dictionary = appearances.descriptions[member]
				if not game.members.has(member) or FileAccess.get_sha256(descriptor.glb)!=descriptor.sha256 or hashes.has(descriptor.sha256):
					printerr("Invalid group avatar attribution member=",member," admitted=",game.members.has(member)," hash_match=",FileAccess.get_sha256(descriptor.glb)==descriptor.sha256," duplicate=",hashes.has(descriptor.sha256)); quit(1); return false
				hashes.append(descriptor.sha256)
			print("GROUP AVATARS PASS unique peers=",hashes.size())
		stage=1
		write_report({"stage":"rematch","result":result_hash,"scores":strokes,"starter":game.world.turn,"roster":game.world.roster,"seat":game.seat,"decision":decision,"server_match":server_match,"next_match":game.scorecards.match_id,"board_rows":board_rows})
	elif stage==1 and game.phase=="menu":
		stage=2
		write_report({"stage":"revoked","result":result_hash,"scores":strokes,"starter":1})
		quit(0)
	return false
