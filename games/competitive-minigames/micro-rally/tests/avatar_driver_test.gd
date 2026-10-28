# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Portrait=preload("res://scripts/portrait.gd")
class Bridge extends Node:
	signal connected
	signal avatar_changed(descriptor: Dictionary)
	signal identity_revoked
	signal closed
	var registered=true
	var capabilities={"avatar.local":1}
	var callback: Callable
	func request(_method: String,_params: Dictionary,reply: Callable) -> void: callback=reply
var failures=0
var output=""
var descriptor: Dictionary
var replacement_path=""
func check(value: bool,label: String) -> void:
	if not value: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	if output.is_empty(): return
	await process_frame; await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+name+".png")
func run() -> void:
	var path=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--descriptor="): path=arg.trim_prefix("--descriptor=")
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--replacement-descriptor="): replacement_path=arg.trim_prefix("--replacement-descriptor=")
	descriptor=JSON.parse_string(FileAccess.get_file_as_string(path))
	var backdrop=ColorRect.new(); backdrop.color=Color("344752"); backdrop.size=Vector2(1280,720); root.add_child(backdrop)
	var bridge=Bridge.new(); root.add_child(bridge)
	var p=Portrait.new(); p.shared_sdk=bridge; p.position=Vector2(420,0); p.size=Vector2(560,630); root.add_child(p)
	var stale=bridge.callback
	bridge.avatar_changed.emit(descriptor)
	check(p.model!=null,"Official profile descriptor loads")
	if p.model==null: quit(1); return
	var instance=p.model.get_instance_id()
	p.set_mood("sad"); p._process(2.1); check(p.mood=="neutral","Transient emotion returns to neutral")
	p.set_mood("happy"); p.reset_race(); check(p.mood=="neutral","Rematch clears old reaction")
	stale.call({"avatar":{}},"")
	check(p.model!=null and p.model.get_instance_id()==instance,"Push update supersedes stale subscribe reply")
	bridge.avatar_changed.emit(descriptor)
	check(p.model.get_instance_id()==instance,"Duplicate profile does not rebuild GLB")
	check(p.model.profile_id==descriptor.get("profile",""),"Profile identity preserved")
	check(p.model.supports_expression("happy") and p.model.supports_expression("sad"),"Shared pack expressions available")
	check(not p.model.animation_player.is_playing(),"Sit pose held without body animation fighting IK")
	for steer in [-1.0,0.0,1.0]:
		p.rig.pose(steer,1,0.7)
		for error in p.rig.foot_errors: check(error<0.012,"Feet follow separate pedals at full travel")
		for error in p.rig.hand_errors: check(error<0.012,"Both hands stay on wheel at full lock")
	p.rig.pose(1,0,0)
	check(p.rig.wheel.transform.basis.y.x<0,"Right steering moves top of wheel toward driver right (-X), viewed from front")
	p.rig.pose(0,0,0)
	var before=p.rig.bone_position("foot.R")
	p.rig.pose(0,1,0)
	check(p.rig.bone_position("foot.R").distance_to(before)>0.01,"Gas visibly moves the right foot")
	check(p.rig.bone_position("foot.L").z>p.rig.bone_position("shin.L").z,"Racing legs extend forward instead of hanging down")
	check(p.rig.bone_position("head").z<p.rig.bone_position("pelvis").z-0.06,"Racing torso reclines")
	p.set_process(false); p.rig.pose(0)
	# Revision 9's extra eye/mouth geometry and CPU garment correctives must coexist
	# with the held Sit pose and game IK, including a live wardrobe notification.
	for expression in ["neutral","happy","sad","angry","surprised","smug","worried","tired","laughing","cat_smug","content","squeezed","love","shocked"]:
		check(p.model.set_expression(expression,1,0),"Pack expression accepted: "+expression)
		p.rig.pose(0.7,1,0.4)
		p.view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		await process_frame; await RenderingServer.frame_post_draw
		if expression in ["cat_smug","love","shocked"]: await capture(expression)
	for mouth in ["rest","flat","smile","frown","smirk","open","laugh","tense","cat_smile"]:
		check(p.model.set_mouth(mouth,1,0),"Pack mouth accepted: "+mouth)
	p.model.reset_face(0)
	if not replacement_path.is_empty():
		var replacement=JSON.parse_string(FileAccess.get_file_as_string(replacement_path))
		var old_model=p.model
		p.set_mood("happy",true); bridge.avatar_changed.emit(replacement)
		check(p.model!=null and p.model!=old_model,"Wardrobe push replaces the resolved costume")
		check(old_model.profile_id.is_empty(),"Old costume identity is cleared before deferred free")
		check(p.mood=="neutral" and p.model.profile_id==descriptor.get("profile",""),"Costume switch retains identity and clears transient face")
		p.set_process(false); p.rig.pose(-1,0,1); p.set_mood("sad",true)
		p.view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		for i in 20: p.model._process(1.0/60)
		await capture("wardrobe-switch")
		for error in p.rig.hand_errors: check(error<0.012,"Changed costume keeps wheel grip")
		for error in p.rig.foot_errors: check(error<0.012,"Changed costume keeps pedal contact")
		bridge.avatar_changed.emit(descriptor); p.set_process(false)
	p.rig.pose(0)
	for expression in ["neutral","happy","sad"]:
		p.set_mood(expression,true)
		for i in 20: p.model._process(1.0/60)
		p.view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		await capture(expression)
	p.rig.rotation.y=deg_to_rad(-35); p.rig.pose(1,1,0); await capture("right-lock")
	p.rig.rotation.y=deg_to_rad(35); p.rig.pose(-1,0,1); await capture("left-lock")
	# Check actual rendered bounds at full lock and maximum bump, including hair.
	for sign_value in [-1,1]:
		p.rig.rotation=Vector3(0,deg_to_rad(35*sign_value),sign_value*0.035)
		p.rig.position.y=0.045; p.rig.pose(sign_value,1,1)
		await process_frame; await RenderingServer.frame_post_draw
		var rendered=p.view.get_texture().get_image()
		var clipped=false
		for x in rendered.get_width():
			if rendered.get_pixel(x,0).a>0.01 or rendered.get_pixel(x,rendered.get_height()-1).a>0.01: clipped=true
		for y in rendered.get_height():
			if rendered.get_pixel(0,y).a>0.01 or rendered.get_pixel(rendered.get_width()-1,y).a>0.01: clipped=true
		if clipped:
			print("CLIPPED_POSE ",sign_value)
			if not output.is_empty(): rendered.save_png(output+"/bounds-"+str(sign_value)+".png")
		check(not clipped,"Full steering and bump keep entire avatar within viewport")
	if "--pose-only" in OS.get_cmdline_user_args():
		p.free(); bridge.free(); backdrop.free(); await process_frame; quit(0 if failures==0 else 1); return
	# A network channel ending must not erase the still-authenticated local profile.
	bridge.closed.emit(); check(p.model!=null,"Network close retains local avatar")
	bridge.identity_revoked.emit(); check(p.model==null and p.descriptor_key.is_empty(),"Identity revocation clears immediately")
	stale.call({"avatar":descriptor},""); bridge.avatar_changed.emit(descriptor)
	check(p.model==null,"Late descriptor cannot resurrect revoked identity")
	bridge.connected.emit(); bridge.callback.call({"avatar":descriptor},"")
	check(p.model!=null,"Fresh authenticated subscription restores profile")
	var no_sit=descriptor.duplicate(true); no_sit.actions={}; no_sit.revision="no-sit"
	bridge.avatar_changed.emit(no_sit); p._process(0.04)
	check(p.model==null and p.rig.skeleton==null,"Unsupported pose degrades to empty chair without dangling skeleton")
	var corrupt=descriptor.duplicate(); corrupt.sha256="wrong"
	bridge.avatar_changed.emit(corrupt); check(p.model==null,"Invalid replacement cannot retain old profile")
	p.free(); bridge.free(); backdrop.free()
	# Full game composition at its logical 1280x720 layout, loaded through the same HUD.
	var game=load("res://main.tscn").instantiate(); root.add_child(game)
	game.net.platform_enabled=false
	await process_frame; await process_frame
	game.start_race(); game.state="race"; game.elapsed=5
	game.set_process(false); game.set_physics_process(false)
	var portrait=game.hud.portrait; portrait.revoked=false; portrait._appearance(descriptor); portrait.set_process(false)
	for car in game.cars: car.freeze=true; car.set_process(false); car.set_physics_process(false)
	portrait.set_mood("happy")
	for i in 20: portrait.model._process(1.0/60)
	portrait.view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	# Instrument fixture for layout only; real acceleration is covered by transmission_test.
	game.player().manual_gears=true; game.player().transmission.gear=3; game.player().transmission.rpm=6500
	game.player().linear_velocity=Vector3(0,0,-14); game.hud.displayed_speed=50.4
	await capture("game-hud")
	game.state="pause"; portrait._process(0.1)
	check(portrait.view.process_mode==Node.PROCESS_MODE_DISABLED,"Pause stops face and pose processing")
	game.state="menu"; portrait.hide(); portrait._process(0.1)
	check(portrait.view.process_mode==Node.PROCESS_MODE_DISABLED,"Hidden HUD has no avatar animation work")
	game.state="race"; portrait.show(); portrait._process(0.04)
	check(portrait.view.process_mode==Node.PROCESS_MODE_INHERIT,"Returning to gameplay resumes avatar")
	check(portrait.position.x>root.size.x*0.75 and portrait.position.y>root.size.y*0.5,"Driver occupies lower right")
	check(portrait.position.x+portrait.size.x<=root.size.x and portrait.position.y+portrait.size.y<=root.size.y,"HUD stays inside screen")
	game.free(); await process_frame; await process_frame
	await RenderingServer.frame_post_draw
	print("AVATAR_DRIVER_TEST ","PASS" if failures==0 else "FAIL", " failures=",failures)
	quit(0 if failures==0 else 1)
