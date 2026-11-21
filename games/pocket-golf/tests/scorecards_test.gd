# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Cards = preload("res://scripts/scorecards.gd")
const Client = preload("res://addons/traineros/client.gd")
const PLAYER := "11111111-1111-4111-8111-111111111111"
const KEY := "22222222-2222-4222-8222-222222222222"
var failures := 0
class Fake extends Client:
	var calls: Array = []
	func request(method: String, params: Dictionary = {}, callback: Callable = Callable()) -> bool:
		calls.append([method,params.duplicate(true),callback]); return true
	func answer(result: Dictionary, error: String = "") -> void:
		var call: Array = calls.pop_front(); call[2].call(JSON.parse_string(JSON.stringify(result)),error)
func check(ok: bool, label: String) -> void:
	if not ok: failures+=1; printerr("FAIL ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var client := Fake.new(); root.add_child(client)
	client.registered=true; client.active=true; client.capabilities={"play.scorecards":1}
	var cards := Cards.new(); root.add_child(cards); cards.bind(client)
	cards.journal_path="user://scorecards-test-"+Cards.operation_id()+".json"
	cards.new_round(JSON.parse_string("[[1,2],[0,3,4]]"),0)
	check(cards.side_order==[1,0],"creator side mapping preserves arbitrary team selection")
	cards.create_round([[1,2],[0,3,4]],func(_v,e): check(e.is_empty(),"create completed"))
	client.answer({"account":{"state":"signed_in","player_id":PLAYER}})
	client.answer({"ruleset":{"id":Cards.RULESET}})
	check(client.calls[0][1].payload.seats==[3,2],"server roster uses mapped sides")
	check(FileAccess.file_exists(cards.journal_path),"mutation persisted before send")
	client.answer({"match":{"id":KEY}})
	cards.join_round(KEY,JSON.parse_string("[[1,2],[0,3,4]]"),2,func(_v,e): check(e.is_empty(),"JSON roster join completed"))
	client.answer({"account":{"state":"signed_in","player_id":PLAYER}})
	check(client.calls[0][1].payload.side==1,"JSON numeric seats resolve to the correct team")
	client.answer({"match":{"seats":[3,2],"state":"waiting","ruleset_id":Cards.RULESET}})
	cards.activate(KEY); cards.finish([[4,5,6],[2,3,4]])
	var command: Dictionary = client.calls[0][1].duplicate(true)
	check(command.payload.scores[0].values==[2,3,4],"shared score follows server side mapping")
	client.answer({},"timeout")
	check(not cards.busy and cards.message.contains("pending"),"lost response remains pending")
	cards.retry_result(); client.answer({"account":{"state":"signed_in","player_id":PLAYER}})
	check(client.calls[0][1]==command,"explicit retry preserves operation and complete payload")
	client.answer({}); cards.poll_at=0
	cards.reset(); client.registered=true; client.capabilities={"play.scorecards":1}
	cards.retry_result(); client.answer({"account":{"state":"signed_in","player_id":KEY}})
	client.answer({"ruleset":{"id":Cards.RULESET}})
	check(client.calls.is_empty() and cards.board_message.contains("No pending"),"new owner cannot replay previous owner's result")
	cards.fetch_board("individual","records"); client.answer({"account":{"state":"signed_in","player_id":KEY}})
	var late: Callable = client.calls.pop_front()[2]
	cards.reset(); late.call({"items":[{"value":1}]},"")
	check(cards.board.is_empty(),"owner change fences a late table callback")
	var transport := Client.new(); root.add_child(transport); transport.active=true
	var replies: Array = []
	transport.request("play.board",{},func(_r,e): replies.append(e))
	transport._packet({"id":str(transport.serial),"error":{"code":"sign_in_required"}})
	check(transport.active and replies==["sign_in_required"],"backend errors never close gameplay transport")
	transport.ignored.append("old"); transport._packet({"id":"old","result":{}})
	check(transport.active,"late timed-out response does not break network framing")
	check(Cards.uuid_valid(Cards.operation_id()) and not Cards.uuid_valid("wrong"),"bounded canonical operation identity")
	DirAccess.remove_absolute(cards.journal_path)
	client.disconnect_host(); transport.disconnect_host()
	cards.queue_free(); client.queue_free(); transport.queue_free(); await process_frame
	print("SCORECARDS ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(0 if failures==0 else 1)
