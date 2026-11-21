# SPDX-License-Identifier: GPL-3.0-or-later
extends Node

const BANK := "res://assets/audio/"
const CALLS := ["Pigeon", "Birb", "Frog", "Bunny", "Dino", "Yeti"]
const MUSIC_LEVEL := -8.0
const CALL_RADIUS := 19.0
var music := AudioStreamPlayer.new()
var steps := AudioStreamPlayer.new()
var voice := AudioStreamPlayer.new()
var call := AudioStreamPlayer3D.new()
var samples := {}
var effects_enabled := true
var quiet := false
var call_clock := 2.0
var caller: Node3D
var population: Node3D
var visitor: Node3D
var previous_steps := {}
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	for surface in ["stone", "grass", "sand", "metal"]:
		for index in 3:cache_sample(surface + str(index))
	for species in CALLS:cache_sample(species.to_lower())
	for index in 6:cache_sample("voice" + str(index))
	for player in [music, steps, voice, call]:add_child(player)
	music.stream = preload("res://assets/audio/awning_waltz.ogg")
	music.volume_db = MUSIC_LEVEL
	voice.volume_db = -11
	call.max_distance = CALL_RADIUS
	call.unit_size = 4
	call.volume_db = -8

func cache_sample(key: String) -> void:
	samples[key] = load(BANK + key + ".wav")

func set_music(enabled: bool) -> void:
	if enabled and not music.playing:music.play()
	elif not enabled:music.stop()

func set_effects(enabled: bool) -> void:
	effects_enabled = enabled
	if not enabled:
		steps.stop()
		voice.stop()
		call.stop()

func set_quiet(value: bool) -> void:
	quiet = value
	if value:
		call.stop()
		steps.stop()
	else:voice.stop()

func footstep(surface: String, speed: float, crouched: bool) -> void:
	if not effects_enabled or quiet:return
	var index := posmod(int(previous_steps.get(surface, -1)) + rng.randi_range(1, 2), 3)
	previous_steps[surface] = index
	steps.stream = samples[surface + str(index)]
	steps.pitch_scale = rng.randf_range(.94, 1.06)
	steps.volume_db = -18.0 if crouched else lerpf(-12, -5, clampf(speed / 7, 0, 1))
	steps.play()

func syllable(character: int, ordinal: int, pitch: float) -> void:
	if not effects_enabled:return
	voice.stream = samples["voice" + str(posmod(character + ordinal, 6))]
	voice.pitch_scale = pitch * rng.randf_range(.96, 1.04)
	voice.play()

func _process(delta: float) -> void:
	music.volume_db = move_toward(music.volume_db, MUSIC_LEVEL - (6 if quiet else 0), delta * 18)
	if not effects_enabled or quiet or not is_instance_valid(population):return
	if call.playing:
		if is_instance_valid(caller) and caller.is_visible_in_tree():
			call.global_position = caller.global_position
		else:call.stop()
		return
	call_clock -= delta
	if call_clock > 0:return
	call_clock = rng.randf_range(3.2, 6.4)
	var nearby: Array[Dictionary] = []
	for actor in population.birds + population.residents + population.hired_sellers:
		if actor.species not in CALLS or not actor.active or not actor.node.is_visible_in_tree():continue
		if visitor.global_position.distance_to(actor.node.global_position) < CALL_RADIUS:
			nearby.append(actor)
	if nearby.is_empty():return
	var selected: Dictionary = nearby[rng.randi_range(0, nearby.size()-1)]
	caller = selected.node
	call.global_position = caller.global_position
	call.stream = samples[selected.species.to_lower()]
	call.pitch_scale = rng.randf_range(.91, 1.09)
	call.play()

func stop_all() -> void:
	set_process(false)
	for player in [music, steps, voice, call]:player.stop()

func _exit_tree() -> void:
	stop_all()
