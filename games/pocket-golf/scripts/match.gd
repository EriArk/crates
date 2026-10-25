# SPDX-License-Identifier: GPL-3.0-or-later
extends Node
const Rules = preload("res://scripts/rules.gd")
const Client = preload("res://scripts/group_client.gd")
const Bot = preload("res://scripts/golf_bot.gd")
signal changed
signal shot_started(shot: Dictionary)
signal round_started
var world = Rules.new()
var bridge = Client.new()
var bot = Bot.new()
var phase := "menu"
var online := false
var solo_bot := false
var seat := 0
var round_id := 0
var angle := 0.0
var power := 75.0
var voted := false
var peer_voted := false
var info := "A little green. A good time."
var sync := ""
var deadline := 0
var preview_wait := 0.0
var last_preview: Array = []
var peer_preview: Dictionary = {}
var members: Array = []
var host := false
var participant_count := 1
var votes: Array = []
var ready_seats: Array = []
var chosen_roster: Array = [[0]]
var seen: Dictionary = {}
var heartbeat_at := 0

func _ready() -> void:
	add_child(bridge)
	bridge.status.connect(func(text): info=text; changed.emit())
	bridge.closed.connect(func():
		if online:
			online=false; phase="menu"; sync=""; members.clear(); changed.emit())
	bridge.session_ready.connect(_session)
	bridge.member_record.connect(_receive_member)
	world.setup(1)

func _process(delta: float) -> void:
	if not online: return
	var now := Time.get_ticks_msec()
	if not sync.is_empty() and now>deadline: invalid(); return
	if now>=heartbeat_at:
		heartbeat_at=now+1000
		if bridge.pending.size()<16: bridge.send({"type":"ping"})
	for member in seen:
		if now-seen[member]>15000: invalid(); return
	if not sync.is_empty(): return
	if can_fire():
		preview_wait=maxf(0.0,preview_wait-delta)
		var current := [world.ply,posmod(roundi(angle*100),36000),roundi(power*100)]
		if preview_wait==0 and current!=last_preview and bridge.pending.size()<8:
			if send({"type":"aim","actor":seat,"ply":current[0],"angle_units":current[1],"power_units":current[2]}):
				last_preview=current; preview_wait=1.0/15.0
	elif phase=="aim" and peer_preview.get("ply",-1)==world.ply:
		var blend := 1.0-exp(-20.0*delta)
		angle=fposmod(rad_to_deg(lerp_angle(deg_to_rad(angle),deg_to_rad(peer_preview.angle_units/100.0),blend)),360.0)
		power=lerpf(power,peer_preview.power_units/100.0,blend)
		changed.emit()

func local(count: int, roster: Array = [], opponent: bool = false) -> void:
	var next: Array = Rules.default_roster(count) if roster.is_empty() else roster
	if not Rules.valid_roster(next,count): return
	online=false; solo_bot=opponent and count==2; seat=0; host=false
	bridge.disconnect_host(); members.clear()
	participant_count=count; chosen_roster=next.duplicate(true)
	round_id=1; world.setup_roster(chosen_roster)
	_reset(); phase="handoff"; round_started.emit(); changed.emit()

func join() -> void:
	if phase not in ["menu","waiting"]: return
	online=true; solo_bot=false; phase="waiting"; changed.emit(); bridge.connect_host()

func leave() -> void:
	online=false; solo_bot=false; bridge.close_channel()
	phase="menu"; sync=""; members.clear(); bot.cancel()
	peer_preview.clear(); last_preview.clear(); changed.emit()

func can_fire() -> bool:
	return phase=="aim" and sync.is_empty() and not world.complete and (world.actor()==seat if online else not solo_bot or world.actor()==0)

func accept_turn() -> void:
	if phase=="handoff": phase="aim"; changed.emit()

func adjust(aim_delta: int, power_delta: int) -> void: adjust_continuous(aim_delta*5.0,power_delta*5.0)
func adjust_continuous(degrees: float, percent: float) -> void:
	if can_fire():
		angle=fposmod(angle+degrees,360.0); power=clampf(power+percent,10,100); changed.emit()

