# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Portrait = preload("res://addons/traineros/avatar_portrait.gd")
var failed := false
func check(value: bool, message: String) -> void:
	if not value: failed=true;printerr("FAIL: "+message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := ""
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--model="): path=arg.trim_prefix("--model=")
		if arg.begins_with("--capture="): output=arg.trim_prefix("--capture=")
	var descriptor := {"schema":1,"rig":"trainer-humanoid-54-v1","profile":"fixture","glb":path,"sha256":FileAccess.get_sha256(path)}
	var ui=load("res://main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	ui._start_local(2);ui.game.accept_turn()
	var texture=await Portrait.capture(ui,descriptor)
	check(texture!=null,"rendered portrait")
	if texture!=null:
		check(texture.get_size()==Vector2(256,256),"bounded snapshot size")
		ui.hud.set_portraits(texture,null)
	await process_frame
	check(ui.find_children("*","SubViewport",true,false).is_empty(),"3D capture scene released")
	if not output.is_empty():
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output)==OK,"HUD capture")
	# Completion of an old asynchronous capture cannot reinstall revoked identity.
	ui.avatar_binding._capture(descriptor,0)
	ui.avatar_binding.revoke()
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	check(ui.avatar_binding.local_portrait==null,"revocation fences capture")
	descriptor.sha256="invalid"
	check(await Portrait.capture(ui,descriptor)==null,"reject corrupt model")
	print("Portrait checks complete")
	quit(1 if failed else 0)
