# SPDX-License-Identifier: GPL-3.0-or-later
# Generic Platform API v1 client. No avatar/wardrobe wire methods are invented here.
extends Node
signal status(text: String)
signal session_ready(host: bool)
signal record(data: Dictionary)
signal closed
signal identity_revoked
signal sdk_record(data: Dictionary)
var app_id := "art.abysstail.pocket-golf"
var activity_title := "Pocket Golf"
var game_protocol := "pocket-golf.6"
var session: Dictionary = {}
var endpoint_override := ""
var channel := ""
var registered := false
var tcp := StreamPeerTCP.new()
var pending: Dictionary = {}
var buffer := PackedByteArray()
var outgoing := PackedByteArray()
var serial := 0
var sequence := 0
var connecting := false
var active := false
var deadline := 0
var token := ""

func connect_host() -> void:
	if registered:
		return
	disconnect_host()
	var path := endpoint_override
	if path.is_empty(): path = OS.get_environment("TRAINEROS_SDK_ENDPOINT")
	if path.is_empty():
		var base := OS.get_environment("LOCALAPPDATA") if OS.get_name()=="Windows" else OS.get_environment("XDG_DATA_HOME")
		if base.is_empty(): base = OS.get_environment("HOME")+"/.local/share"
		path = base+"/traineros/platform-v1/endpoint.json"
	if not FileAccess.file_exists(path):
		fail("Open TrainerOS to play with a friend. Local play is available.")
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length()>65536:
		fail("TrainerOS discovery is unavailable.")
		return
	var info = JSON.parse_string(file.get_as_text())
	if not info is Dictionary or info.get("protocol")!=1 or info.get("host")!="127.0.0.1" or not info.get("port") is float or info.port<1 or info.port>65535 or not info.get("token") is String or info.token.is_empty():
		fail("TrainerOS discovery is invalid.")
		return
	token = info.token
	connecting = true
	active = true
	deadline = Time.get_ticks_msec()+5000
	if tcp.connect_to_host("127.0.0.1",int(info.port))!=OK:
		fail("Could not connect to TrainerOS.")
		return
	status.emit("Connecting to TrainerOS…")

func disconnect_host() -> void:
	tcp.disconnect_from_host()
	active = false
	connecting = false
	registered = false
	channel = ""
	session={}
	token = ""
	pending.clear()
	buffer.clear()
	outgoing.clear()

func fail(reason: String) -> void:
	disconnect_host()
	closed.emit()
	status.emit(reason)

func request(method: String, params: Dictionary = {}) -> bool:
	if not active or pending.size()>=64: return false
	serial += 1
	var id := str(serial)
	pending[id] = {"method":method,"deadline":Time.get_ticks_msec()+5000}
	outgoing.append_array((JSON.stringify({"id":id,"method":method,"params":params})+"\n").to_utf8_buffer())
	return true

func open_lobby() -> void:
	if registered: request("activity.open")

func close_channel() -> void:
	if not channel.is_empty():
		request("network.close",{"channel":channel})
		channel = ""
		session={}
		closed.emit()

func send(data: Dictionary) -> bool:
	var bytes := JSON.stringify(data).to_utf8_buffer()
	if channel.is_empty() or bytes.size()>16384: return false
	return request("network.send",{"channel":channel,"data":Marshalls.raw_to_base64(bytes)})

