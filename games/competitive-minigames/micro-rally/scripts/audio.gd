# SPDX-License-Identifier: GPL-3.0-or-later
extends Node
const Tires = preload("tire_surface.gd")
# One local engine, bounded tire/boost layers, two music decks and a bounded SFX pool.
const VOICES = 12
const FILES = {"impact0":"impact0", "impact1":"impact1", "wreck":"wreck", "shield":"shield", "win":"win", "finish":"finish", "dnf":"dnf", "final_lap":"final_lap"}
var streams: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var decks: Array[AudioStreamPlayer] = []
var deck_gain = [0.0,0.0]
var motor = AudioStreamPlayer.new()
var tyres = AudioStreamPlayer.new()
var squeal = AudioStreamPlayer.new()
var turbo = AudioStreamPlayer.new()
var cue = AudioStreamPlayer.new()
var music_volume = 0.5
var effects_volume = 0.75
var duck = 0.0
var countdown_tick = -1
var final_lap_played = false
var finish_played = false
var previous_state = ""
var events: Dictionary = {}
var mix_bus = ""

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	mix_bus="RallyMix"+str(get_instance_id())
	AudioServer.add_bus(); var bus=AudioServer.bus_count-1
	AudioServer.set_bus_name(bus,mix_bus)
	var limiter=AudioEffectHardLimiter.new(); limiter.ceiling_db=-1.0
	AudioServer.add_bus_effect(bus,limiter)
	var settings=ConfigFile.new()
	if settings.load("user://audio.cfg")==OK:
		music_volume=clampf(float(settings.get_value("mix","music",0.5)),0,1)
		effects_volume=clampf(float(settings.get_value("mix","effects",0.75)),0,1)
	for name in FILES: streams[name]=load("res://assets/audio/"+FILES[name]+".ogg")
	streams.shot=_tone(0.11,110,false,0.85)
	streams.pickup=_tone(0.25,880,false,0.0)
	streams.tick=_tone(0.12,520,false,0.0)
	streams.go=_tone(0.45,1040,false,0.0)
	streams.ui=_tone(0.045,740,false,0.0)
	for name in ["menu","race"]:
		var deck=AudioStreamPlayer.new(); add_child(deck); deck.bus=mix_bus
		deck.stream=load("res://assets/audio/"+name+".ogg").duplicate()
		deck.stream.loop=true; deck.volume_db=-80; decks.append(deck)
	for i in VOICES:
		var voice=AudioStreamPlayer.new(); add_child(voice); voice.bus=mix_bus; voices.append(voice)
	for layer in [motor,tyres,squeal,turbo,cue]: add_child(layer); layer.bus=mix_bus; layer.volume_db=-80
	motor.stream=_tone(1.0,60,true,0.13)
	tyres.stream=_tone(1.0,95,true,0.98)
	squeal.stream=_tone(1.0,610,true,0.38)
	turbo.stream=_tone(1.0,180,true,0.7)
	for layer in [motor,tyres,squeal,turbo]: layer.play(); layer.stream_paused=true

func _exit_tree() -> void:
	for player in get_children():
		if player is AudioStreamPlayer: player.stop(); player.stream=null
	streams.clear()
	var bus=AudioServer.get_bus_index(mix_bus)
	if bus>0: AudioServer.remove_bus(bus)

func _tone(duration: float, frequency: float, looped: bool, noise_mix: float) -> AudioStreamWAV:
	var data=PackedByteArray(); var count=int(22050*duration); data.resize(count*2)
	var rng=RandomNumberGenerator.new(); rng.seed=44
	var filtered=0.0
	for i in count:
		var t=float(i)/22050; var envelope=1.0 if looped else minf(1,t*500)*pow(1.0-float(i)/count,2)
		filtered=lerpf(filtered,rng.randf_range(-1,1),0.32)
		var wave=sin(t*TAU*frequency)*0.5+sin(t*TAU*frequency*2)*0.25+sin(t*TAU*frequency*4)*0.13
		wave=lerpf(wave,filtered,noise_mix)
		if looped: envelope*=minf(1,minf(float(i),float(count-1-i))/110)
		data.encode_s16(i*2,int(wave*envelope*23000))
	var wav=AudioStreamWAV.new(); wav.format=AudioStreamWAV.FORMAT_16_BITS; wav.mix_rate=22050; wav.data=data
	if looped: wav.loop_mode=AudioStreamWAV.LOOP_FORWARD; wav.loop_end=count
	return wav

func set_volume(kind: String, value: float, persist: bool = true) -> bool:
	if kind not in ["music","effects"] or not is_finite(value): return false
	if kind=="music": music_volume=clampf(value,0,1)
	else: effects_volume=clampf(value,0,1)
	if not persist: return true
	var settings=ConfigFile.new(); settings.set_value("mix","music",music_volume); settings.set_value("mix","effects",effects_volume)
	if settings.save("user://audio.cfg.pending")!=OK: return false
	return DirAccess.rename_absolute("user://audio.cfg.pending","user://audio.cfg")==OK

