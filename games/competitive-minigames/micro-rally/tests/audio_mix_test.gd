# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var game: Node
func _initialize() -> void: call_deferred("run")
func hold(seconds: float) -> void:
	for i in roundi(seconds*20):
		game.sound.update(game,0.05)
		OS.delay_msec(50); await process_frame
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	game.set_process(false); game.set_physics_process(false); game.net.set_process(false)
	game.sound.set_volume("music",0.5,false); game.sound.set_volume("effects",0.75,false)
	# Internal output capture only; no microphone and no host speaker output.
	AudioServer.set_bus_mute(0,true)
	var recorder=AudioEffectRecord.new(); recorder.format=AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(AudioServer.get_bus_index(game.sound.mix_bus),recorder)
	recorder.set_recording_active(true)
	await hold(1.5)
	game.start_race()
	for seconds in [3.0,2.0,1.0]: game.countdown=seconds; await hold(1)
	game.state="race"; var car=game.player()
	car.linear_velocity=Vector3(10,0,14); car.throttle=1; car.grounded=true; car.boosting=true
	await hold(1)
	for i in 6: game.sound.play_event("shot"); await hold(0.3)
	game.sound.play_event("shield"); await hold(0.6)
	game.sound.play_event("impact0"); await hold(0.5)
	car.boosting=false; car.laps=game.laps-1; await hold(5)
	car.finish_time=100; await hold(5.5)
	recorder.set_recording_active(false)
	var wav=recorder.get_recording(); var peak=0; var energy=0.0
	var bytes=wav.data
	for i in range(0,bytes.size(),2):
		var value=absi(bytes.decode_s16(i)); peak=maxi(peak,value); energy+=float(value)*value
	var rms=sqrt(energy/maxf(1,bytes.size()/2))/32768.0
	var ok=wav.get_length()>15 and peak>1000 and peak<32760 and rms>0.001
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mix-output="): ok=wav.save_to_wav(arg.trim_prefix("--mix-output="))==OK and ok
	print("AUDIO MIX ",JSON.stringify({"seconds":wav.get_length(),"peak_db":linear_to_db(float(peak)/32768),"rms_db":linear_to_db(rms),"pcm_bytes":bytes.size(),"passed":ok}))
	await preload("audio_drain.gd").dispose(game,self)
	quit(0 if ok else 1)
