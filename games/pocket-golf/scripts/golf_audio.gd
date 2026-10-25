# SPDX-License-Identifier: GPL-3.0-or-later
extends Node
## Local presentation. Absolute shot time consumes each cue once, even muted.
const MUSIC = preload("res://assets/audio/little-green.ogg")
const ROLL = preload("res://assets/audio/roll.ogg")
const CUES := {
	"strike":preload("res://assets/audio/kenney/impactWood_light_000.ogg"),
	"strike_sand":preload("res://assets/audio/sand.ogg"),
	"wood":preload("res://assets/audio/kenney/impactWood_light_001.ogg"),
	"stone":preload("res://assets/audio/kenney/impactGeneric_light_000.ogg"),
	"rim":preload("res://assets/audio/kenney/impactMetal_light_000.ogg"),
	"cup":preload("res://assets/audio/cup.ogg"),
	"step_l":preload("res://assets/audio/kenney/footstep_grass_000.ogg"),
	"step_r":preload("res://assets/audio/kenney/footstep_grass_001.ogg"),
	"ui":preload("res://assets/audio/ui.ogg"),
	"cup-jingle":preload("res://assets/audio/cup-jingle.ogg"),
	"ace-jingle":preload("res://assets/audio/ace-jingle.ogg"),
	"round-jingle":preload("res://assets/audio/round-jingle.ogg")}
const LIMIT := 8
signal cue_played(kind: String)
var music: AudioStreamPlayer
var rolling: AudioStreamPlayer
var jingle: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var music_percent := 45
var effects_percent := 75
var path := "user://audio.cfg"
var events: Array = []
var cursor := 0
var clock := -1.0
var focused := true
var paused := false
var duck := 0.0
var gains: Dictionary = {}
var stopped := false

func _ready() -> void:
	load_settings()
	music=_player(); music.stream=MUSIC.duplicate(); music.stream.loop=true
	rolling=_player(); rolling.stream=ROLL.duplicate(); rolling.stream.loop=true
	jingle=_player()
	for i in LIMIT: voices.append(_player())
	music.volume_db=-80; music.play()
	apply_levels()

func _player() -> AudioStreamPlayer:
	var node := AudioStreamPlayer.new(); add_child(node); return node

func load_settings() -> void:
	music_percent=45; effects_percent=75
	var config := ConfigFile.new()
	if config.load(path)!=OK: return
	var m = config.get_value("audio","music",45)
	var s = config.get_value("audio","effects",75)
	if m is int and m>=0 and m<=100: music_percent=m
	if s is int and s>=0 and s<=100: effects_percent=s

func save_settings() -> Error:
	var config := ConfigFile.new()
	config.set_value("audio","music",music_percent)
	config.set_value("audio","effects",effects_percent)
	return config.save(path)

func apply_levels() -> void:
	if music==null: return
	# True mute, including sounds already playing, without touching system volume.
	for voice in voices: voice.volume_linear=effects_percent/100.0*gains.get(voice,0.5)
	jingle.volume_linear=effects_percent/100.0*0.75
	if effects_percent==0: rolling.volume_linear=0
	if music_percent==0: music.volume_linear=0

func set_state(is_focused: bool, is_paused: bool) -> void:
	if focused and not is_focused:
		for voice in voices: voice.stop()
		if rolling!=null: rolling.stop()
		if jingle!=null: jingle.stop()
	focused=is_focused; paused=is_paused
	if music==null: return
	music.stream_paused=not focused
	for voice in voices: voice.stream_paused=not focused or (paused and voice.stream!=CUES.ui)
	rolling.stream_paused=not focused or paused
	jingle.stream_paused=not focused or paused

func _process(delta: float) -> void:
	if not focused: return
	duck=maxf(0,duck-delta)
	var target := music_percent/100.0*(0.22 if duck>0 else 0.45 if paused else 0.75)
	music.volume_linear=lerpf(music.volume_linear,target,1-exp(-delta*5))

func cue(kind: String, strength: float=1.0) -> void:
	if stopped or not focused or effects_percent==0 or (paused and kind!="ui") or not CUES.has(kind): return
	if kind.ends_with("jingle"):
		jingle.stream=CUES[kind]; jingle.play(); duck=jingle.stream.get_length()+0.15
	else:
		var chosen: AudioStreamPlayer
		for voice in voices:
			if not voice.playing: chosen=voice; break
		if chosen==null: return # bounded polyphony, no unbounded impact backlog
		gains[chosen]=clampf(strength,0.05,1.0)*(0.22 if kind.begins_with("step") else 0.6)
		chosen.stream=CUES[kind]; chosen.volume_linear=effects_percent/100.0*gains[chosen]
		chosen.stream_paused=false; chosen.play()
	cue_played.emit(kind)

func begin(visual_events: Array) -> void:
	clear_shot()
	for e in visual_events:
		if e.kind in ["strike","strike_sand","wood","stone","rim","cup","ace"]:
			events.append(e.duplicate())

func seek(time: float, speed: float=0.0, in_sand: bool=false) -> void:
	if stopped: return
	if time<clock: return # rewinds never replay a sound
	# A moving online presentation consumes muted events, not paused sound tails.
	if paused or not focused:
		for voice in voices: voice.stop()
		jingle.stop()
	clock=time
	while cursor<events.size() and events[cursor].time<=time:
		var event: Dictionary = events[cursor]; cursor+=1
		# Discard old impacts after a hitch or background interval.
		if time-event.time>0.22: continue
		if event.kind in ["cup","ace"]:
			cue("cup"); cue("ace-jingle" if event.kind=="ace" else "cup-jingle")
		else: cue(event.kind,event.strength)
	var volume := clampf(speed/8.0,0,1)*effects_percent/100.0*(0.40 if in_sand else 0.22)
	rolling.volume_linear=volume if focused and not paused else 0.0
	rolling.pitch_scale=0.8+clampf(speed/12,0,0.5)
	if speed>0.08 and focused and not paused:
		if not rolling.playing: rolling.play()
	else: rolling.stop()

func clear_shot() -> void:
	events.clear(); cursor=0; clock=-1
	if rolling!=null: rolling.stop()
	for voice in voices: voice.stop()

func reset() -> void:
	clear_shot()
	if jingle!=null: jingle.stop()
	duck=0

func shutdown() -> void:
	stopped=true
	set_process(false)
	for voice in voices+[music,rolling,jingle]:
		if is_instance_valid(voice): voice.stop(); voice.stream=null
	gains.clear()

func _exit_tree() -> void:
	shutdown()
