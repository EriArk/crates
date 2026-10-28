# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const CameraRig=preload("res://scripts/race_camera.gd")
const Controls=preload("res://scripts/controls.gd")
const Store=preload("res://scripts/career_store.gd")
var failures=0
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path="user://camera-test/"+str(Time.get_ticks_usec()); var store=Store.new(); store.load_profile("one",path)
	check(store.camera_mode()==1 and store.camera_button()==0,"Old saves keep classic camera with R3")
	check(store.set_camera_option("camera_mode",4) and store.set_camera_option("camera_button",2),"Camera preferences save")
	store.load_profile("one",path); check(store.camera_mode()==4 and store.camera_button()==2,"Preferences survive reload")
	store.load_profile("two",path); check(store.camera_mode()==1 and store.camera_button()==0,"Preferences remain profile-owned")
	store.writable=false; check(not store.set_camera_option("camera_mode",3) and store.camera_mode()==1,"Readonly save is preserved")
	check(not store.set_camera_option("camera_mode",5) and not store.set_camera_option("camera_button",4),"Invalid options are rejected")
	var game=load("res://main.tscn").instantiate(); root.add_child(game)
	await process_frame; await process_frame
	game.net.platform_enabled=false; game.net.set_process(false); game.net.bridge.set_process(false)
	game.set_process(false); game.set_physics_process(false); game.cup.store.load_profile("controls",path)
	for car in game.cars: car.freeze=true; car.set_physics_process(false); car.set_process(false)
	var car=game.player(); car.position=Vector3(0,100,0); car.rotation=Vector3.ZERO; car.linear_velocity=Vector3.ZERO
	var rig=game.race_camera; var camera=game.camera
	var distances=[]
	for mode in 5:
		rig.select(mode); game._camera(0,true)
		check(camera.position.is_finite() and camera.basis.determinant()>0.9,"Valid camera transform in every mode")
		if mode<3: distances.append(camera.position.distance_to(car.position))
		else: check(game.tilt_shift.get_shader_parameter("strength")==0.0,"Low views do not blur the road")
	check(distances[0]<distances[1] and distances[1]<distances[2],"Three overhead distances are distinct")
	check(camera.position.z<car.position.z and camera.position.y>car.position.y+0.4,"Windshield mount is forward and above the bonnet")
	check(not car.turret.visible,"Own roof muzzle does not intersect the hood camera")
	car.rotation.y=PI/2; rig.select(3); game._camera(0,true)
	check(car.turret.visible,"Leaving hood view restores the gun")
	var aim=Controls.aim_direction(Vector2.UP,camera.global_basis)
	check(aim.dot(-car.global_basis.z)>0.999,"Right stick up follows the rotated camera's forward direction")
	check(Controls.aim_direction(Vector2.RIGHT,camera.global_basis).dot(camera.global_basis.x)>0.999,"Right stick right follows screen right")
	car.rotation=Vector3(0,0,PI); rig.select(4); game._camera(0,true)
	check(camera.position.y>car.position.y and rig.mode==4,"Overturned hood uses upright follow view without losing preference")
	car.rotation=Vector3.ZERO
	var wall=game.Art.collider(game,Vector3(12,10,0.5),Vector3(0,102,4))
	await physics_frame; await physics_frame
	rig.select(3); game._camera(0,true)
	check(camera.position.z<3.5 and camera.position.z>0,"Chase sphere stops before an actual wall")
	wall.queue_free(); await physics_frame; await physics_frame
	# Switching modes is independent of gameplay input, pause and online overlays.
	game.state="race"; game.hud.panel.hide(); rig.select(1); car.throttle=0.7
	var key=InputEventKey.new(); key.physical_keycode=KEY_V; key.pressed=true
	game._input(key); check(rig.mode==2 and is_equal_approx(car.throttle,0.7),"V changes view without releasing the throttle")
	key.echo=true; game._input(key); check(rig.mode==2,"Keyboard repeat does not cycle repeatedly")
	key.echo=false; game.state="pause"; game._input(key); check(rig.mode==2,"Pause does not consume camera gameplay input")
	game.state="race"; game.net.overlay=true; game._input(key); check(rig.mode==2,"Online menu does not switch camera")
	game.net.overlay=false
	var pad=InputEventJoypadButton.new(); pad.button_index=JOY_BUTTON_RIGHT_STICK; pad.pressed=true
	game._input(pad); check(rig.mode==3,"Default R3 switches camera")
	game.cup.store.set_camera_option("camera_button",1); game._input(pad); check(rig.mode==3,"Old binding stops switching")
	pad.button_index=JOY_BUTTON_LEFT_STICK; game._input(pad); check(rig.mode==4,"New L3 binding switches camera")
	game._input(key); check(rig.mode==0,"Camera cycle wraps from hood to overhead close")
	game.state="menu"; game.hud.menu("controls"); game.hud.menu("camera"); game.hud.back(); game.hud.back()
	check(game.hud.menu_mode=="main","Camera settings return through controls to entry screen")
	await preload("res://tests/audio_drain.gd").dispose(game,self)
	print("CAMERA_TEST ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(0 if failures==0 else 1)