func _process(_delta: float) -> void:
	if not active: return
	tcp.poll()
	var connection := tcp.get_status()
	if connecting:
		if connection==StreamPeerTCP.STATUS_CONNECTED:
			connecting = false
			request("hello",{"protocol":1,"token":token,"app":app_id})
			token = ""
		else:
			if Time.get_ticks_msec()>deadline or connection==StreamPeerTCP.STATUS_ERROR:
				fail("TrainerOS did not respond.")
			return
		# Send hello in this turn, before the renderer can block on new shaders.
	if connection!=StreamPeerTCP.STATUS_CONNECTED:
		fail("TrainerOS disconnected. Local play is available.")
		return
	if not outgoing.is_empty():
		var sent := tcp.put_partial_data(outgoing)
		if sent[0]!=OK:
			fail("TrainerOS connection failed.")
			return
		outgoing = outgoing.slice(sent[1])
	var count := tcp.get_available_bytes()
	if count>0:
		if buffer.size()+count>262144:
			fail("TrainerOS frame is too large.")
			return
		var received := tcp.get_data(count)
		if received[0]!=OK:
			fail("TrainerOS connection failed.")
			return
		buffer.append_array(received[1])
	while active:
		var end := buffer.find(10)
		if end<0: break
		if end>=65536:
			fail("TrainerOS frame is too large.")
			return
		var value = JSON.parse_string(buffer.slice(0,end).get_string_from_utf8())
		buffer = buffer.slice(end+1)
		if not value is Dictionary:
			fail("Invalid TrainerOS response.")
			return
		_packet(value)
	if buffer.size()>=65536:
		fail("TrainerOS frame is too large.")
		return
	for request in pending.values():
		if Time.get_ticks_msec()>request.deadline:
			fail("TrainerOS response timed out. Reconnect to start a new session.")
			return

func _packet(value: Dictionary) -> void:
	var event: String = value.get("event","")
	if not event.is_empty():
		if event in ["host.stopping","context.revoked"]:
			identity_revoked.emit()
			fail("Trainer changed or TrainerOS closed. Return to Lobby for a fresh game.")
		elif event=="network.ready":
			var s = value.get("session",{})
			if not s is Dictionary or not channel.is_empty() or not registered or s.get("protocol")!=game_protocol or s.get("delivery")!="reliable-ordered" or not s.get("host") is bool or not s.get("channel") is String or s.channel.is_empty():
				fail("Incompatible game session.")
				return
			if not s.get("peer") is String or s.peer.is_empty() or not s.get("self") is String or s.self.is_empty() or s.peer==s.self:
				fail("Missing admitted player identity.")
				return
			channel = s.channel
			session=s.duplicate(true)
			sequence = 0
			session_ready.emit(s.host)
		elif event=="network.closed" and value.get("channel")==channel and not channel.is_empty():
			channel = ""
			session={}
			closed.emit()
			status.emit("Match disconnected. Your Lobby remains available.")
		elif event=="network.data" and value.get("channel")==channel and not channel.is_empty():
			if value.get("peer")!=session.get("peer") or value.get("sequence")!=str(sequence) or not value.get("data") is String:
				fail("Out-of-order game record.")
				return
			var bytes := Marshalls.base64_to_raw(value.data)
			var data = JSON.parse_string(bytes.get_string_from_utf8())
			if bytes.size()>16384 or not data is Dictionary:
				fail("Invalid game record.")
				return
			var grant := channel
			sequence += 1
			if data.get("namespace")=="traineros.avatar.v1": sdk_record.emit(data)
			else: record.emit(data)
			if channel==grant: request("network.consume",{"channel":grant,"sequence":value.sequence})
		return
	var id = value.get("id","")
	if not pending.has(id):
		fail("Unexpected TrainerOS response.")
		return
	var method: String = pending[id].method
	pending.erase(id)
	if value.has("error"):
		fail("TrainerOS could not complete the request. Reconnect from Lobby.")
		return
	var result = value.get("result",{})
	if not result is Dictionary:
		fail("Invalid TrainerOS result.")
		return
	if method=="hello":
		var caps = result.get("capabilities",{})
		if result.get("protocol")!=1 or not caps is Dictionary or caps.get("lobby.activity")!=1 or caps.get("network.records")!=1:
			fail("This TrainerOS build needs native game networking support.")
			return
		request("activity.register",{"title":activity_title,"protocol":game_protocol})
	elif method=="activity.register":
		registered = true
		status.emit("Connected to TrainerOS.")
