# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://addons/traineros/avatar_client.gd"
signal other_toss(at: Vector2)
signal state_changed
var available := false
var snapshot: Dictionary = {}
var message := "Connecting to TrainerOS…"
var poll := 0.0
var queued_action := ""

func _ready() -> void:
	app_id="org.traineros.bazaar.festival"
	unavailable.connect(func(reason):
		available=false
		snapshot={}
		queued_action=""
		message="Offline · play here with one controller." if reason.contains("not available") else reason
		state_changed.emit())
	_connect_after_draw.call_deferred()

func _connect_after_draw() -> void:
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
	connect_host()

func toss(at: Vector2) -> void:
	if available and pending.size()<3:
		_request("activity.cup.toss",{"x":roundi(at.x*100),"z":roundi(at.y*100)})

func action(verb: String) -> void:
	if not available:return
	if pending.is_empty():_request("activity.cup."+verb)
	elif verb!="status":queued_action=verb

func _process(delta: float) -> void:
	super._process(delta)
	if not available:return
	if not queued_action.is_empty() and pending.is_empty():
		var verb:=queued_action
		queued_action=""
		action(verb)
	poll-=delta
	if poll<=0 and pending.is_empty():
		poll=0.65
		action("status")

func _packet(packet: Dictionary) -> void:
	if packet.has("event"):
		if packet.event=="festival.ring":
			other_toss.emit(Vector2(packet.get("x",0),packet.get("z",0))/100.0)
		if packet.event in ["context.revoked","host.stopping"]:_fail("TrainerOS session ended.")
		return
	var id:String=packet.get("id","")
	if not pending.has(id):_fail("Unexpected festival reply.");return
	var method:String=pending[id].method
	pending.erase(id)
	if packet.has("error"):
		var code:String=packet.error.get("code","")
		message={"need_two":"Form a two-player party in Lobby first.","host_first":"The party host signs up first.","install_golf":"Install matching Pocket Golf versions on both devices.","room_busy":"Finish the current lobby activity first."}.get(code,"Festival service unavailable.")
		state_changed.emit()
		return
	var result=packet.get("result",{})
	if not result is Dictionary:_fail("Invalid festival reply.");return
	if method=="hello":
		available=result.get("capabilities",{}).get("bazaar.cup")==1
		message="" if available else "Online registration needs a festival-enabled TrainerOS host."
	elif result.has("members"):
		if result==snapshot:return
		snapshot=result
		message=""
	state_changed.emit()
