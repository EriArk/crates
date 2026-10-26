# SPDX-License-Identifier: GPL-3.0-or-later
extends Node
const Client = preload("res://addons/traineros/group_client.gd")
const Wire = preload("race_wire.gd")
var bridge = Client.new()
var game: Node3D
var online = false
var host = false
var starting = false
var round_id = 0
var members: Array = []
var ready_members: Array = []
var votes: Array = []
var inputs: Dictionary = {}
var seen: Dictionary = {}
var input_sequences: Dictionary = {}
var sequence = 0
var last_snapshot = -1
var clock = 0.0
var deadline = 0
var phase = "idle"
var targets: Array = []
var received_at = 0
var beams: Array = []
var info = ""
var overlay = false
var voted = false

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS; add_child(bridge)
	bridge.session_ready.connect(_session); bridge.member_record.connect(_receive)
	bridge.closed.connect(_closed)
	bridge.status.connect(func(text): info=text)

func connect_platform() -> void:
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	bridge.connect_host()

func _session(is_host: bool) -> void:
	if online or game.state!="menu": bridge.close_channel(); return
	online=true; host=is_host; members.clear(); inputs.clear(); seen.clear(); input_sequences.clear()
	for member in bridge.session.members: members.append(member.id)
	game.player_index=members.find(bridge.session.self)
	for member in bridge.channels: seen[member]=Time.get_ticks_msec()
	round_id=0; phase="waiting"; game.state="network_wait"; game.hud.panel.hide()
	game.hud.message="Собираем стартовую решётку…"; deadline=Time.get_ticks_msec()+15000
	if host: _prepare()

func _prepare() -> void:
	round_id+=1; ready_members=[bridge.session.self]; votes.clear(); voted=false
	phase="preparing"; deadline=Time.get_ticks_msec()+15000
	game.bot_count=15; starting=true; game.start_race(); starting=false
	game.state="network_wait"; game.hud.message="Ожидаем готовности участников…"
	if not bridge.send({"type":"prepare","round":round_id,"track":Wire.TRACK,"conditions":game.conditions.descriptor(),"laps":4}): abort("Не удалось подготовить заезд.")

func _begin() -> void:
	phase="playing"; game.state="countdown"; game.countdown=3; game.hud.message=""
	sequence=0; last_snapshot=-1; clock=0; inputs.clear(); input_sequences.clear(); targets.clear()
	for member in seen: seen[member]=Time.get_ticks_msec()
	if host and not bridge.send({"type":"begin","round":round_id}): abort("Не удалось начать заезд.")

