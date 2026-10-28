# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://addons/traineros/client.gd"
## Adapter for SDK network.group v1; SDK owns admission and secure transport.
signal member_record(member: String, data: Dictionary)
signal avatar_changed(descriptor: Dictionary)
signal profile_available(profile: String)
var channels: Dictionary = {}
var sequences: Dictionary = {}
var outstanding: Dictionary = {}
var records: Array = []
var consumes: Array = []
var retired_channels: Array = []

func _retire_records() -> void:
	# A closed grant may still have SDK replies in flight. Retire only its queued
	# record requests, preserving the authenticated connection and avatar callbacks.
	for grant in channels.values():
		if not retired_channels.has(grant): retired_channels.append(grant)
	while retired_channels.size()>64: retired_channels.pop_front()
	for id in pending.keys():
		if pending[id].method in ["network.send","network.consume","network.close"]:
			pending.erase(id); ignored.append(id)
	while ignored.size()>64: ignored.pop_front()

func _init() -> void:
	app_id="art.abysstail.micro-rally"; activity_title="Micro Rally"; game_protocol="micro-rally.6"

func send_latest(member: String, key: String, data: Dictionary) -> bool:
	# Replace only unsent disposable state. Never replay old controls after congestion.
	var bytes = JSON.stringify(data).to_utf8_buffer()
	if not channels.has(member) or bytes.size()>16384: return false
	for item in records:
		if item.channel==channels[member] and item.get("key")==key:
			item.data=Marshalls.raw_to_base64(bytes); return true
	if records.size()>=256: return false
	records.append({"channel":channels[member],"key":key,"data":Marshalls.raw_to_base64(bytes)})
	return true

func disconnect_host() -> void:
	retired_channels.clear()
	channels.clear(); sequences.clear()
	outstanding.clear(); records.clear(); consumes.clear()
	super.disconnect_host()

func close_channel() -> void:
	super.close_channel()
	_retire_records()
	channels.clear(); sequences.clear()
	outstanding.clear(); records.clear(); consumes.clear()

func send_to(member: String, data: Dictionary) -> bool:
	var bytes := JSON.stringify(data).to_utf8_buffer()
	if not channels.has(member) or bytes.size()>16384 or records.size()>=256: return false
	records.append({"channel":channels[member],"data":Marshalls.raw_to_base64(bytes)})
	return true

func send(data: Dictionary) -> bool:
	if channels.is_empty() or records.size()+channels.size()>256: return false
	for member in channels:
		if not send_to(member,data): return false
	return true

func _process(delta: float) -> void:
	super._process(delta)
	if not active: return
	_drain_queues()

func _drain_queues() -> void:
	# Stay below SDK's 64 unconsumed records and client's 64 local requests.
	# State fan-out must not consume the space needed to acknowledge
	# incoming records. Drain consumes first and retain FIFO order per channel.
	while not consumes.is_empty() and pending.size()<32:
		if not request("network.consume",consumes[0]): return
		consumes.pop_front()
	var blocked: Array = []
	var index := 0
	while index<records.size() and pending.size()<24:
		var record: Dictionary = records[index]
		var grant: String = record.channel
		if outstanding.get(grant,0)>=(2 if record.has("key") else 24) or blocked.has(grant):
			blocked.append(grant); index+=1; continue
		if not request("network.send",{"channel":grant,"data":record.data}): return
		outstanding[grant]=outstanding.get(grant,0)+1
		records.remove_at(index)

