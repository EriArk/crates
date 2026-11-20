# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

var failures: Array[String] = []
var footfalls := 0
var voiced := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for i in count:await physics_frame

func _initialize() -> void:run.call_deferred()

func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.smoke_mode = true
	world.square.life.stop_sound()
	var audio = world.audio
	audio.set_music(true)
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 1
	var slot := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0,capture)
	await create_timer(.35).timeout
	var peak := 0.0
	for frame in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak,maxf(absf(frame.x),absf(frame.y)))
	check(peak > .001 and peak < .97,"Music reached output at a safe level")
	check(audio.music.stream.loop and audio.music.stream.get_length()>55,"Full waltz loops")
	AudioServer.remove_bus_effect(0,slot)
	var walker = world.visitor
	walker.footfall.connect(func(_at, _speed, _crouched):footfalls += 1)
	walker.enter_space(Vector3(0,.1,17),0)
	await frames(12)
	walker.touch_move = Vector2(0,-1)
	await frames(42)
	check(footfalls >= 1 and audio.steps.stream != null,"Moving visitor produces footsteps")
	walker.touch_move = Vector2.ZERO
	await frames(18)
	var stopped := footfalls
	await frames(20)
	check(footfalls == stopped,"Standing still is quiet")
	walker.jump_requested = true
	await frames(2)
	walker.touch_move = Vector2(0,-1)
	await frames(12)
	check(not walker.is_on_floor() and footfalls==stopped,"Airborne travel is quiet")
	walker.touch_move = Vector2.ZERO
	await frames(60)
	check(world.square.foot_surface(Vector3.ZERO)=="stone" and world.square.foot_surface(Vector3(19,0,30))=="grass" and world.square.foot_surface(Vector3(0,0,83))=="sand","Official surface map")
	var personal = load("res://scripts/personal_world.gd").new()
	personal.kind = "island"
	check(personal.foot_surface(Vector3(0,0,7))=="stone" and personal.foot_surface(Vector3(0,0,30))=="grass" and personal.foot_surface(Vector3(0,0,42))=="sand","Island surface map")
	personal.kind = "station"
	check(personal.foot_surface(Vector3.ZERO)=="metal","Station floor is metal")
	personal.free()
	for kind in ["sand","grass","metal","stone"]:
		audio.footstep(kind,3,false)
		var first: Resource = audio.steps.stream
		audio.footstep(kind,4,false)
		check(first != audio.steps.stream and kind in audio.steps.stream.resource_path,"Alternating samples on "+kind)
	var pop = world.population
	var frog: Dictionary = {}
	for npc in pop.residents:
		check(world.Lines.LINES.has(npc.speaker),"Named conversation for "+npc.speaker)
		if npc.species=="Frog":frog=npc
	walker.enter_space(frog.node.position+Vector3(.8,.1,.45),0)
	pop.update_activity()
	world._process(0)
	check(world.nearest.get("actor",{}).get("speaker")=="Ripple","Walking frog can be greeted")
	audio.call.stop()
	audio.call_clock = 0
	audio._process(.02)
	check(is_instance_valid(audio.caller) and audio.call.playing and audio.call.global_position==audio.caller.global_position,"Call emitted by nearby live animal")
	world.dialogue.syllable.connect(func(_ch,_ord,_pitch):voiced+=1)
	world.inspect_spot()
	check(world.dialogue.visible and world.modal and not walker.input_enabled and not audio.call.playing,"Greeting opens conversation and suspends movement")
	world.dialogue._process(.031)
	check(voiced>0 and world.dialogue.cursor>0 and world.dialogue.cursor<world.dialogue.page_text.text.length(),"Voice follows revealed letters")
	world.dialogue.next.pressed.emit()
	check(world.dialogue.page==0 and world.dialogue.page_text.visible_characters==-1,"Tap reveals page")
	var screenshot := OS.get_environment("BAZAAR_TALK_CAPTURE")
	if not screenshot.is_empty() and DisplayServer.get_name()!="headless":
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(screenshot)==OK,"Dialogue capture")
	var first_line: String=world.dialogue.page_text.text
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_A
	press.pressed = true
	world.dialogue._input(press)
	check(world.dialogue.page==1 and world.dialogue.cursor==0,"A advances exactly one page")
	world.dialogue.advance()
	world.dialogue.advance()
	check(not world.modal and walker.input_enabled and walker.camera.current,"Last page returns to walking")
	world._process(0);world.inspect_spot()
	check(world.dialogue.page_text.text!=first_line,"Repeat visit gets another conversation")
	press.button_index = JOY_BUTTON_B
	world.dialogue._input(press)
	check(not world.modal and not audio.voice.playing,"B closes immediately and silences voice")
	var stall: Dictionary = world.square.stall_layout(2)
	walker.enter_space(stall.approach,0)
	pop.update_activity()
	world._process(0)
	check(world.talk.visible and world.speaker.speaker=="Pip","Merchant can chat from the aisle")
	world.start_conversation()
	check(world.dialogue.tag.text=="Pip","Merchant has own lines")
	world.dialogue.close()
	world._process(0)
	world.inspect_spot()
	check(world.services.visible and world.services.page=="goods","Primary action still opens goods")
	world.hide_menu()
	pop.apply_stall_sellers([{"slot":2,"species":"Yeti","rental_id":"fixture"}])
	world._process(0)
	check(world.speaker.species=="Yeti" and world.speaker.speaker=="Stall keeper","Hired seller replaces covered NPC")
	audio.set_effects(false)
	audio.syllable(100,2,1)
	audio.footstep("metal",5,false)
	check(not audio.voice.playing and not audio.steps.playing,"Effects mute covers speech and steps")
	print("BAZAAR_MARKET_SOUND ",JSON.stringify({"failures":failures,"music_peak":peak,"footfalls":footfalls,"pass":failures.is_empty()}))
	await world.leave_bazaar(0 if failures.is_empty() else 1)
