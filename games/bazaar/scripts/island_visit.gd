# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
## Server leases name the current host. The existing TrainerOS records transport
## carries only visitor poses; neither peer owns a wallet or decides a sale.
var client=preload("services_client.gd").new()
var figures=preload("population.gd").new()
var visitor: CharacterBody3D
var visit: String
var host := ""
var members := {}
var links := {}
var actors := {}
var poses := {}
var poll := 0.0
var frame := 0.0
var leaving := false
var last_contact := 0
var venue := ""

func _ready() -> void:
	var bytes:=Crypto.new().generate_random_bytes(16)
	bytes[6]=(bytes[6]&15)|64;bytes[8]=(bytes[8]&63)|128
	var hex:=bytes.hex_encode()
	visit="%s-%s-%s-%s-%s"%[hex.left(8),hex.substr(8,4),hex.substr(12,4),hex.substr(16,4),hex.substr(20)]
	client.app_id="org.traineros.bazaar.island"
	add_child(client);add_child(figures)
	client.snapshot.connect(roster)
	client.unavailable.connect(func(_why):reset_peers())
	client.read_failed.connect(func(_method,_why):reset_peers())

func use_endpoint(path: String) -> void:
	reset_peers()
	client.use_endpoint(path)
	poll=0

func drop(peer: String) -> void:
	if links.has(peer):
		var io:Dictionary=links[peer].io
		io.stdio.close()
		io.stderr.close()
		if OS.is_process_running(int(io.pid)):OS.kill(int(io.pid))
		links.erase(peer)

func reset_peers() -> void:
	for p in links.keys():drop(p)
	for actor in actors.values():actor.queue_free()
	actors.clear();poses.clear();members.clear();host=""

func heartbeat() -> void:
	var offers: Array=[]
	if host==visit:
		for peer in links:
			if not links[peer].code.is_empty():offers.append({"guest":peer,"code":links[peer].code})
	client.read("bazaar.visit",{"visit":visit,"leave":leaving,"offers":offers})

func roster(method: String, data: Dictionary) -> void:
	if method!="bazaar.visit" or leaving:return
	last_contact=Time.get_ticks_msec()
	var next_host:String=str(data.get("host",""))
	if next_host!=host:reset_peers()
	host=next_host
	venue=str(data.bazaar_id)
	members.clear()
	for member in data.members:members[str(member.visit_id)]=str(member.display_name)
	for peer in links.keys():
		if not members.has(peer):drop(peer)
	for peer in actors.keys():
		if not members.has(peer):
			actors[peer].queue_free();actors.erase(peer);poses.erase(peer)
	if host==visit:
		for peer in members:
			if peer!=visit and not links.has(peer):connect_peer(peer,"")
	elif members.has(host) and data.get("code") is String:
		if links.has(host) and links[host].code!=data.code:drop(host)
		if not links.has(host):connect_peer(host,data.code)

func connect_peer(peer: String, code: String) -> void:
	var base:=OS.get_environment("XDG_DATA_HOME")
	if base.is_empty():base=OS.get_environment("HOME").path_join(".local/share")
	var directory:=base.path_join("TrainerOS/platform/records")
	var executable:=OS.get_environment("TRAINEROS_RECORD_PYTHON")
	var helper:=OS.get_environment("TRAINEROS_RECORD_HELPER")
	if executable.is_empty():executable=directory.path_join("venv/bin/python")
	if helper.is_empty():helper=directory.path_join("secure-channel.py")
	if not FileAccess.file_exists(executable) or not FileAccess.file_exists(helper):return
	var address:=OS.get_environment("TRAINEROS_ISLAND_NEARBY")
	if host!=visit and code.begins_with("near:") and address.is_empty():return
	var io:=OS.execute_with_pipe(executable,[helper],false)
	if io.is_empty():return
	links[peer]={"io":io,"buffer":"","code":code,"connected":false,"credit":0}
	var guest:=peer if host==visit else visit
	var config:Dictionary={"host":host==visit,"identity":("island/"+venue+"/"+host+"/"+guest).sha256_text()}
	if (host==visit and not address.is_empty()) or code.begins_with("near:"):
		config.mode="nearby";config.address=address
		if host!=visit:
			var parts:=code.split(":")
			if parts.size()!=4:drop(peer);return
			config.port=int(parts[1]);config.fingerprint=parts[2];config.token=parts[3]
	elif host!=visit:config.code=code
	write(peer,config)

