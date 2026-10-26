# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
const RAIN_COUNT = 240
var environment: Environment
var sun: DirectionalLight3D
var rain: MultiMeshInstance3D
var rain_material: ShaderMaterial
var rain_clock = 0.0
var rainy = false

func _ready() -> void:
	var world = WorldEnvironment.new(); environment=Environment.new(); world.environment=environment; add_child(world)
	environment.background_mode=Environment.BG_COLOR
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR if _compatibility() else Environment.TONE_MAPPER_ACES
	environment.fog_enabled=true; environment.fog_mode=Environment.FOG_MODE_DEPTH
	sun=DirectionalLight3D.new(); sun.name="Sun"; sun.shadow_enabled=true; add_child(sun)
	sun.directional_shadow_max_distance=85; sun.shadow_bias=0.08; sun.shadow_normal_bias=1.5
	sun.directional_shadow_blend_splits=true; sun.directional_shadow_split_1=0.12; sun.directional_shadow_split_2=0.30; sun.directional_shadow_split_3=0.65; sun.shadow_blur=1.2
	rain=MultiMeshInstance3D.new(); rain.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh = QuadMesh.new(); mesh.size=Vector2(0.028,0.68)
	var batch = MultiMesh.new(); batch.transform_format=MultiMesh.TRANSFORM_3D; batch.mesh=mesh
	batch.instance_count=RAIN_COUNT; batch.custom_aabb=AABB(Vector3(-30,-1,-30),Vector3(60,22,60))
	rain.multimesh=batch; rain_material=ShaderMaterial.new(); rain_material.shader=preload("res://shaders/rain.gdshader")
	rain.material_override=rain_material; add_child(rain)

func _compatibility() -> bool: return RenderingServer.get_current_rendering_method()=="gl_compatibility"

func apply(conditions: RefCounted) -> void:
	var sunset: bool=conditions.time_of_day=="sunset"
	var cloud: float=0.0 if conditions.weather=="clear" else (0.72 if conditions.weather=="overcast" else 0.90)
	var ambient = Color("c0becb") if sunset else Color("b7c9d1")
	environment.ambient_light_color=ambient.lerp(Color("c4cdd1"),cloud)
	environment.ambient_light_energy=(0.32 if _compatibility() else 0.48) if sunset else (0.30 if _compatibility() else 0.46)
	environment.ambient_light_energy+=cloud*0.09
	environment.background_color=(Color("cbb8a4") if sunset else Color("a8bbb0")).lerp(Color("9baeb4"),cloud)
	environment.fog_light_color=(Color("b4a89d") if sunset else Color("83a29c")).lerp(Color("9baeb4"),cloud)
	environment.fog_depth_begin=lerpf(95,65,cloud); environment.fog_depth_end=lerpf(200,150,cloud); environment.fog_density=0.15
	sun.rotation_degrees=Vector3(-22,-82,0) if sunset else Vector3(-40,-55,0)
	sun.light_color=(Color("ffdab0") if sunset else Color("ffebcb")).lerp(Color("e2e9ed"),cloud)
	sun.light_energy=(0.50 if _compatibility() else 0.90)*lerpf(0.88 if sunset else 1.0,0.38,cloud)
	rainy=conditions.weather=="rain"; rain.visible=rainy; rain_clock=0
	rain_material.set_shader_parameter("rain_time",0.0)
	var random = RandomNumberGenerator.new(); random.seed=conditions.seed_value
	for i in RAIN_COUNT:
		var position = Vector3(random.randf_range(-29,29),random.randf_range(0,20),random.randf_range(-29,29))
		rain.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,position))

func update(delta: float, focus: Vector3, running: bool) -> void:
	if not rainy: return
	rain.position=focus-Vector3.UP
	rain_material.set_shader_parameter("anchor_y",rain.position.y)
	if running: rain_clock=fmod(rain_clock+delta,4096.0)
	rain_material.set_shader_parameter("rain_time",rain_clock)
