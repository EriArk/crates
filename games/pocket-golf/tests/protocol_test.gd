# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Match = preload("res://scripts/match.gd")
const Client = preload("res://scripts/group_client.gd")
var failures := 0
func check(ok: bool, what: String) -> void:
	if not ok: failures+=1; printerr("FAIL ",what)
func _initialize() -> void: call_deferred("run")
func prepare(game) -> void:
	game.local(5,[[0,1],[2,3,4]]); game.accept_turn()
	game.online=true; game.host=false; game.seat=4
	game.members=["a","b","c","d","e"]
	game.bridge.session={"self":"e","hostMember":"a"}
func run() -> void:
	var game := Match.new(); root.add_child(game)
	game.bridge.endpoint_override="user://absent-golf-host.json"; game.join()
	check(game.phase=="menu" and not game.online,"offline fallback")
	for bad in [NAN,INF,-1,36000,"90",0.5]:
		prepare(game); var before: String = game.world.digest()
		game._receive_member("a",{"type":"shot","round":1,"actor":0,"ply":0,"angle_units":bad,"power_units":7500,"before":before,"after":"forged"})
		check(game.phase=="menu" and game.world.digest()==before,"reject malformed commit atomically")
	prepare(game); var before: String = game.world.digest()
	var sender = game.world.copy(); sender.fire(0.37,65.23)
	var packet := {"type":"shot","round":1,"actor":0,"ply":0,"angle_units":37,"power_units":6523,"before":before,"after":sender.digest()}
	game._receive_member("b",packet)
	check(game.phase=="menu" and game.world.digest()==before,"peer cannot forge host commit")
	prepare(game); game._receive_member("a",packet)
	check(game.phase=="moving" and game.world.digest()==sender.digest(),"host commit independently replayed")
	prepare(game); game.host=true
	game._receive_member("b",{"type":"putt","round":1,"actor":0,"ply":0,"angle_units":0,"power_units":7500,"before":game.world.digest()})
	check(game.phase=="menu" and game.world.digest()==before,"teammate cannot take current actor turn")
	var client := Client.new(); root.add_child(client)
	client.active=true; client.registered=true
	client._packet({"event":"network.ready","session":{"protocol":"pocket-golf.6"}})
	check(not client.active,"duet protocol cannot enter team game")
	client.active=true; client.registered=true
	client._packet({"event":"context.revoked"})
	check(not client.active and client.channels.is_empty(),"profile revokes all grants")
	game.queue_free(); client.queue_free(); await process_frame
	print("PROTOCOL ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
