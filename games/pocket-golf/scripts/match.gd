# SPDX-License-Identifier: GPL-3.0-or-later
extends Node
const Rules = preload("res://scripts/rules.gd")
const Client = preload("res://addons/traineros/client.gd")
signal changed
signal shot_started(shot: Dictionary)
var world = Rules.new()
var bridge = Client.new()
var phase := "menu"
var online := false
var seat := 0
var round_id := 0
var angle := 0
var power := 75
var voted := false
var peer_voted := false
var info := "A little green. A good time."
var sync := ""
var deadline := 0
var deferred_shot: Dictionary = {}

func _ready() -> void:
	add_child(bridge)
	bridge.status.connect(func(text): info=text; changed.emit())
	bridge.closed.connect(func():
		if online:
			online=false; phase="menu"; sync=""; deferred_shot.clear(); changed.emit())
	bridge.session_ready.connect(_session)
	bridge.record.connect(_receive)
	world.setup(1)

func _process(_delta: float) -> void:
	if not sync.is_empty() and Time.get_ticks_msec()>deadline: invalid()

func local(count: int) -> void:
	online = false
	bridge.disconnect_host()
	round_id = 1
	world.setup(count)
	_reset()
	phase = "handoff"
	changed.emit()

func join() -> void:
	if phase not in ["menu","waiting"]: return
	online = true
	phase = "waiting"
	changed.emit()
	bridge.connect_host()

func leave() -> void:
	online = false
	bridge.close_channel()
	phase = "menu"
	sync = ""
	deferred_shot.clear()
	changed.emit()

func can_fire() -> bool:
	return phase=="aim" and not world.complete and (not online or world.turn==seat)

func accept_turn() -> void:
	if phase=="handoff": phase="aim"; changed.emit()

func adjust(aim_delta: int, power_delta: int) -> void:
	if can_fire():
		angle = posmod(angle+aim_delta*5,360)
		power = clampi(power+power_delta*5,10,100)
		changed.emit()

func _reset() -> void:
	angle = 0
	power = 75
	voted = false
	peer_voted = false
	deferred_shot.clear()

func fire() -> void:
	if not can_fire(): return
	var before: String = world.digest()
	var ply: int = world.ply
	var shot: Dictionary = world.fire(angle,power)
	if online and not send({"type":"shot","ply":ply,"angle":angle,"power":power,"before":before,"after":world.digest()}): return
	phase = "moving"
	shot_started.emit(shot)
	changed.emit()

func finish_shot() -> void:
	if phase!="moving": return
	phase = "result" if world.complete else "aim" if online else "handoff"
	if not deferred_shot.is_empty():
		var next := deferred_shot.duplicate(true)
		deferred_shot.clear()
		_receive(next)
	changed.emit()

func rematch() -> void:
	if phase!="result" or voted: return
	if not online:
		round_id += 1
		world.setup(world.players,(round_id-1)%world.players)
		_reset()
		phase = "handoff"
		changed.emit()
		return
	voted = true
	if not send({"type":"rematch","hash":world.digest()}): return
	if seat==0 and peer_voted: _host_round()
	changed.emit()

func send(data: Dictionary) -> bool:
	data["round"] = round_id
	if bridge.send(data): return true
	invalid()
	return false

func invalid() -> void:
	leave()
	info = "The match could not stay in sync. Return to Lobby for a fresh round."
	changed.emit()

func _session(host: bool) -> void:
	if not online: bridge.close_channel(); return
	seat = 0 if host else 1
	round_id = 0
	phase = "waiting"
	sync = "start"
	deadline = Time.get_ticks_msec()+10000
	if host: _host_round()

func _host_round() -> void:
	round_id += 1
	world.setup(2,(round_id-1)%2)
	_reset()
	phase = "waiting"
	sync = "ready"
	deadline = Time.get_ticks_msec()+10000
	send({"type":"start","hash":world.digest()})
	changed.emit()

func _receive(data: Dictionary) -> void:
	if not online: return
	var kind = data.get("type")
	if kind=="start":
		if seat!=1 or data.get("round")!=round_id+1 or not (sync=="start" or (world.complete and voted and peer_voted)):
			invalid(); return
		round_id += 1
		world.setup(2,(round_id-1)%2)
		_reset()
		phase = "waiting"
		sync = "begin"
		deadline = Time.get_ticks_msec()+10000
		if data.get("hash")!=world.digest(): invalid(); return
		send({"type":"ready","hash":world.digest()})
		changed.emit()
		return
	if data.get("round")!=round_id: invalid(); return
	if kind=="ready" and seat==0 and sync=="ready" and data.get("hash")==world.digest():
		if not send({"type":"begin","hash":world.digest()}): return
		sync=""; phase="aim"; changed.emit(); return
	if kind=="begin" and seat==1 and sync=="begin" and data.get("hash")==world.digest():
		sync=""; phase="aim"; changed.emit(); return
	if kind=="shot" and sync.is_empty() and phase in ["aim","moving"] and not world.complete and world.turn!=seat:
		var a = data.get("angle",-1)
		var p = data.get("power",-1)
		if not (a is float or a is int) or not (p is float or p is int): invalid(); return
		if a!=int(a) or p!=int(p) or a<0 or a>=360 or int(a)%5!=0 or p<10 or p>100 or int(p)%5!=0 or data.get("ply")!=world.ply or data.get("before")!=world.digest(): invalid(); return
		if phase=="moving":
			if not deferred_shot.is_empty(): invalid(); return
			deferred_shot=data.duplicate(true); return
		# Apply on an independent candidate so forged outcomes never replace the world.
		var candidate = Rules.new()
		candidate.players=world.players; candidate.hole=world.hole; candidate.turn=world.turn
		candidate.starter=world.starter; candidate.ply=world.ply
		candidate.balls=world.balls.duplicate(true); candidate.strokes=world.strokes.duplicate()
		candidate.finished=world.finished.duplicate(); candidate.scores=world.scores.duplicate(true)
		var shot: Dictionary = candidate.fire(int(a),int(p))
		if data.get("after")!=candidate.digest(): invalid(); return
		world=candidate; phase="moving"; shot_started.emit(shot); changed.emit(); return
	if kind=="rematch" and world.complete and not peer_voted and sync.is_empty() and data.get("hash")==world.digest():
		peer_voted=true
		if seat==0 and voted: _host_round()
		changed.emit(); return
	invalid()
