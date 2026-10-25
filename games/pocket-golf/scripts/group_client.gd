# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://addons/traineros/client.gd"
## Adapter for SDK network.group v1; SDK owns admission and secure transport.
signal member_record(member: String, data: Dictionary)
var channels: Dictionary = {}
var sequences: Dictionary = {}
var outstanding: Dictionary = {}
var records: Array = []
var consumes: Array = []

func _init() -> void: game_protocol="pocket-golf.8"

func disconnect_host() -> void:
	channels.clear(); sequences.clear()
	outstanding.clear(); records.clear(); consumes.clear()
	super.disconnect_host()

func close_channel() -> void:
	super.close_channel()
	channels.clear(); sequences.clear()
	outstanding.clear(); records.clear(); consumes.clear()

func send_to(member: String, data: Dictionary) -> bool:
	var bytes := JSON.stringify(data).to_utf8_buffer()
	if not channels.has(member) or bytes.size()>16384 or records.size()>=256: return false
	records.append({"channel":channels[member],"data":Marshalls.raw_to_base64(bytes)})
	return true

func send(data: Dictionary) -> bool:
	if channels.is_empty() or records.size()+channels.size()>256: return false
	if data.get("type") in ["aim","ping"] and records.size()>16: return true
	for member in channels:
		if not send_to(member,data): return false
	return true

func _process(delta: float) -> void:
	super._process(delta)
	if not active: return
	_drain_queues()

func _drain_queues() -> void:
	# Stay below SDK's 64 unconsumed records and client's 64 local requests.
	# A seven-way avatar fan-out must not consume the space needed to acknowledge
	# incoming records. Drain consumes first and retain FIFO order per channel.
	while not consumes.is_empty() and pending.size()<32:
		if not request("network.consume",consumes[0]): return
		consumes.pop_front()
	var blocked: Array = []
	var index := 0
	while index<records.size() and pending.size()<24:
		var record: Dictionary = records[index]
		var grant: String = record.channel
		if outstanding.get(grant,0)>=24 or blocked.has(grant):
			blocked.append(grant); index+=1; continue
		if not request("network.send",record): return
		outstanding[grant]=outstanding.get(grant,0)+1
		records.remove_at(index)

func _packet(value: Dictionary) -> void:
	var event = value.get("event","")
	if event=="network.ack":
		var grant = value.get("channel")
		if outstanding.get(grant,0)>0: outstanding[grant]-=1
		return
	if event=="network.ready":
		var s = value.get("session")
		if not s is Dictionary or not registered or not channel.is_empty() or s.get("protocol")!=game_protocol or s.get("delivery")!="reliable-ordered" or not s.get("host") is bool:
			fail("Incompatible golf session."); return
		var members = s.get("members"); var links = s.get("channels")
		if not members is Array or members.size()<2 or members.size()>8 or not links is Array:
			fail("Golf supports up to eight players."); return
		var ids: Array = []; var previous := 0
		for member in members:
			if not member is Dictionary or not member.get("id") is String or member.id.is_empty() or ids.has(member.id) or member.get("connected")!=true or not _seat(member.get("seat"),previous):
				fail("Invalid admitted golf roster."); return
			previous=int(member.seat); ids.append(member.id)
		if not ids.has(s.get("self")) or not ids.has(s.get("hostMember")) or s.host!=(s.self==s.hostMember) or links.size()!=(members.size()-1 if s.host else 1):
			fail("Invalid golf group role."); return
		var grants: Array = []
		for link in links:
			if not link is Dictionary or not link.get("channel") is String or link.channel.is_empty() or grants.has(link.channel) or channels.has(link.get("peer")) or not ids.has(link.get("peer")) or link.peer==s.self or (not s.host and link.peer!=s.hostMember):
				fail("Invalid golf group channel."); return
			channels[link.peer]=link.channel; sequences[link.channel]=0; grants.append(link.channel)
		channel=grants[0]; session=s.duplicate(true)
		session_ready.emit(s.host); return
	if event=="network.closed":
		if not channel.is_empty() and (value.get("channel","").is_empty() or channels.values().has(value.get("channel"))):
			channel=""; channels.clear(); sequences.clear(); session={}; closed.emit()
			outstanding.clear(); records.clear(); consumes.clear()
			status.emit("A player left. Return to Lobby for a fresh round.")
		return
	if event=="network.data":
		var grant = value.get("channel",""); var member = value.get("peer","")
		if grant.is_empty() or channels.get(member)!=grant or value.get("sequence")!=str(sequences.get(grant,-1)) or not value.get("data") is String:
			fail("Out-of-order golf record."); return
		var bytes := Marshalls.base64_to_raw(value.data)
		var data = JSON.parse_string(bytes.get_string_from_utf8())
		if bytes.size()>16384 or not data is Dictionary: fail("Invalid golf record."); return
		sequences[grant]+=1
		member_record.emit(member,data)
		if channels.get(member)==grant:
			if consumes.size()>=256: fail("Golf acknowledgement queue exceeded."); return
			consumes.append({"channel":grant,"sequence":value.sequence})
		return
	if value.has("error"):
		push_warning("Golf SDK request "+str(pending.get(value.get("id"),{}).get("method"))+": "+str(value.error.get("code","unknown")))
	if pending.get(value.get("id"),{}).get("method")=="hello" and not value.has("error"):
		if value.get("result",{}).get("capabilities",{}).get("network.group")!=1:
			fail("Update TrainerOS to use group golf."); return
	super._packet(value)

func _seat(value, previous: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value==int(value) and value>previous and value<=16
