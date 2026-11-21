# SPDX-License-Identifier: GPL-3.0-or-later
extends SubViewportContainer
const HULL = preload("saucer.glb")
const SKY = preload("sky.gdshader")
const EXHAUST = preload("exhaust.gdshader")
var space := SubViewport.new()
var local_ship: Node3D
var wings := {}
var sky_material := ShaderMaterial.new()
var elapsed := 0.0
var thrust := ShaderMaterial.new()
var jet := CylinderMesh.new()
var drift := Vector2.ZERO
var formation: Array = []
var targets := {}
var dust := MultiMeshInstance3D.new()
var seeds := PackedVector3Array()

func _ready() -> void:
	stretch=true
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	space.own_world_3d=true
	space.handle_input_locally=false
	space.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(space)
	resized.connect(_resize_view)
	_resize_view()
	var camera:=Camera3D.new()
	space.add_child(camera)
	camera.position=Vector3(1.6,7.7,22)
	camera.look_at(Vector3(0,2.9,-11))
	camera.fov=51
	var sky:=Sky.new()
	sky.radiance_size=Sky.RADIANCE_SIZE_32
	sky_material.shader=SKY
	sky_material.set_shader_parameter("source_bearing",Vector3(.22,.05,-.97))
	sky_material.set_shader_parameter("sector_shift",.75)
	sky_material.set_shader_parameter("jump_glow",.035)
	sky.sky_material=sky_material
	var environment:=Environment.new()
	environment.background_mode=Environment.BG_SKY
	environment.sky=sky
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("a5bbf4")
	environment.ambient_light_energy=.8
	environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	var world:=WorldEnvironment.new()
	world.environment=environment
	space.add_child(world)
	for spec in [[Vector3(-38,-32,0),Color("ffe0ae"),1.65],[Vector3(-24,148,0),Color("a7caff"),1.1]]:
		var light:=DirectionalLight3D.new()
		light.rotation_degrees=spec[0]
		light.light_color=spec[1]
		light.light_energy=spec[2]
		space.add_child(light)
	thrust.shader=EXHAUST
	thrust.set_shader_parameter("power",1.0)
	jet.bottom_radius=.36
	jet.top_radius=.055
	jet.height=1
	jet.radial_segments=12
	jet.rings=0
	jet.material=thrust
	local_ship=_ship()
	var field:=MultiMesh.new()
	field.transform_format=MultiMesh.TRANSFORM_3D
	var streak:=BoxMesh.new()
	streak.size=Vector3(.035,.035,.85)
	var glow:=StandardMaterial3D.new()
	glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color=Color("a9c5ec")
	streak.material=glow
	field.mesh=streak
	field.instance_count=68
	field.custom_aabb=AABB(Vector3(-60,-32,-100),Vector3(120,64,130))
	var rng:=RandomNumberGenerator.new()
	rng.seed=149
	for i in field.instance_count:
		var angle:=rng.randf()*TAU
		var radius:=rng.randf_range(11,53)
		seeds.append(Vector3(cos(angle)*radius,sin(angle)*radius*.58,rng.randf()*120))
	dust.multimesh=field
	dust.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	space.add_child(dust)

func _ship() -> Node3D:
	var ship:Node3D=HULL.instantiate()
	space.add_child(ship)
	for nozzle in ["ExhaustPort","ExhaustStarboard"]:
		var port:Node3D=ship.find_child(nozzle,true,false)
		var plume:=MeshInstance3D.new()
		plume.mesh=jet
		plume.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ship.add_child(plume)
		plume.global_position=port.global_position
		plume.rotation.x=PI/2
	return ship

func set_party(ids: Array, own: String, poses: Dictionary) -> void:
	targets=poses
	var others:=ids.duplicate()
	others.erase(own)
	if others==formation:return
	for id in wings.keys():
		if id not in others:
			wings[id].queue_free()
			wings.erase(id)
	formation=others
	for id in others:
		if not wings.has(id):wings[id]=_ship()
		var slot:=others.find(id)
		var row:=floori(slot/2.0)
		var spread:=11.0+row*2.2
		var origin:=Vector3(spread*(-1 if slot%2==0 else 1),2.4+row*1.1,-17.0-row*11)
		wings[id].position=origin
		wings[id].set_meta("origin",origin)

func _process(delta: float) -> void:
	elapsed+=delta
	var pads:=Input.get_connected_joypads()
	var stick:=Vector2.ZERO
	if not pads.is_empty():
		stick=Vector2(Input.get_joy_axis(pads[0],JOY_AXIS_LEFT_X),Input.get_joy_axis(pads[0],JOY_AXIS_LEFT_Y))
		stick=stick.normalized()*clampf((stick.length()-.14)/.68,0,1)
	stick+=Input.get_vector("ui_left","ui_right","ui_up","ui_down")
	drift=drift.lerp(stick.limit_length(),1-exp(-9.0*delta))
	_pose(local_ship,Vector3.ZERO,drift,delta)
	for id in formation:
		_pose(wings[id],wings[id].get_meta("origin"),targets.get(id,Vector2.ZERO),delta)
	for i in seeds.size():
		var p:=seeds[i]
		p.z=fposmod(p.z+elapsed*28,120)-98
		dust.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,p))

func _pose(ship: Node3D, origin: Vector3, axis: Vector2, delta: float) -> void:
	var wave:=sin(elapsed*1.45+origin.x)*.14
	var blend:=1.0-exp(-11.0*delta)
	ship.position=ship.position.lerp(origin+Vector3(axis.x*3.3,-axis.y*2.3+wave,0),blend)
	ship.rotation=ship.rotation.lerp(Vector3(-axis.y*.19,-axis.x*.13,-axis.x*.40+wave*.08),blend)

func _resize_view() -> void:
	stretch_shrink=2 if size.x>=1200 else 1
