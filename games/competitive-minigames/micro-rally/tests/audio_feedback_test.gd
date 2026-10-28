# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures=0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://main.tscn").instantiate(); root.add_child(game)
	await process_frame; await physics_frame
	game.set_process(false); game.set_physics_process(false); game.net.set_process(false)
	var audio=game.sound
	audio.set_volume("effects",0.75,false); audio.set_volume("music",0.5,false)
	check(audio.decks.size()==2 and audio.decks.all(func(p): return p.stream.loop),"Both authored music tracks loop")
	check(audio.streams.values().all(func(s): return s!=null and s.get_length()>0),"All selected and generated streams decode")
	game.start_race()
	for car in game.cars: car.freeze=true
	var car=game.player()
	audio.events.clear()
	for seconds in [3.0,2.9,2.0,1.9,1.0,0.1]:
		game.countdown=seconds; audio.update(game,0.1)
	check(audio.events.get("tick",0)==3,"Countdown cues play once per number")
	game.state="race"; audio.update(game,0.1); audio.update(game,0.1)
	check(audio.events.get("go",0)==1,"GO plays once")
	car.linear_velocity=Vector3(12,0,0); car.throttle=1; car.grounded=true; car.boosting=true; car.boost=80
	for w in car.physics.wheels: w.contact=true; w.slip=4
	audio.update(game,0.2)
	check(not audio.motor.stream_paused and not audio.tyres.stream_paused and not audio.turbo.stream_paused,"Movement drives engine, gravel and boost layers")
	car.linear_velocity=Vector3.ZERO
	for w in car.physics.wheels: w.surface=0; w.slip=0; w.long_slip=8
	audio.update(game,0.1)
	check(not audio.squeal.stream_paused and audio.tyres.stream_paused,"Stationary asphalt burnout has rubber squeal without gravel")
	for w in car.physics.wheels: w.surface=3
	audio.update(game,0.1)
	check(audio.squeal.stream_paused and not audio.tyres.stream_paused,"Stationary dirt wheelspin uses loose-surface sound")
	car.linear_velocity=Vector3(12,0,0)
	car.transmission.rpm=7000; audio.update(game,0.5); var high_pitch=audio.motor.pitch_scale
	car.transmission.rpm=3500; audio.update(game,0.5)
	check(audio.motor.pitch_scale<high_pitch-0.4,"Upshift rpm drop lowers engine pitch at unchanged road speed")
	game.state="pause"; audio.update(game,0.2)
	check(audio.motor.stream_paused and audio.tyres.stream_paused and audio.squeal.stream_paused and audio.turbo.stream_paused,"Offline pause silences movement")
	game.state="race"; game.net.overlay=true; audio.update(game,0.2)
	check(not audio.motor.stream_paused and audio.events.go==1,"Online menu keeps the moving world audible without replaying GO")
	game.net.overlay=false
	car.laps=game.laps-1; audio.update(game,0.1); audio.update(game,0.1)
	check(audio.events.get("final_lap",0)==1 and audio.duck>0,"Last-lap cue plays once and ducks music")
	car.finish_time=100; audio.update(game,0.1); game.state="results"; audio.update(game,0.1)
	check(audio.events.get("win",0)==1 and audio.finish_played,"Player finish then results do not repeat the jingle")
	game.start_race(); car=game.player(); game.state="results"; audio.update(game,0.1)
	check(audio.events.get("dnf",0)==1,"Unfinished player has a distinct result cue")
	game.start_race(); car=game.player(); game.state="race"
	for other in game.cars: other.freeze=true
	game.feedback.update(game,0.01)
	car.health=80; game.feedback.update(game,0.01)
	var count=audio.events.get("impact0",0)
	game.feedback.update(game,0.01)
	check(count==1 and audio.events.impact0==count,"Repeated authoritative state cannot repeat an impact")
	car.shield=100; game.feedback.update(game,0.01)
	var shields=audio.events.get("shield",0)
	for value in [99.0,98.0,97.0]: car.shield=value; game.feedback.update(game,0.01)
	check(audio.events.shield==shields,"Quantized shield decay is silent")
	car.shield=88; game.feedback.update(game,0.01)
	check(audio.events.shield==shields+1,"Shield hit produces feedback")
	car.health=0; game.feedback.update(game,0.01); game.feedback.update(game,0.01)
	check(audio.events.get("wreck",0)==1,"Wreck cue and smoke occur once without splitting the car")
	check(not audio.play_event("shot",46),"Distant sounds are culled")
	for i in 100: audio.play_event("shot")
	check(audio.voices.size()==audio.VOICES,"Burst of events cannot allocate extra sound voices")
	audio.set_volume("effects",0,false); audio.set_volume("music",0,false); audio.update(game,0.1)
	check(not audio.play_event("shot") and audio.motor.volume_db< -80 and audio.cue.volume_db< -80 and audio.decks[1].volume_db< -80,"Independent zero volumes mute current and new audio")
	check(not audio.set_volume("bad",1,false) and not audio.set_volume("music",NAN,false),"Invalid settings rejected")
	check(audio.set_volume("music",0.25),"Settings save succeeds in isolated test profile")
	var reopened=load("res://scripts/audio.gd").new(); root.add_child(reopened)
	check(reopened.music_volume==0.25 and reopened.effects_volume==0,"Music and effects settings survive reopening")
	reopened.queue_free()
	audio.set_volume("effects",0.75,false); audio.set_volume("music",0.5,false)
	game.hud.menu("pause"); game.hud.menu("audio")
	check(game.hud.audio_parent=="pause" and game.hud.focus_controls[0].has_focus(),"Sound controls retain controller focus and return to pause")
	game.hud.buttons[-1].pressed.emit(); check(game.hud.menu_mode=="pause","Sound Back returns to originating menu")
	game.effects.clear()
	car.position=game.track.points[80]+Vector3.UP*0.72; car.grounded=true
	await physics_frame
	for i in 80:
		car.position+=game.track.tangents[80]*0.08
		# Presentation consumes wheel contacts now; supply a moving authoritative contact fixture.
		for w in car.physics.wheels:
			w.contact=true; w.missing=false; w.normal=Vector3.UP; w.slip=4
			w.point=car.to_global(w.anchor-Vector3.UP*(w.length+w.radius))
		game.effects.skid(car,game.track)
	check(game.effects.marks.size()==game.effects.MARK_LIMIT,"Ground contact marks are bounded")
	var marks=game.effects.marks.size(); car.grounded=false; game.effects.skid(car,game.track)
	check(game.effects.marks.size()==marks,"No tyre marks while airborne")
	for i in 100: game.effects.wreck(car.position); game.effects.ring(car.position,Color.CYAN); game.effects.exhaust(car)
	check(game.effects.particles.size()<=game.effects.LIMIT,"Combat and boost share the existing VFX budget")
	game.effects._process(7)
	check(game.effects.particles.is_empty() and game.effects.marks.is_empty(),"Transient effects expire")
	game.start_race()
	check(game.feedback.previous.is_empty() and not audio.finish_played and not audio.final_lap_played,"Rematch clears old audiovisual state")
	print("AUDIO FEEDBACK TEST failures=",failures)
	game.queue_free(); await process_frame
	# Fixed-FPS tests outrun the real-time mixer. Let queued playback fades drain.
	OS.delay_msec(180); await process_frame
	quit(1 if failures else 0)
