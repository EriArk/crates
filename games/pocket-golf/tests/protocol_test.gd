# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Match = preload("res://scripts/match.gd")
const Client = preload("res://scripts/group_client.gd")
var failures := 0
class QueuedClient extends Client:
	var requests: Array = []
	func request(method: String, params: Dictionary = {}) -> bool:
		if pending.size()>=64: return false
		requests.append([method,params.duplicate(true)]); pending[str(requests.size())]={}
		return true
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
	var queued := QueuedClient.new()
	queued.channel="grant"; queued.channels={"peer":"grant"}; queued.sequences={"grant":0}
	for i in 64: queued.pending[str(i)]={}
	for i in 3:
		queued._packet({"event":"network.data","channel":"grant","peer":"peer","sequence":str(i),"data":Marshalls.utf8_to_base64('{"type":"ping"}')})
	check(queued.consumes.size()==3 and queued.requests.is_empty(),"full RPC queue retains every consumption acknowledgement")
	queued.pending.clear()
	for i in 40: check(queued.send_to("peer",{"n":i}),"bounded send admission")
	queued._drain_queues()
	check(queued.requests[0]==["network.consume",{"channel":"grant","sequence":"0"}] and queued.requests[2][1].sequence=="2","consumes drain first and in sequence")
	check(queued.outstanding.grant==21 and queued.records.size()==19,"bulk fan-out leaves request headroom")
	queued.pending.clear(); queued._drain_queues()
	check(queued.outstanding.grant==24 and queued.records.size()==16,"channel credits bound unacknowledged records")
	queued.pending.clear(); queued._packet({"event":"network.ack","channel":"grant"}); queued._drain_queues()
	check(queued.outstanding.grant==24 and queued.records.size()==15,"credit returns permit exactly one further send")
	queued.free(); game.queue_free(); client.queue_free(); await process_frame
	print("PROTOCOL ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
