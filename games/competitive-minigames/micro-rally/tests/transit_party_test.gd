# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Party = preload("res://addons/trainer_transit/party.gd")

class Bridge extends Node:
	signal member_record(peer: String, data: Dictionary)
	signal closed
	var session: Dictionary
	var records := []
	var pending := {}
	func send(data): records.append(data)

class MatchSession extends Node:
	var bridge := Bridge.new()
	var round_id := 2
	func _init(): add_child(bridge)

func _initialize():
	var host:=MatchSession.new()
	var guest:=MatchSession.new()
	var roster:=[{"id":"a"},{"id":"b"},{"id":"c"}]
	var a:=Party.new()
	var b:=Party.new()
	host.bridge.session={"host":true,"self":"a","members":roster,"hostMember":"a"}
	guest.bridge.session={"host":false,"self":"b","members":roster,"hostMember":"a"}
	a.bind(host)
	b.bind(guest)
	a.admit()
	b.admit()
	b.tick(.13,true,Vector2.RIGHT)
	host.bridge.member_record.emit("b",guest.bridge.records.back())
	host.bridge.member_record.emit("c",{"type":"ping","egregore_v1":[0,-100]})
	host.bridge.member_record.emit("c",{"type":"ping","egregore_v1":[0,1000]})
	host.bridge.member_record.emit("imposter",{"type":"ping","egregore_v1":[-100,0]})
	a.tick(.13,true,Vector2.LEFT)
	var packet:Dictionary=host.bridge.records.back()
	var ok:bool=packet=={"type":"ping","round":2,"egregore_v1":[-100,0,100,0,0,-100]}
	guest.bridge.member_record.emit("c",packet)
	ok=ok and not b.poses.has("a")
	guest.bridge.member_record.emit("a",packet)
	ok=ok and b.poses["a"]==Vector2.LEFT and b.poses["c"]==Vector2.UP
	host.bridge.closed.emit()
	guest.bridge.closed.emit()
	ok=ok and a.roster.is_empty() and b.poses.is_empty()
	host.free()
	guest.free()
	print("Transit formation regression: ",ok)
	quit(0 if ok else 1)
