# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Match = preload("res://scripts/match.gd")
const Client = preload("res://addons/traineros/client.gd")
var failures := 0

func check(value: bool, name: String) -> void:
	if not value: failures+=1; printerr("FAIL ",name)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game := Match.new(); root.add_child(game)
	game.bridge.endpoint_override="user://missing-sdk-test.json"
	game.join(); check(game.phase=="menu" and not game.online,"missing host fallback")
	game.local(2); game.accept_turn(); check(game.can_fire(),"local remains available")
	game.online=true; game.seat=1; game.round_id=1
	var before: String = game.world.digest()
	game._receive({"type":"shot","round":1,"ply":0,"angle":0,"power":75,"before":before,"after":"fabricated"})
	check(game.phase=="menu" and game.world.digest()==before,"forged outcome rejected without committing")
	game.local(2); game.accept_turn(); game.online=true; game.seat=0
	game._receive({"type":"shot","round":1,"ply":0,"angle":0,"power":75,"before":before,"after":"fabricated"})
	check(game.phase=="menu" and game.world.digest()==before,"out of turn rejected")
	game.local(2); game.accept_turn(); game.online=true; game.seat=1
	game._receive({"type":"shot","round":1,"ply":0,"angle":0.5,"power":75,"before":before,"after":"fabricated"})
	check(game.phase=="menu" and game.world.digest()==before,"fractional angle rejected")
	var client := Client.new(); root.add_child(client)
	client.active=true; client.registered=true
	client._packet({"event":"network.ready","session":{"channel":"fixture","protocol":"wrong","host":true,"delivery":"reliable-ordered"}})
	check(not client.active and client.channel.is_empty(),"protocol mismatch rejected")
	client.active=true; client.registered=true; client.channel="fixture"; client.sequence=0
	client._packet({"event":"network.data","channel":"fixture","sequence":"1","data":Marshalls.utf8_to_base64("{}")})
	check(not client.active,"out of order SDK sequence rejected")
	client.active=true; client.registered=true; client.channel="fixture"
	client._packet({"event":"context.revoked","reason":"profile_changed"})
	check(not client.active and not client.registered and client.channel.is_empty(),"profile revocation clears grants")
	print("PROTOCOL ","PASS" if failures==0 else "FAIL", " failures=",failures)
	quit(0 if failures==0 else 1)