func tick_bot(delta: float) -> void:
	if online or not solo_bot or phase!="aim" or world.actor()!=1: return
	var command: Array = bot.tick(world,delta)
	if command.is_empty(): return
	angle=command[0]; power=command[1]
	_apply_shot(world.fire(angle,power))

func _reset() -> void:
	angle=0; power=75; voted=false; peer_voted=false
	sync=""; votes.clear(); ready_seats.clear(); peer_preview.clear(); last_preview.clear(); preview_wait=0; bot.cancel()

func fire() -> void:
	if not can_fire(): return
	var command := {"type":"putt","ply":world.ply,"actor":world.actor(),"angle_units":posmod(roundi(angle*100),36000),"power_units":roundi(power*100),"before":world.digest()}
	if not online: _apply_shot(world.fire_units(command.angle_units,command.power_units))
	elif host: _host_shot(command)
	else:
		if send(command): sync="shot"; deadline=Time.get_ticks_msec()+10000; changed.emit()

func _apply_shot(shot: Dictionary) -> void:
	peer_preview.clear(); last_preview.clear(); sync=""; phase="moving"
	shot_started.emit(shot); changed.emit()

func finish_shot() -> void:
	if phase!="moving": return
	if not online:
		phase="result" if world.complete else "aim" if solo_bot and world.actor()==1 else "handoff"
	else:
		phase="waiting_turn"; sync="settled"; deadline=Time.get_ticks_msec()+30000
		if host: ready_seats.append(seat); _begin_turn_if_ready()
		else: send({"type":"settled","hash":world.digest()})
	changed.emit()

func _begin_turn_if_ready() -> void:
	if not host or ready_seats.size()!=participant_count: return
	if not send({"type":"turn","hash":world.digest()}): return
	ready_seats.clear(); sync=""; phase="result" if world.complete else "aim"; changed.emit()

func rematch() -> void:
	if phase!="result" or voted: return
	if not online:
		round_id+=1; world.setup_roster(chosen_roster,(round_id-1)%chosen_roster.size())
		_reset(); phase="handoff"; round_started.emit(); changed.emit(); return
	voted=true
	if host: _vote(seat)
	else: send({"type":"rematch","hash":world.digest()})
	changed.emit()

func _vote(member_seat: int) -> void:
	if votes.has(member_seat): invalid(); return
	votes.append(member_seat)
	if votes.size()==participant_count: _host_round()

func send(data: Dictionary) -> bool:
	data["round"]=round_id
	if bridge.send(data): return true
	invalid(); return false

func invalid() -> void:
	leave(); info="The match could not stay in sync. Return to Lobby for a fresh round."; changed.emit()

func _session(is_host: bool) -> void:
	if phase not in ["menu","waiting"]: bridge.close_channel(); return
	online=true; solo_bot=false; host=is_host; members.clear(); seen.clear()
	for member in bridge.session.members: members.append(member.id)
	seat=members.find(bridge.session.self); participant_count=members.size()
	if participant_count==3:
		leave(); info="Choose 2 or 4 individual players, or 4-8 players in teams."; changed.emit(); return
	for peer in bridge.channels: seen[peer]=Time.get_ticks_msec()
	round_id=0; _reset(); phase="setup" if host else "waiting"
	info="The host is choosing players and teams."
	chosen_roster=Rules.default_roster(participant_count)
	changed.emit()

func start_group(roster: Array) -> void:
	if not online or not host or phase!="setup" or not Rules.valid_roster(roster,participant_count): return
	chosen_roster=roster.duplicate(true); _host_round()

func _host_round() -> void:
	round_id+=1; world.setup_roster(chosen_roster,(round_id-1)%chosen_roster.size()); _reset()
	phase="waiting"; sync="ready"; deadline=Time.get_ticks_msec()+15000; ready_seats=[seat]
	send({"type":"start","roster":chosen_roster,"hash":world.digest()})
	round_started.emit(); changed.emit()

