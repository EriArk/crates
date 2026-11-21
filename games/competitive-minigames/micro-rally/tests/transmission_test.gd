# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Gearbox = preload("res://scripts/transmission.gd")
const Store = preload("res://scripts/career_store.gd")
const Wire = preload("res://scripts/race_wire.gd")
var failures=0
func check(ok: bool, label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var box=Gearbox.new()
	for i in 300: box.step(1.0/60,0,0,1,0,false,false)
	check(box.gear==1 and box.rpm>7900,"Airborne free revs cannot run automatic through gears")
	box.reset()
	for speed in range(36):
		for i in 60: box.step(1.0/60,speed,speed,1,0,true,false)
	check(box.gear==5,"Automatic climbs through five ratios")
	for i in 180: box.step(1.0/60,0,0,0,0,true,false)
	check(box.gear==1,"Automatic recovers first gear after a stop")
	box.reset()
	for i in 180: box.step(1.0/60,16,16,1,0,true,true)
	check(box.gear==1 and box.drive_acceleration(false)==0,"Manual holds first and limiter removes engine torque")
	box.gear=5; box.cooldown=0; box.request(-1); box.step(1.0/60,36,36,1,0,true,true)
	check(box.gear==5,"Downshift that would overrev is rejected")
	box.request(-1); box.step(1.0/60,10,10,1,0,true,true)
	check(box.gear==4 and box.shift_left>0 and box.drive_acceleration(false)<0.1,"Accepted downshift briefly interrupts drive")
	for i in 60: box.step(1.0/60,10,10,1,0,true,true)
	check(box.drive_acceleration(false)>10,"Clutch recovers drive after shift")
	box.step(0.1,8,8,0,1,true,true)
	check(not box.reverse,"Braking at speed does not engage reverse")
	box.step(0.1,0,0,0,1,true,true)
	check(box.reverse and box.gear_label()=="R","Brake-to-reverse engages near rest")
	box.step(0.1,-3,-3,1,0,true,true)
	check(box.reverse,"Gas must brake reverse motion before changing direction")
	box.step(0.1,-0.2,-0.2,1,0,true,true)
	check(not box.reverse and box.gear==1,"Forward restarts in first gear")
	check(is_equal_approx(Gearbox.speed_kmh(Vector3(3,0,4)),18),"Speed includes drift in km/h")
	check(Gearbox.speed_kmh(Vector3(0,10,0))==0,"Vertical bounce does not inflate ground speed")
	check(is_equal_approx(Gearbox.speed_kmh(Vector3(0,0,-10)),36),"Reverse and forward speed use magnitude")
	var store=Store.new(); var owner="gear-test-"+str(Time.get_ticks_usec())
	store.load_profile(owner,"user://transmission-test")
	check(not store.manual_gears(),"Existing/missing setting defaults to automatic")
	check(store.set_manual_gears(true),"Manual preference saves")
	store.load_profile(owner,"user://transmission-test"); check(store.manual_gears(),"Preference survives reload")
	store.load_profile(owner+"other","user://transmission-test"); check(not store.manual_gears(),"Preference belongs to profile")
	var bad=Store.fresh(); bad.manual_gears="manual"; check(not Store.valid(bad),"Malformed saved preference rejected")
	var game=load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	game.state="test"; game.set_physics_process(false)
	for c in game.cars: c.freeze=true
	var car=game.player(); car.manual_gears=true; car.transmission.reset()
	game.controls.shift_buttons(car,true,false)
	var serial=car.shift_serial
	for i in 20: game.controls.shift_buttons(car,true,false)
	check(car.shift_serial==serial,"Holding a shift button creates one request")
	game.controls.shift_buttons(car,false,false); game.controls.shift_buttons(car,false,true)
	check(car.shift_serial==serial+1 and car.shift_direction== -1,"Released button permits next downshift")
	game.controls.neutral(car); check(car.transmission.pending==0 and car.shift_direction==0,"Pause neutral cancels pending shift")
	game.controls.neutral_required=true
	var key=InputEventKey.new(); key.physical_keycode=KEY_C; key.keycode=KEY_C; key.pressed=true
	Input.parse_input_event(key); Input.flush_buffered_events(); game.controls.read(car,game.camera)
	check(game.controls.neutral_required and car.shift_direction==0,"Held shift key cannot cross resume barrier")
	key=key.duplicate(); key.pressed=false; Input.parse_input_event(key); Input.flush_buffered_events(); game.controls.read(car,game.camera)
	check(not game.controls.neutral_required,"Releasing shift clears resume barrier")
	serial=car.shift_serial; key=key.duplicate(); key.pressed=true; Input.parse_input_event(key); Input.flush_buffered_events()
	for i in 5: game.controls.read(car,game.camera)
	check(car.shift_serial==serial+1 and car.shift_direction==1,"Actual C key produces exactly one upshift")
	key=key.duplicate(); key.pressed=false; Input.parse_input_event(key); Input.flush_buffered_events()
	var remote=game.cars[1]; var command=[0,0,0,1000,0,0,1,5,1,0,0,0,0]
	check(Wire.valid_input(command),"Manual command is bounded")
	Wire.apply_input(remote,command); remote.transmission.step(0.01,4,4,1,0,true,remote.manual_gears)
	check(remote.transmission.gear==2,"Host applies manual input to admitted car")
	for i in 80:
		Wire.apply_input(remote,command); remote.transmission.step(1.0/60,4,4,1,0,true,remote.manual_gears)
	check(remote.transmission.gear==2,"Repeated latest input cannot repeat shift")
	for invalid in [[0,0,0,0,0,0],[0,0,0,0,0,0,2,1,1],[0,0,0,0,0,0,1,-1,1],[0,0,0,0,0,0,1,1,2]]:
		check(not Wire.valid_input(invalid),"Old or malformed shift command rejected")
	game.hud.menu("controls"); var before=game.cup.store.manual_gears(); game.hud.buttons[0].pressed.emit()
	check(game.cup.store.manual_gears()!=before and car.manual_gears==game.cup.store.manual_gears(),"Visible setting updates live car and profile")
	game.state="pause"; game.hud.menu("pause"); game.hud.menu("controls"); game.hud.back()
	check(game.hud.menu_mode=="pause","Controls returns to pause")
	car.transmission.gear=4; car.reset_at(Transform3D.IDENTITY); car.freeze=false
	await physics_frame; await physics_frame
	check(car.transmission.gear==1,"Recovery resets gearing")
	# Compare physical acceleration with a held low gear, not just a number on the HUD.
	var floor=StaticBody3D.new(); var shape=BoxShape3D.new(); shape.size=Vector3(80,0.4,400)
	var collision=CollisionShape3D.new(); collision.shape=shape; floor.add_child(collision); game.add_child(floor); floor.position=Vector3(0,39.8,0)
	car.track=null; car.collision_layer=2; car.collision_mask=1
	var speeds: Array=[]; var gears: Array=[]
	for manual in [true,false]:
		car.manual_gears=manual; car.throttle=0; car.brake=0; car.boosting=false; car.steer_input=0; car.handbrake=false
		car.reset_at(Transform3D(Basis.IDENTITY,Vector3(0,40.8,0)))
		for i in 90: await physics_frame
		car.throttle=1
		for i in 300: await physics_frame
		speeds.append(-car.linear_velocity.z); gears.append(car.transmission.gear)
	check(speeds[0]<13.5 and speeds[1]>21 and speeds[1]>speeds[0]*1.5 and gears[1]>=4,"Gearing changes actual chassis acceleration and reachable speed")
	print("PHYSICAL GEARING speeds_mps=",speeds," gears=",gears)
	print("TRANSMISSION TEST failures=",failures)
	await preload("audio_drain.gd").dispose(game,self); quit(1 if failures else 0)