func _receive(member: String, data: Dictionary) -> void:
	if not online or not bridge.channels.has(member): return
	seen[member]=Time.get_ticks_msec()
	var kind = data.get("type")
	if data.get("namespace")=="traineros.avatar.v1": return
	if kind=="prepare" and not host and member==bridge.session.hostMember:
		if data.get("round")!=round_id+1 or phase not in ["waiting","results"] or (phase=="results" and not voted) or data.get("track")!=Wire.TRACK or data.get("laps")!=4 or not data.get("conditions") is Dictionary:
			abort("Несовместимые условия заезда."); return
		var conditions = game.Conditions.new()
		if not conditions.configure(data.conditions): abort("Неверные условия заезда."); return
		round_id+=1; game.conditions=conditions; game.bot_count=15; starting=true; game.start_race(); starting=false
		for car in game.cars: car.replica=true; car.freeze=true; car.collision_layer=0; car.collision_mask=0
		game.state="network_wait"; phase="preparing"; voted=false; overlay=false; deadline=Time.get_ticks_msec()+15000
		if not bridge.send({"type":"ready","round":round_id}): abort("Не удалось подтвердить готовность.")
		return
	if Wire.integer(data.get("round"),0,round_id-1): return # In-flight old inputs cannot enter a rematch.
	if data.get("round")!=round_id: abort("Устаревшее сообщение заезда."); return
	if kind=="ready" and host and phase=="preparing" and not ready_members.has(member):
		ready_members.append(member)
		if ready_members.size()==members.size(): _begin()
		return
	if kind=="begin" and not host and phase=="preparing": _begin(); return
	if kind=="input" and host and phase in ["playing","results"]:
		if not Wire.integer(data.get("seq"),0,2147483647) or data.seq<=input_sequences.get(member,-1) or not Wire.valid_input(data.get("values")):
			abort("Неверная команда управления."); return
		input_sequences[member]=data.seq
		if phase=="playing": inputs[member]={"values":data.values,"at":Time.get_ticks_msec()}
		return
	if kind=="recover" and host and phase=="playing": game._recover(game.cars[members.find(member)]); return
	if kind=="state" and not host and phase in ["playing","results"]:
		if not Wire.valid_snapshot(data,game.pickups.size()) or data.seq<=last_snapshot or (phase=="results" and data.phase!="results"):
			abort("Не удалось синхронизировать заезд."); return
		last_snapshot=data.seq; targets=data.cars; received_at=Time.get_ticks_msec()
		game.elapsed=data.ms/1000.0; game.countdown=data.countdown/1000.0
		for i in game.pickups.size():
			var pickup: Dictionary=game.pickups[i]
			if pickup.cooldown<=0 and data.pickups[i]>0: game.effects.burst(pickup.node.position,Color("8defff"))
			pickup.cooldown=data.pickups[i]/1000.0; pickup.node.visible=pickup.cooldown<=0
		for beam in data.get("beams",[]):
			game.effects.beam(Vector3(beam[1],beam[2],beam[3])/100,Vector3(beam[4],beam[5],beam[6])/100)
			if beam[0]==game.player_index: game.sound.shot.play()
		if data.phase=="results" and phase!="results":
			apply_targets(1.0,true); phase="results"; game.finish_race()
		elif phase!="results": game.state=data.phase
		return
	if kind=="vote" and host and phase in ["playing","results"]:
		if game.state!="results" or votes.has(member): abort("Неверный запрос реванша."); return
		votes.append(member); _rematch_if_ready(); return
	if kind=="ping": return
	abort("Неизвестное сообщение заезда.")

func apply_remote(car: Node3D) -> void:
	var member: String=members[car.index]; var command: Dictionary=inputs.get(member,{})
	if command.is_empty() or Time.get_ticks_msec()-command.at>350: game.controls.neutral(car)
	else: Wire.apply_input(car,command.values)

func tick_client(delta: float) -> void:
	apply_targets(delta)
	if phase=="playing":
		if game.state=="race" and not overlay:
			if game.demo_auto:
				game.player().bot_drive(game.cars,delta); game.player().bot.combat(game.player(),game.cars,delta)
			else: game.controls.read(game.player(),game.camera)
		else: game.controls.neutral(game.player())
	if game.state=="race":
		game.elapsed+=delta; game._update_conditions(game.elapsed)
		game.effect_clock+=delta
		if game.effect_clock>0.09:
			for car in game.cars:
				if car.finish_time<0 and car.grounded and car.linear_velocity.length()>3 and car.position.distance_to(game.player().position)<45: game.effects.dust(car,game.current_wetness)
			game.effect_clock=0
		if game.player().finish_time>=0: game.hud.message="Финиш! Ожидаем остальных участников…"
	elif game.state=="countdown": game.countdown=maxf(0,game.countdown-delta)

