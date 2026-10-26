# SPDX-License-Identifier: GPL-3.0-or-later
extends Node
var motor = AudioStreamPlayer.new()
var shot = AudioStreamPlayer.new()
var pickup = AudioStreamPlayer.new()

func _ready() -> void:
	add_child(motor); add_child(shot); add_child(pickup)
	motor.stream=_tone(1.0,72,true); motor.volume_db=-28; motor.play()
	shot.stream=_tone(0.08,170,false,true); shot.volume_db=-24
	pickup.stream=_tone(0.22,660,false); pickup.volume_db=-20

func _tone(duration: float, frequency: float, looped: bool, noise: bool = false) -> AudioStreamWAV:
	var data = PackedByteArray(); var count = int(22050*duration); data.resize(count*2)
	var rng = RandomNumberGenerator.new(); rng.seed=44
	for i in count:
		var t = float(i)/22050; var envelope = 1.0 if looped else pow(1.0-float(i)/count,2)
		var wave = sin(t*TAU*frequency)*0.5+sin(t*TAU*frequency*2)*0.22+sin(t*TAU*frequency*3)*0.1
		if noise: wave=wave*0.3+rng.randf_range(-0.65,0.65)
		data.encode_s16(i*2,int(wave*envelope*20000))
	var wav = AudioStreamWAV.new(); wav.format=AudioStreamWAV.FORMAT_16_BITS; wav.mix_rate=22050; wav.data=data
	if looped: wav.loop_mode=AudioStreamWAV.LOOP_FORWARD; wav.loop_end=count
	return wav

func engine(speed: float, active: bool) -> void:
	motor.stream_paused=not active; motor.pitch_scale=0.65+speed*0.065
