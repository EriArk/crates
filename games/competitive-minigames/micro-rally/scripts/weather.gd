# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
const RAIN_COUNT = 240
var environment: Environment
var sun: DirectionalLight3D
var rain: MultiMeshInstance3D
var rain_material: ShaderMaterial
var rain_clock = 0.0
var rainy = false
const HEADLIGHT_LIMIT = 4
var headlights: Array[SpotLight3D] = []
var light_cars: Array = [null,null,null,null]
var darkness = 0.0
var last_sample: Dictionary = {}

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
	for i in HEADLIGHT_LIMIT:
		var light = SpotLight3D.new(); light.name="Headlight"+str(i); light.shadow_enabled=false
		light.spot_range=19; light.spot_angle=28; light.spot_attenuation=0.65; light.spot_angle_attenuation=1.4
		light.light_color=Color("ffe4b6"); light.light_energy=0; light.visible=false
		add_child(light); headlights.append(light)

func _compatibility() -> bool: return RenderingServer.get_current_rendering_method()=="gl_compatibility"

func apply(conditions: RefCounted) -> void:
	last_sample={}; set_sample(conditions.sample()); rain_clock=0
	rain_material.set_shader_parameter("rain_time",0.0)
	var random = RandomNumberGenerator.new(); random.seed=conditions.seed_value
	for i in RAIN_COUNT:
		var position = Vector3(random.randf_range(-29,29),random.randf_range(0,20),random.randf_range(-29,29))
		rain.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,position))

func profile(time: String, weather: String) -> Dictionary:
	var cloud = {"clear":0.0,"overcast":0.72,"rain":0.90}[weather]
	var values = {
		"day":["b7c9d1",0.46,0.30,"a8bbb0","83a29c",Vector3(-40,-55,0),"ffebcb",1.0,0.0],
		"sunset":["c0becb",0.48,0.32,"cbb8a4","b4a89d",Vector3(-22,-82,0),"ffdab0",0.88,0.3],
		"night":["9cabc9",0.42,0.27,"28394f","465974",Vector3(-52,35,0),"b8caf0",0.26,1.0],
		"dawn":["b5c2d0",0.46,0.31,"c1b8bd","a5b5be",Vector3(-18,78,0),"ffe3c8",0.78,0.3]
	}[time]
	var night = time=="night"
	return {"ambient":Color(values[0]).lerp(Color("9eacc0") if night else Color("c4cdd1"),cloud),
		"ambient_energy":float(values[2] if _compatibility() else values[1])+cloud*0.09,
		"background":Color(values[3]).lerp(Color("394c64") if night else Color("9baeb4"),cloud),
		"fog":Color(values[4]).lerp(Color("50627b") if night else Color("9baeb4"),cloud),
		"fog_begin":lerpf(95,65,cloud),"fog_end":lerpf(200,150,cloud),"rotation":values[5],
		"sun_color":Color(values[6]).lerp(Color("a8b9d5") if night else Color("e2e9ed"),cloud),
		"sun_energy":(0.50 if _compatibility() else 0.90)*lerpf(values[7],0.16 if night else 0.38,cloud),
		"darkness":values[8],"rain":1.0 if weather=="rain" else 0.0}

func set_sample(sample: Dictionary) -> void:
	if sample==last_sample: return
	last_sample=sample.duplicate(true)
	var a = profile(sample.from.time,sample.from.weather); var b = profile(sample.to.time,sample.to.weather)
	var t: float=sample.blend
	environment.ambient_light_color=a.ambient.lerp(b.ambient,t); environment.ambient_light_energy=lerpf(a.ambient_energy,b.ambient_energy,t)
	environment.background_color=a.background.lerp(b.background,t); environment.fog_light_color=a.fog.lerp(b.fog,t)
	environment.fog_depth_begin=lerpf(a.fog_begin,b.fog_begin,t); environment.fog_depth_end=lerpf(a.fog_end,b.fog_end,t); environment.fog_density=0.15
	sun.rotation=Vector3(lerp_angle(deg_to_rad(a.rotation.x),deg_to_rad(b.rotation.x),t),lerp_angle(deg_to_rad(a.rotation.y),deg_to_rad(b.rotation.y),t),0)
	sun.light_color=a.sun_color.lerp(b.sun_color,t); sun.light_energy=lerpf(a.sun_energy,b.sun_energy,t)
	darkness=lerpf(a.darkness,b.darkness,t)
	var intensity = lerpf(a.rain,b.rain,t)
	rainy=intensity>0.001; rain.visible=rainy; rain_material.set_shader_parameter("intensity",intensity)

func update_headlights(cars: Array, delta: float, player_index: int = 0) -> void:
	if cars.is_empty(): return
	light_cars[0]=cars[player_index]
	var focus: Vector3=cars[player_index].position
	for i in range(1,HEADLIGHT_LIMIT):
		if not is_instance_valid(light_cars[i]) or light_cars[i] not in cars or light_cars[i]==light_cars[0] or light_cars[i].position.distance_to(focus)>40:
			light_cars[i]=null; headlights[i].light_energy=0
		if light_cars[i]==null:
			var distance = 32.0
			for car in cars:
				if car in light_cars: continue
				var d: float=car.position.distance_to(focus)
				if d<distance: distance=d; light_cars[i]=car
	for i in HEADLIGHT_LIMIT:
		var car = light_cars[i]; var light = headlights[i]
		if not is_instance_valid(car): light.visible=false; light.light_energy=0; continue
		var forward: Vector3=-car.global_basis.z
		light.global_position=car.global_position+forward*1.6+Vector3.UP*0.3
		light.look_at(light.global_position+forward*12-Vector3.UP*2.4,Vector3.UP)
		var fade = 1.0 if i==0 else 1.0-smoothstep(27,40,car.position.distance_to(focus))
		light.light_energy=lerpf(light.light_energy,darkness*fade*(1.1 if _compatibility() else 1.7),1.0-exp(-delta*7))
		light.visible=light.light_energy>0.01
	for car in cars: car.lamp_material.emission_energy_multiplier=darkness*1.4

func update(delta: float, focus: Vector3, running: bool) -> void:
	if not rainy: return
	rain.position=focus-Vector3.UP
	rain_material.set_shader_parameter("anchor_y",rain.position.y)
	if running: rain_clock=fmod(rain_clock+delta,4096.0)
	rain_material.set_shader_parameter("rain_time",rain_clock)