func apply_targets(delta: float, snap: bool = false) -> void:
	if targets.size()!=game.cars.size(): return
	var age: float=minf(0.1,(Time.get_ticks_msec()-received_at)/1000.0)
	for i in targets.size():
		var s: Array=targets[i]; var car: Node3D=game.cars[i]
		var position = Vector3(s[0],s[1],s[2])/100.0; var velocity = Vector3(s[4],s[5],s[6])/100.0
		var target = position+velocity*age if s[14]<0 else position
		car.position=target if snap or car.position.distance_to(target)>6 else car.position.lerp(target,1-exp(-delta*24))
		car.rotation.y=lerp_angle(car.rotation.y,s[3]/1000.0,1.0 if snap else 1-exp(-delta*24))
		car.last_forward=-car.basis.z
		car.checkpoint=posmod(int(s[13]),game.track.COUNT)
		car.offroad=game.track.road_distance(car.position,game.track.nearest(car.position,car.checkpoint))>game.track.WIDTH*0.5+0.5
		car.linear_velocity=velocity
		# Local aim reacts immediately; everyone else displays the authoritative turret.
		if i!=game.player_index: car.aim=Vector3(sin(s[7]/1000.0),0,cos(s[7]/1000.0))
		if car.local_player:
			if s[8]<car.health: game.hud.portrait.set_mood("hurt")
			elif s[14]>=0 and car.finish_time<0: game.hud.portrait.set_mood("victory")
			if s[11]>car.ammo or ((int(s[12])&2)!=0 and not car.shield_item): game.sound.pickup.play()
		car.health=s[8]; car.shield=s[9]; car.boost=s[10]; car.ammo=s[11]
		car.immune=1 if (int(s[12])&1)!=0 else 0; car.shield_item=(int(s[12])&2)!=0
		car.ghost_time=1 if (int(s[12])&8)!=0 else 0
		car.boosting=(int(s[12])&4)!=0; car.grounded=(int(s[12])&16)!=0
		car.passed=s[13]; car.laps=int(s[13])/game.track.COUNT; car.finish_time=s[14]/1000.0 if s[14]>=0 else -1
		car.disabled_time=s[15]/1000.0; car.update_visuals()

func _process(delta: float) -> void:
	if not online: return
	var now = Time.get_ticks_msec()
	if phase in ["waiting","preparing"]:
		if now>deadline: abort("Участник не успел подготовить трассу.")
		return
	for member in seen:
		if now-seen[member]>8000: abort("Связь с участником потеряна."); return
	clock+=delta
	if clock<(1.0/15.0 if host else 1.0/20.0): return
	clock=0; sequence+=1
	if host:
		var packet = {"type":"state","round":round_id,"seq":sequence,"phase":game.state,"ms":roundi(game.elapsed*1000),"countdown":maxi(0,roundi(game.countdown*1000)),"cars":game.cars.map(Wire.car_state),"pickups":game.pickups.map(func(p): return roundi(p.cooldown*1000)),"beams":beams.duplicate()}
		for member in bridge.channels:
			if not bridge.send_latest(member,"state",packet): abort("Очередь синхронизации переполнена."); return
		beams.clear()
	else:
		var packet = {"type":"input","round":round_id,"seq":sequence,"values":Wire.input(game.player())} if phase=="playing" else {"type":"ping","round":round_id}
		if not bridge.send_latest(bridge.session.hostMember,"input",packet): abort("Не удалось передать управление.")

func shot(car: Node3D, from: Vector3, to: Vector3) -> void:
	if online and host and beams.size()<12: beams.append([car.index,roundi(from.x*100),roundi(from.y*100),roundi(from.z*100),roundi(to.x*100),roundi(to.y*100),roundi(to.z*100)])

func rematch() -> void:
	if not online or game.state!="results" or voted: return
	voted=true; game.hud.message="Реванш: ожидаем остальных участников…"
	game.hud.menu("results")
	if host: votes.append(bridge.session.self); _rematch_if_ready()
	elif not bridge.send({"type":"vote","round":round_id}): abort("Не удалось запросить реванш.")

func _rematch_if_ready() -> void:
	if votes.size()==members.size(): _prepare()

func recover() -> void:
	if host: game._recover(game.player())
	elif not bridge.send({"type":"recover","round":round_id}): abort("Не удалось вернуть машину.")

func leave() -> void:
	online=false; phase="idle"; overlay=false; bridge.close_channel(); clear()

func clear() -> void:
	inputs.clear(); seen.clear(); ready_members.clear(); votes.clear(); targets.clear(); beams.clear(); voted=false

func abort(reason: String) -> void:
	info=reason; leave(); game.network_ended(reason)

func _closed() -> void:
	if online: online=false; phase="idle"; overlay=false; clear(); game.network_ended("Заезд прерван. Вернитесь в лобби для нового старта.")