func write(peer: String, value: Dictionary) -> void:
	var pipe:FileAccess=links[peer].io.stdio
	if not pipe.store_buffer((JSON.stringify(value)+"\n").to_utf8_buffer()):drop(peer)

func pose_ok(value: Variant) -> bool:
	if not value is Array or value.size()!=4:return false
	for v in value:
		if typeof(v) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(v)) or absf(v)>100:return false
	return true

func read_pose(peer: String, packet: Dictionary) -> void:
	if host==visit:
		if pose_ok(packet.get("pose")):poses[peer]=packet.pose
	elif packet.get("poses") is Dictionary:
		for id in packet.poses:
			if id!=visit and members.has(id) and pose_ok(packet.poses[id]):poses[id]=packet.poses[id]

func pump(peer: String) -> void:
	var link:Dictionary=links[peer]
	var pipe:FileAccess=link.io.stdio
	if not OS.is_process_running(int(link.io.pid)):drop(peer);return
	var count:=mini(24576,pipe.get_length())
	if count<=0:return
	link.buffer+=pipe.get_buffer(count).get_string_from_utf8()
	if link.buffer.length()>65536:drop(peer);return
	var lines:PackedStringArray=link.buffer.split("\n")
	link.buffer=lines[lines.size()-1]
	for i in lines.size()-1:
		var msg=JSON.parse_string(lines[i])
		if not msg is Dictionary:drop(peer);return
		match msg.get("event"):
			"ready":
				if host==visit:
					var ep=msg.get("endpoint")
					if ep is Dictionary:link.code="near:%d:%s:%s"%[int(ep.port),ep.fingerprint,ep.token]
					elif msg.get("code") is String:link.code=msg.code
					poll=0
			"connected":link.connected=true
			"ack":link.credit=maxi(0,int(link.credit)-1)
			"data":
				var payload=JSON.parse_string(Marshalls.base64_to_raw(str(msg.get("data",""))).get_string_from_utf8())
				if payload is Dictionary:read_pose(peer,payload)
				write(peer,{"consume":int(msg.sequence)})
			"error","closed":drop(peer);return
		if not links.has(peer):return

func _process(delta: float) -> void:
	if leaving:return
	poll-=delta
	if poll<=0:
		poll=3.0
		if not client.active:client.connect_host()
		elif client.has_counter:heartbeat()
	if not host.is_empty() and Time.get_ticks_msec()-last_contact>18000:reset_peers()
	for peer in links.keys():pump(peer)
	frame-=delta
	if frame<=0:
		frame=.15
		var p:=visitor.position
		var local_pose:=[p.x,p.y,p.z,visitor.anchor.rotation.y]
		var payload:Dictionary={"pose":local_pose}
		if host==visit:
			var bundle:=poses.duplicate()
			bundle[visit]=local_pose
			payload={"poses":bundle}
		for peer in links.keys():
			if links[peer].connected and links[peer].credit<3:
				links[peer].credit+=1
				write(peer,{"send":Marshalls.raw_to_base64(JSON.stringify(payload).to_utf8_buffer())})
	for peer in poses:
		if not members.has(peer):continue
		var pos:Array=poses[peer]
		var target:=Vector3(pos[0],pos[1],pos[2])
		if not actors.has(peer):
			var actor:Node3D=figures.figure("Casual_Female" if str(peer).hash()%2==0 else "Casual_Male",target,.48).node
			var caption:=Label3D.new();caption.text=members[peer];caption.pixel_size=.004;caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED
			actor.add_child(caption);caption.position.y=1.7;actors[peer]=actor
		var actor:Node3D=actors[peer]
		actor.position=actor.position.lerp(target,minf(1,delta*12))
		actor.rotation.y=lerp_angle(actor.rotation.y,float(pos[3]),minf(1,delta*12))

func leave() -> void:
	leaving=true
	if client.has_counter:
		var until:=Time.get_ticks_msec()+900
		while not client.pending.is_empty() and Time.get_ticks_msec()<until:await get_tree().process_frame
		if client.pending.is_empty():
			heartbeat()
			while not client.pending.is_empty() and Time.get_ticks_msec()<until:await get_tree().process_frame
	reset_peers()

func _exit_tree() -> void:
	for peer in links.keys():drop(peer)
