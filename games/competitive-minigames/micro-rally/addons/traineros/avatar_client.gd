# SPDX-License-Identifier: GPL-3.0-or-later
class_name TrainerAvatarClient
extends Node
## Read-only local avatar capability. Does not register a Lobby or launch a game.
signal appearance_changed(descriptor: Dictionary)
signal unavailable(reason: String)
signal recipe_resolved(key: String, descriptor: Dictionary)
signal recipe_failed(key: String, reason: String)
var app_id := "org.example.avatar"
var endpoint_override := ""
var profile_id := ""
var tcp := StreamPeerTCP.new()
var buffer := PackedByteArray()
var outgoing := PackedByteArray()
var active := false
var connecting := false
var deadline := 0
var serial := 0
var pending: Dictionary = {}
var token := ""
var recipe_supported := false
var resolving_key := ""

func connect_host() -> void:
	disconnect_host()
	var path := endpoint_override
	if path.is_empty(): path = OS.get_environment("TRAINEROS_SDK_ENDPOINT")
	if path.is_empty():
		var base := OS.get_environment("LOCALAPPDATA") if OS.get_name()=="Windows" else OS.get_environment("XDG_DATA_HOME")
		if base.is_empty(): base = OS.get_environment("HOME")+"/.local/share"
		path = base+"/traineros/platform-v1/endpoint.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length()>65536:
		_fail("TrainerOS is not available")
		return
	var info = JSON.parse_string(file.get_as_text())
	if not info is Dictionary or info.get("protocol")!=1 or info.get("host")!="127.0.0.1" or not info.get("port") is float or info.port<1 or info.port>65535 or not info.get("token") is String:
		_fail("Invalid TrainerOS endpoint")
		return
	token=info.token
	if tcp.connect_to_host("127.0.0.1", int(info.port))!=OK:
		_fail("TrainerOS connection failed")
		return
	active=true
	connecting=true
	deadline=Time.get_ticks_msec()+5000

func disconnect_host() -> void:
	tcp.disconnect_from_host()
	active=false
	connecting=false
	profile_id=""
	recipe_supported=false
	resolving_key=""
	token=""
	buffer.clear()
	outgoing.clear()
	pending.clear()

func _exit_tree() -> void: disconnect_host()
func _fail(reason: String) -> void:
	disconnect_host()
	unavailable.emit(reason)

func resolve_recipe(recipe: Dictionary, key: String) -> bool:
	if not active or not recipe_supported or not resolving_key.is_empty(): return false
	resolving_key=key
	_request("avatar.resolve",{"recipe":recipe})
	return true

func _request(method: String, params: Dictionary={}) -> void:
	serial+=1
	pending[str(serial)]={"method":method,"deadline":Time.get_ticks_msec()+(30000 if method=="avatar.resolve" else 5000)}
	outgoing.append_array((JSON.stringify({"id":str(serial),"method":method,"params":params})+"\n").to_utf8_buffer())

func _process(_delta: float) -> void:
	if not active: return
	tcp.poll()
	if connecting:
		if tcp.get_status()==StreamPeerTCP.STATUS_CONNECTED:
			connecting=false
			_request("hello", {"protocol":1,"token":token,"app":app_id})
			token=""
		else:
			if Time.get_ticks_msec()>deadline or tcp.get_status()==StreamPeerTCP.STATUS_ERROR: _fail("TrainerOS connection timed out")
			return
		# Flush hello now: the next rendered frame may compile shaders for seconds.
	if tcp.get_status()!=StreamPeerTCP.STATUS_CONNECTED:
		_fail("TrainerOS disconnected")
		return
	if not outgoing.is_empty():
		var sent:=tcp.put_partial_data(outgoing)
		if sent[0]!=OK:
			_fail("TrainerOS send failed")
			return
		outgoing=outgoing.slice(sent[1])
	var count:=tcp.get_available_bytes()
	if count>0:
		if buffer.size()+count>262144:
			_fail("TrainerOS receive limit")
			return
		var data:=tcp.get_data(count)
		if data[0]!=OK:
			_fail("TrainerOS read failed")
			return
		buffer.append_array(data[1])
	while active:
		var end:=buffer.find(10)
		if end<0: break
		if end>=65536:
			_fail("TrainerOS frame limit")
			return
		var packet=JSON.parse_string(buffer.slice(0,end).get_string_from_utf8())
		buffer=buffer.slice(end+1)
		if not packet is Dictionary:
			_fail("Invalid TrainerOS packet")
			return
		_packet(packet)
	if buffer.size()>=65536: _fail("TrainerOS frame limit")
	for request in pending.values():
		if Time.get_ticks_msec()>request.deadline:
			_fail("TrainerOS response timed out")
			return

func _packet(p: Dictionary) -> void:
	if p.has("event"):
		if p.event in ["host.stopping","context.revoked"]: _fail("Trainer identity ended")
		elif p.event=="avatar.changed": _appearance(p.get("avatar",{}))
		return
	var id: String=p.get("id","")
	if not pending.has(id):
		_fail("Unexpected TrainerOS response")
		return
	var method: String=pending[id].method
	pending.erase(id)
	if method=="avatar.resolve":
		var key := resolving_key
		resolving_key=""
		if p.has("error"): recipe_failed.emit(key,str(p.error.get("code","Avatar unavailable")))
		elif p.get("result") is Dictionary and p.result.get("avatar") is Dictionary:
			recipe_resolved.emit(key,p.result.avatar)
		else: recipe_failed.emit(key,"Invalid avatar result")
		return
	if p.has("error"):
		if method=="avatar.subscribe" and p.error.get("code")=="avatar_not_ready": return
		_fail(str(p.error.get("code","Avatar unavailable")))
		return
	var result=p.get("result",{})
	if not result is Dictionary:
		_fail("Invalid TrainerOS result")
		return
	if method=="hello":
		recipe_supported=result.get("capabilities",{}).get("avatar.recipe")==1
		if result.get("capabilities",{}).get("avatar.local")!=1:
			_fail("This TrainerOS has no avatar service")
			return
		profile_id=result.get("context",{}).get("profile","")
		if profile_id.is_empty():
			_fail("Choose a Trainer profile first")
			return
		_request("avatar.subscribe")
	elif method=="avatar.subscribe": _appearance(result.get("avatar",{}))

func _appearance(value) -> void:
	if not value is Dictionary or value.get("profile")!=profile_id:
		_fail("Avatar identity is unavailable")
		return
	appearance_changed.emit(value)
