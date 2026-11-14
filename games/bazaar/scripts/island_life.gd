# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
## Bounded visual effects, independent of visitor count or game economy.
var droplets := MultiMesh.new()
var elapsed := 0.0
var fountain_audio := AudioStreamPlayer3D.new()
var sound_enabled := true
var cloth: Array[Node3D] = []
const COUNT := 192

func water_material(ocean := false) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code="""shader_type spatial;
	uniform float frequency = 4.0;
	uniform vec3 deep_color : source_color = vec3(0.10,0.48,0.57);
	varying vec3 world;
	void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
	void fragment(){
	 float wave=sin(world.x*frequency+TIME*2.1)*cos(world.z*frequency*0.95-TIME*1.7);
	 float glint=pow(max(0.0,wave),10.0);
	 ALBEDO=deep_color+vec3(0.06,0.12,0.12)*wave+vec3(0.25)*glint;
	 ROUGHNESS=0.28;SPECULAR=0.65;
	}"""
	var mat := ShaderMaterial.new();mat.shader=shader
	if ocean:
		mat.set_shader_parameter("deep_color",Vector3(0.035,0.19,0.24));mat.set_shader_parameter("frequency",0.32)
	return mat

func _ready() -> void:
	var instance := MultiMeshInstance3D.new();add_child(instance)
	var drop := SphereMesh.new();drop.radius=0.035;drop.height=0.10;drop.radial_segments=6;drop.rings=3
	var mat := StandardMaterial3D.new();mat.albedo_color=Color("cff9f5");mat.roughness=0.25
	drop.material=mat;droplets.transform_format=MultiMesh.TRANSFORM_3D;droplets.mesh=drop
	droplets.instance_count=COUNT;instance.multimesh=droplets
	var water: AudioStreamWAV=load("res://assets/audio/fountain.wav")
	water.loop_mode=AudioStreamWAV.LOOP_FORWARD;water.loop_end=water.data.size()/2
	fountain_audio.stream=water;fountain_audio.volume_db=-20;fountain_audio.unit_size=3;fountain_audio.max_distance=18
	add_child(fountain_audio);fountain_audio.position.y=0.8;fountain_audio.play()
	update_jets()

func set_sound(enabled: bool, paused := false) -> void:
	sound_enabled=enabled;fountain_audio.stream_paused=not enabled or paused

func update_jets() -> void:
	# Eight continuous parabolic jets. All droplets land inside the real basin.
	for i in COUNT:
		var jet := i%8;var t := fmod(elapsed*0.72+float(i/8)/24.0,1.0)
		var a := jet*TAU/8.0
		var p := Vector3(sin(a)*(0.20+2.0*t),1.65+3.8*t-5.0*t*t,cos(a)*(0.20+2.0*t))
		droplets.set_instance_transform(i,Transform3D(Basis.IDENTITY,p))

func _process(delta: float) -> void:
	elapsed+=delta;update_jets()
	for i in cloth.size():cloth[i].rotation.z=sin(elapsed*1.7+i)*0.035

func stop_sound() -> void:
	# Release the looping playback before the audio server is torn down.
	fountain_audio.stream_paused=false
	fountain_audio.stop()
	fountain_audio.stream=null

func _exit_tree() -> void:
	stop_sound()
