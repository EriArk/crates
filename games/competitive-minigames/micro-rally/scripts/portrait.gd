# SPDX-License-Identifier: GPL-3.0-or-later
extends TextureRect
const Client = preload("res://addons/traineros/avatar_client.gd")
const Presenter = preload("res://addons/traineros/avatar_presenter.gd")
var client: Node
var view: SubViewport
var model: Node3D
var mood = "focused"
var timer = 0.0
var shared_sdk: Node

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	expand_mode=TextureRect.EXPAND_IGNORE_SIZE; stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var shader = Shader.new(); shader.code="shader_type canvas_item; void fragment(){ vec2 p=UV*2.0-1.0; if(dot(p,p)>1.0) discard; COLOR=texture(TEXTURE,UV); }"
	var mask = ShaderMaterial.new(); mask.shader=shader; material=mask
	if shared_sdk!=null:
		shared_sdk.connected.connect(_subscribe_shared)
		shared_sdk.avatar_changed.connect(_appearance)
		shared_sdk.closed.connect(func():
			if not shared_sdk.registered: _clear())
		return
	client=Client.new(); client.app_id="art.abysstail.micro-rally"; add_child(client)
	client.appearance_changed.connect(_appearance)
	client.unavailable.connect(func(_reason): _clear())
	client.connect_host()

func _subscribe_shared() -> void:
	if shared_sdk.capabilities.get("avatar.local")!=1: return
	shared_sdk.request("avatar.subscribe",{},func(result,error):
		if error.is_empty() and result.get("avatar") is Dictionary: _appearance(result.avatar))
	shared_sdk.request("avatar.get",{},func(result,error):
		if error.is_empty() and result.get("avatar") is Dictionary: _appearance(result.avatar))

func _clear() -> void:
	texture=null
	if is_instance_valid(view): view.queue_free()
	view=null; model=null

func _appearance(descriptor: Dictionary) -> void:
	_clear()
	model=Presenter.from_descriptor(descriptor)
	if model==null: return
	view=SubViewport.new(); view.size=Vector2i(192,192); view.transparent_bg=true; view.own_world_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ONCE; add_child(view); view.add_child(model)
	var camera = Camera3D.new(); camera.position=Vector3(0,0.81,1.2); camera.fov=28; camera.near=0.01; camera.far=10; view.add_child(camera)
	var env = WorldEnvironment.new(); env.environment=Environment.new(); env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color.TRANSPARENT; env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("adb6c5"); env.environment.ambient_light_energy=0.7; view.add_child(env)
	var light = DirectionalLight3D.new(); light.rotation_degrees=Vector3(-25,-25,0); light.light_energy=1.4; view.add_child(light)
	texture=view.get_texture(); set_mood(mood,true)

func set_mood(value: String, force: bool = false) -> void:
	if value==mood and not force: return
	mood=value
	# Only named actions supplied by the real SDK model are eligible.
	if is_instance_valid(model): model.play_action(value)

func _process(delta: float) -> void:
	timer+=delta
	if timer>0.10 and is_instance_valid(view): view.render_target_update_mode=SubViewport.UPDATE_ONCE; timer=0
