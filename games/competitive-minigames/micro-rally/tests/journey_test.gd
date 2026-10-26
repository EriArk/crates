# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures = 0
func check(ok: bool, label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func key(code: Key, pressed: bool) -> void:
	var event = InputEventKey.new(); event.physical_keycode=code; event.keycode=code; event.pressed=pressed; Input.parse_input_event(event)
	Input.flush_buffered_events()
func pad(button: JoyButton, pressed: bool) -> void:
	# Headless has no focused OS window: dispatch through the real viewport GUI.
	var event = InputEventJoypadButton.new(); event.button_index=button; event.pressed=pressed
	root.push_input(event)
func run() -> void:
	root.size=Vector2i(1280,720)
	var game = load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	check(game.state=="menu" and game.hud.buttons[0].has_focus(),"Cup menu has controller focus")
	pad(JOY_BUTTON_A,true); await process_frame; pad(JOY_BUTTON_A,false); await process_frame
	check(game.state=="countdown","Viewport bottom face event starts race from focused menu")
	for i in 190: await physics_frame
	check(game.state=="race","Start countdown finishes")
	game.controls.neutral_required=false
	key(KEY_W,true); key(KEY_UP,true)
	for i in 100: await physics_frame
	check(game.cars[0].desired.z< -0.9 and game.cars[0].linear_velocity.length()>2,"Real key events steer and accelerate physical vehicle")
	key(KEY_W,false); key(KEY_UP,false)
	pad(JOY_BUTTON_START,true); await process_frame; pad(JOY_BUTTON_START,false)
	check(game.state=="pause" and paused,"Start pauses solo race")
	var elapsed=game.elapsed; var position=game.cars[0].position
	for i in 10: await process_frame
	check(game.elapsed==elapsed and game.cars[0].position.is_equal_approx(position),"Pause freezes time and physics")
	key(KEY_UP,true) # Held while paused, before the resume frame.
	pad(JOY_BUTTON_START,true); await process_frame; pad(JOY_BUTTON_START,false)
	check(game.state=="race" and not paused and game.controls.neutral_required,"Resume requires neutral controls")
	game.controls.read(game.cars[0],game.camera)
	check(game.cars[0].throttle==0,"Held trigger/key cannot accelerate immediately after resume")
	key(KEY_UP,false); game.controls.read(game.cars[0],game.camera)
	check(not game.controls.neutral_required,"Neutral releases input barrier")
	game.state="test"
	for car in game.cars: car.freeze=true; car.immune=0
	var a=game.cars[0]; var b=game.cars[1]
	a.position=Vector3(0,30,0); b.position=Vector3(0,30,-8); a.aim=Vector3.FORWARD; b.shield=0; b.health=100
	await physics_frame; await physics_frame
	a.fire_cooldown=0; a.ammo=3; game._shoot(a)
	check(a.ammo==2 and b.health==91,"Actual physics ray hits car and consumes ammunition")
	b.immune=0; b.shield=20; a.fire_cooldown=0; game._shoot(a)
	check(b.health==91 and b.shield==11,"Shot first consumes active shield")
	b.immune=0; b.shield=0; b.take_damage(200)
	check(b.health==0 and b.disabled_time>0,"Destruction starts timed recovery without fragmentation")
	# The starting grid is intentionally still occupied; recover on a free course segment.
	b.checkpoint=80; b.passed=80
	game._recover(b); check(b.health==100 and b.immune>0,"Recovery restores health and short protection")
	a.aim=Vector3.RIGHT; game.controls.read(a,game.camera)
	check(a.aim==Vector3.RIGHT,"Releasing aim preserves its direction")
	game.return_menu(); game.bot_count=0; game.start_race(); game.state="race"; game.elapsed=24.0
	game.cars[0].passed=game.laps*game.track.COUNT
	game._physics_process(1.0/60)
	check(game.state=="results" and game.hud.panel.visible,"Finishing produces visible result screen")
	check(FileAccess.file_exists("user://valley.cfg"),"Finished stage survives as a local record")
	game.start_race(); check(game.state=="countdown" and not paused,"Rematch exits paused results")
	game.return_menu(); check(game.state=="menu" and game.hud.buttons[0].has_focus(),"Return restores menu focus")
	print("JOURNEY TEST failures=",failures)
	game.queue_free(); await process_frame; quit(1 if failures else 0)
