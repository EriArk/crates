# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Walker = preload("res://scripts/walker.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var descriptor: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--descriptor="):descriptor=JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--descriptor=")))
	if descriptor.is_empty():push_error("A synthetic SDK descriptor is required");quit(1);return
	descriptor["profile"]="bazaar-sdk-fixture"
	var server := TCPServer.new()
	if server.listen(0,"127.0.0.1")!=OK:push_error("Fixture listener failed");quit(1);return
	var path := "user://bazaar-sdk-fixture.json"
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"protocol":1,"host":"127.0.0.1","port":server.get_local_port(),"token":"isolated-fixture"}));file.close()
	var holder := Node3D.new();root.add_child(holder)
	var visitor = Walker.new();holder.add_child(visitor);visitor.set_physics_process(false)
	visitor.client.endpoint_override=path;visitor.reconnect()
	var peer: StreamPeerTCP
	var buffer := ""
	var stage := 0
	var passed := false
	var deadline := Time.get_ticks_msec()+20000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if peer==null and server.is_connection_available():peer=server.take_connection()
		if peer==null:continue
		peer.poll()
		var count := peer.get_available_bytes() if peer.get_status()==StreamPeerTCP.STATUS_CONNECTED else 0
		if count>0:buffer+=peer.get_utf8_string(count)
		while buffer.contains("\n"):
			var end := buffer.find("\n");var request: Dictionary=JSON.parse_string(buffer.left(end));buffer=buffer.substr(end+1)
			var result: Dictionary={}
			if request.method=="hello":
				if request.params.app!="org.traineros.bazaar" or request.params.token!="isolated-fixture":break
				result={"capabilities":{"avatar.local":1},"context":{"profile":"bazaar-sdk-fixture"}}
			elif request.method=="avatar.subscribe":result={"avatar":descriptor}
			else:break
			peer.put_data((JSON.stringify({"id":request.id,"result":result})+"\n").to_utf8_buffer())
		if stage==0 and is_instance_valid(visitor.visual):
			stage=1;peer.put_data((JSON.stringify({"event":"context.revoked"})+"\n").to_utf8_buffer())
		elif stage==1 and visitor.visual==null and visitor.fallback.visible and not visitor.client.active:
			passed=true;break
	peer=null;server.stop();holder.queue_free()
	for i in 5:await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("SDK socket subscribe -> shared avatar -> context revocation: ","PASS" if passed else "FAIL")
	quit(0 if passed else 1)