func _host_shot(data: Dictionary) -> void:
	if not _valid_shot(data) or phase!="aim" or not sync.is_empty(): invalid(); return
	var candidate = world.copy()
	var shot: Dictionary = candidate.fire_units(int(data.angle_units),int(data.power_units))
	var commit := data.duplicate(true); commit.type="shot"; commit["after"]=candidate.digest()
	if not send(commit): return
	world=candidate; ready_seats.clear(); angle=data.angle_units/100.0; power=data.power_units/100.0
	_apply_shot(shot)

func _receive_member(member: String, data: Dictionary) -> void:
	if not online or not members.has(member) or member==bridge.session.get("self"): return
	seen[member]=Time.get_ticks_msec()
	var kind = data.get("type")
	if data.get("namespace")=="traineros.avatar.v1": return # Avatar roster consumes this separately.
	if kind=="ping": return
	var sender: int = members.find(member)
	var from_host: bool = member==bridge.session.get("hostMember")
	if kind=="start" and not host and from_host:
		var roster = data.get("roster")
		if data.get("round")!=round_id+1 or not (round_id==0 or world.complete and voted) or not roster is Array or not Rules.valid_roster(roster,participant_count): invalid(); return
		var candidate = Rules.new(); candidate.setup_roster(roster,round_id%roster.size())
		if data.get("hash")!=candidate.digest(): invalid(); return
		round_id+=1; chosen_roster=roster.duplicate(true); world=candidate; _reset()
		phase="waiting"; sync="begin"; deadline=Time.get_ticks_msec()+15000
		send({"type":"ready","hash":world.digest()}); round_started.emit(); changed.emit(); return
	if data.get("round")!=round_id: invalid(); return
	if kind=="ready" and host and sync=="ready" and not ready_seats.has(sender) and data.get("hash")==world.digest():
		ready_seats.append(sender)
		if ready_seats.size()==participant_count:
			if send({"type":"begin","hash":world.digest()}): sync=""; ready_seats.clear(); phase="aim"; changed.emit()
		return
	if kind=="begin" and not host and from_host and sync=="begin" and data.get("hash")==world.digest():
		sync=""; phase="aim"; changed.emit(); return
	if kind=="aim":
		if not _valid_aim(data): invalid(); return
		if data.get("ply",-1)<world.ply: return
		if data.get("ply")!=world.ply or data.get("actor")!=world.actor() or (sender!=world.actor() if host else not from_host) or world.complete or phase!="aim": invalid(); return
		if host and not send(data): return
		peer_preview=data.duplicate(true); return
	if kind=="putt" and host and sender==world.actor(): _host_shot(data); return
	if kind=="shot" and not host and from_host and phase=="aim" and sync in ["","shot"] and _valid_shot(data):
		var candidate = world.copy(); var shot: Dictionary = candidate.fire_units(int(data.angle_units),int(data.power_units))
		if data.get("after")!=candidate.digest(): invalid(); return
		world=candidate; angle=data.angle_units/100.0; power=data.power_units/100.0; _apply_shot(shot); return
	if kind=="settled" and host and phase in ["moving","waiting_turn"] and not ready_seats.has(sender) and data.get("hash")==world.digest():
		ready_seats.append(sender); _begin_turn_if_ready(); return
	if kind=="turn" and not host and from_host and sync=="settled" and data.get("hash")==world.digest():
		sync=""; phase="result" if world.complete else "aim"; changed.emit(); return
	if kind=="rematch" and host and world.complete and phase in ["result","waiting_turn","moving"] and data.get("hash")==world.digest(): _vote(sender); return
	invalid()

func _valid_shot(data: Dictionary) -> bool:
	return not world.complete and _valid_aim(data) and data.get("actor")==world.actor() and data.get("ply")==world.ply and data.get("before")==world.digest()

func _valid_aim(data: Dictionary) -> bool:
	for entry in [["angle_units",0,35999],["power_units",1000,10000],["ply",0,10000],["actor",0,participant_count-1]]:
		var value = data.get(entry[0])
		if not (value is float or value is int) or not is_finite(float(value)) or value!=int(value) or value<entry[1] or value>entry[2]: return false
	return true

func _exit_tree() -> void: bot.cancel()