func reset_round() -> void:
	countdown_tick=-1; final_lap_played=false; finish_played=false; previous_state=""
	cue.stop(); duck=0
	for voice in voices: voice.stop()

func play_event(event: String, distance: float = 0.0) -> bool:
	if not streams.has(event) or distance>=45 or effects_volume<=0: return false
	var gain=pow(clampf(1.0-distance/45.0,0,1),2)
	var chosen: AudioStreamPlayer=null
	for voice in voices:
		if not voice.playing: chosen=voice; break
		if chosen==null or float(voice.get_meta("gain",0))<float(chosen.get_meta("gain",0)): chosen=voice
	if chosen.playing and float(chosen.get_meta("gain",0))>gain: return false
	var level={"shot":-14.0,"pickup":-13.0,"shield":-17.0,"wreck":-17.0,"ui":-22.0}.get(event,-16.0)
	chosen.stream=streams[event]; chosen.pitch_scale=randf_range(0.94,1.06) if event in ["shot","impact0","impact1"] else 1.0
	chosen.set_meta("gain",gain); chosen.set_meta("level",level)
	chosen.volume_db=level+linear_to_db(maxf(0.00001,gain*effects_volume)); chosen.play()
	events[event]=int(events.get(event,0))+1
	return true

func play_cue(event: String) -> void:
	cue.stream=streams[event]; cue.volume_db=-10+linear_to_db(maxf(0.00001,effects_volume)); cue.play()
	duck=cue.stream.get_length()+0.35 if effects_volume>0 else 0.0
	events[event]=int(events.get(event,0))+1

func update(game: Node, delta: float) -> void:
	var car=game.player()
	if game.state=="countdown":
		var tick=maxi(1,ceili(game.countdown))
		if tick!=countdown_tick: countdown_tick=tick; play_cue("tick")
	if game.state=="race" and previous_state=="countdown": play_cue("go")
	if not game.is_arena() and game.state=="race" and car.laps>=game.laps-1 and not final_lap_played and car.finish_time<0:
		final_lap_played=true; play_cue("final_lap")
	if (car.finish_time>=0 or game.state=="results") and game.state in ["race","results"] and not finish_played:
		finish_played=true
		play_cue("dnf" if car.finish_time<0 and not game.is_arena() else "win" if game.standings().find(car)==0 else "finish")
	previous_state=game.state
	duck=maxf(0,duck-delta)
	var racing=game.state in ["countdown","race","pause"] and not finish_played
	var quiet=game.state=="pause" or game.net.overlay
	for i in 2:
		var target=1.0 if (i==1)==racing else 0.0
		deck_gain[i]=move_toward(deck_gain[i],target,delta*0.8)
		var gain=deck_gain[i]*music_volume*(0.23 if duck>0 else 1.0)*(0.45 if quiet else 1.0)
		decks[i].volume_db=-8+linear_to_db(maxf(0.00001,gain))
		if target>0 and not decks[i].playing: decks[i].play()
		elif deck_gain[i]<=0 and decks[i].playing: decks[i].stop()
	var moving=game.state=="race" and car.finish_time<0 and car.disabled_time<=0
	var speed=car.linear_velocity.length()
	motor.stream_paused=not moving
	motor.pitch_scale=lerpf(motor.pitch_scale,0.68+car.transmission.rpm/car.transmission.REDLINE*1.28,1-exp(-delta*9))
	motor.volume_db=-24+linear_to_db(maxf(0.00001,effects_volume))+(3 if absf(car.throttle)>0.1 else 0)
	var tire=Tires.feedback(car)
	var hard=0.0; var contacts=0
	for w in car.physics.wheels:
		if not w.contact or w.missing: continue
		contacts+=1
		if w.surface<Tires.Kind.GRAVEL: hard+=1.0
	hard=hard/contacts if contacts>0 else 0.0
	var rough=maxf(tire.y*0.65,tire.x*(1-hard))
	rough=maxf(rough,hard*game.current_wetness*clampf(speed/30,0,0.5))
	tyres.stream_paused=not moving or not car.grounded or rough<0.015
	tyres.pitch_scale=0.75+tire.x*0.65+tire.y*0.15
	tyres.volume_db=-23+linear_to_db(maxf(0.00001,effects_volume*rough))-game.current_wetness*3
	squeal.stream_paused=not moving or not car.grounded or tire.x*hard<0.015
	squeal.pitch_scale=0.85+tire.x*0.35
	squeal.volume_db=-28+linear_to_db(maxf(0.00001,effects_volume*tire.x*hard))
	turbo.stream_paused=not moving or not car.boosting or car.boost<=0 or car.throttle<=0
	turbo.pitch_scale=1+speed*0.012; turbo.volume_db=-23+linear_to_db(maxf(0.00001,effects_volume))
	cue.volume_db=-10+linear_to_db(maxf(0.00001,effects_volume))
	for voice in voices:
		if voice.playing: voice.volume_db=float(voice.get_meta("level",-16))+linear_to_db(maxf(0.00001,float(voice.get_meta("gain",1))*effects_volume))
