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
var angle := 0.0
var power := 75.0
var voted := false
var peer_voted := false
var info := "A little green. A good time."
var sync := ""
var deadline := 0
var deferred_shot: Dictionary = {}
var preview_wait := 0.0
var last_preview: Array = []
var peer_preview: Dictionary = {}

func _ready() -> void:
	add_child(bridge)
	bridge.status.connect(func(text): info=text; changed.emit())
	bridge.closed.connect(func():
		if online:
			online=false; phase="menu"; sync=""; deferred_shot.clear(); changed.emit())
	bridge.session_ready.connect(_session)
	bridge.record.connect(_receive)
	world.setup(1)

func _process(delta: float) -> void:
	if not sync.is_empty() and Time.get_ticks_msec()>deadline: invalid()
	if not online or not sync.is_empty(): return
	if can_fire():
		preview_wait=maxf(0.0,preview_wait-delta)
		var current := [world.ply,posmod(roundi(angle*100),36000),roundi(power*100)]
		# Coalesce changes at 15 Hz. Cosmetic preparation must not fill the
		# reliable channel's request queue or displace an authoritative putt.
		if preview_wait==0 and current!=last_preview and bridge.pending.size()<8:
			if bridge.send({"type":"aim","round":round_id,"ply":current[0],"angle_units":current[1],"power_units":current[2]}):
				last_preview=current; preview_wait=1.0/15.0
	elif phase=="aim" and peer_preview.get("ply",-1)==world.ply:
		var target: float = peer_preview.angle_units/100.0
		var target_power: float = peer_preview.power_units/100.0
		var blend := 1.0-exp(-20.0*delta)
		var next_angle := fposmod(rad_to_deg(lerp_angle(deg_to_rad(angle),deg_to_rad(target),blend)),360.0)
		var next_power := lerpf(power,target_power,blend)
		if absf(wrapf(target-angle,-180,180))<0.01: next_angle=target
		if absf(target_power-power)<0.01: next_power=target_power
		if next_angle!=angle or next_power!=power:
			angle=next_angle; power=next_power; changed.emit()

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
	peer_preview.clear(); last_preview.clear(); preview_wait=0
	changed.emit()

func can_fire() -> bool:
	return phase=="aim" and not world.complete and (not online or world.turn==seat)

func accept_turn() -> void:
	if phase=="handoff": phase="aim"; changed.emit()

func adjust(aim_delta: int, power_delta: int) -> void:
	adjust_continuous(aim_delta*5.0,power_delta*5.0)

func adjust_continuous(degrees: float, percent: float) -> void:
	if can_fire():
		angle = fposmod(angle+degrees,360.0)
		power = clampf(power+percent,10.0,100.0)
		changed.emit()

func _reset() -> void:
	angle = 0
	power = 75
	voted = false
	peer_voted = false
	deferred_shot.clear()
	peer_preview.clear(); last_preview.clear(); preview_wait=0

func fire() -> void:
	if not can_fire(): return
	var before: String = world.digest()
	var ply: int = world.ply
	var aim_units := posmod(roundi(angle*100),36000)
	var power_units := roundi(power*100)
	var shot: Dictionary = world.fire_units(aim_units,power_units)
	if online and not send({"type":"shot","ply":ply,"angle_units":aim_units,"power_units":power_units,"before":before,"after":world.digest()}): return
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
	if phase not in ["menu","waiting"]: bridge.close_channel(); return
	online = true
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
	if kind=="aim" and sync.is_empty() and phase in ["aim","moving"]:
		if not _valid_aim(data): invalid(); return
		var preview_ply = data.get("ply",-1)
		if not (preview_ply is int or preview_ply is float) or not is_finite(float(preview_ply)) or preview_ply<0 or preview_ply!=int(preview_ply): invalid(); return
		if preview_ply<world.ply: return # A previous turn's cosmetic update.
		if preview_ply!=world.ply or world.turn==seat or world.complete: invalid(); return
		peer_preview=data.duplicate(true)
		return
	if kind=="ready" and seat==0 and sync=="ready" and data.get("hash")==world.digest():
		if not send({"type":"begin","hash":world.digest()}): return
		sync=""; phase="aim"; changed.emit(); return
	if kind=="begin" and seat==1 and sync=="begin" and data.get("hash")==world.digest():
		sync=""; phase="aim"; changed.emit(); return
	if kind=="shot" and sync.is_empty() and phase in ["aim","moving"] and not world.complete and world.turn!=seat:
		var a = data.get("angle_units",-1)
		var p = data.get("power_units",-1)
		if not _valid_aim(data) or data.get("ply")!=world.ply or data.get("before")!=world.digest(): invalid(); return
		if phase=="moving":
			if not deferred_shot.is_empty(): invalid(); return
			deferred_shot=data.duplicate(true); return
		# Apply on an independent candidate so forged outcomes never replace the world.
		var candidate = Rules.new()
		candidate.players=world.players; candidate.hole=world.hole; candidate.turn=world.turn
		candidate.starter=world.starter; candidate.ply=world.ply
		candidate.balls=world.balls.duplicate(true); candidate.strokes=world.strokes.duplicate()
		candidate.finished=world.finished.duplicate(); candidate.scores=world.scores.duplicate(true)
		var shot: Dictionary = candidate.fire_units(int(a),int(p))
		if data.get("after")!=candidate.digest(): invalid(); return
		angle=a/100.0; power=p/100.0; peer_preview.clear()
		world=candidate; phase="moving"; shot_started.emit(shot); changed.emit(); return
	if kind=="rematch" and world.complete and not peer_voted and sync.is_empty() and data.get("hash")==world.digest():
		peer_voted=true
		if seat==0 and voted: _host_round()
		changed.emit(); return
	invalid()

func _valid_aim(data: Dictionary) -> bool:
	var a = data.get("angle_units",-1)
	var p = data.get("power_units",-1)
	if not (a is float or a is int) or not (p is float or p is int): return false
	if not is_finite(float(a)) or not is_finite(float(p)) or a<0 or a>=36000 or p<1000 or p>10000: return false
	return a==int(a) and p==int(p)