func _packet(value: Dictionary) -> void:
	var event = value.get("event","")
	if event=="avatar.changed":
		if value.get("avatar") is Dictionary: avatar_changed.emit(value.avatar)
		return
	if event=="network.ack":
		var grant = value.get("channel")
		if outstanding.get(grant,0)>0: outstanding[grant]-=1
		return
	if event=="network.ready":
		var s = value.get("session")
		if not s is Dictionary or not registered or not channel.is_empty() or s.get("protocol")!=game_protocol or s.get("delivery")!="reliable-ordered" or not s.get("host") is bool:
			fail("Incompatible network session."); return
		var members = s.get("members"); var links = s.get("channels")
		if not members is Array or members.size()<2 or members.size()>16 or not links is Array or s.get("maxBytes")!=16384 or s.get("window")!=64:
			fail("Micro Rally supports 2 to 16 players."); return
		var ids: Array = []; var previous := 0
		for member in members:
			if not member is Dictionary or not member.get("id") is String or member.id.is_empty() or ids.has(member.id) or member.get("connected")!=true or not _seat(member.get("seat"),previous):
				fail("Invalid admitted rally roster."); return
			previous=int(member.seat); ids.append(member.id)
		if not ids.has(s.get("self")) or not ids.has(s.get("hostMember")) or s.host!=(s.self==s.hostMember) or links.size()!=(members.size()-1 if s.host else 1):
			fail("Invalid rally group role."); return
		var grants: Array = []
		for link in links:
			if not link is Dictionary or not link.get("channel") is String or link.channel.is_empty() or grants.has(link.channel) or channels.has(link.get("peer")) or not ids.has(link.get("peer")) or link.peer==s.self or (not s.host and link.peer!=s.hostMember):
				fail("Invalid rally group channel."); return
			channels[link.peer]=link.channel; sequences[link.channel]=0; grants.append(link.channel)
		channel=grants[0]; session=s.duplicate(true)
		session_ready.emit(s.host); return
	if event=="network.closed":
		if not channel.is_empty() and (value.get("channel","").is_empty() or channels.values().has(value.get("channel"))):
			_retire_records()
			channel=""; channels.clear(); sequences.clear(); session={}; closed.emit()
			outstanding.clear(); records.clear(); consumes.clear()
			status.emit("A player left. Return to Lobby for a fresh round.")
		return
	if event=="network.data":
		var grant = value.get("channel",""); var member = value.get("peer","")
		if retired_channels.has(grant) and not channels.values().has(grant): return
		if grant.is_empty() or channels.get(member)!=grant or value.get("sequence")!=str(sequences.get(grant,-1)) or not value.get("data") is String:
			fail("Out-of-order rally record."); return
		var bytes := Marshalls.base64_to_raw(value.data)
		var data = JSON.parse_string(bytes.get_string_from_utf8())
		if bytes.size()>16384 or not data is Dictionary: fail("Invalid rally record."); return
		sequences[grant]+=1
		member_record.emit(member,data)
		if channels.get(member)==grant:
			if consumes.size()>=256: fail("Rally acknowledgement queue exceeded."); return
			consumes.append({"channel":grant,"sequence":value.sequence})
		return
	if ignored.has(value.get("id")): super._packet(value); return
	if value.has("error"):
		if pending.get(value.get("id"),{}).get("method")=="activity.register" and value.error.get("code")=="invalid_activity":
			pending.erase(value.id); connected.emit()
			status.emit("Install Micro Rally through Crates to play online."); return
		push_warning("Rally SDK request "+str(pending.get(value.get("id"),{}).get("method"))+": "+str(value.error.get("code","unknown")))
	if pending.get(value.get("id"),{}).get("method")=="hello" and not value.has("error"):
		var context=value.get("result",{}).get("context",{})
		if context is Dictionary and context.get("profile") is String: profile_available.emit(context.profile)
		if value.get("result",{}).get("capabilities",{}).get("network.group")!=1:
			var result = value.get("result",{})
			if result.get("protocol")!=1 or not result.get("capabilities") is Dictionary: fail("Incompatible TrainerOS version."); return
			pending.erase(value.id); capabilities=result.capabilities.duplicate(true); connected.emit()
			status.emit("Update TrainerOS to race online. Solo play is available."); return
	super._packet(value)

func _seat(value, previous: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value==int(value) and value>previous and value<=16
