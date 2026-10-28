# SPDX-License-Identifier: GPL-3.0-or-later
extends TextureRect
const Client = preload("res://addons/traineros/avatar_client.gd")
const Presenter = preload("res://addons/traineros/avatar_presenter.gd")
const Rig = preload("driver_rig.gd")
const Feedback = preload("driver_feedback.gd")
var client: Node
var view: SubViewport
var rig: Node3D
var model: Node3D
var shared_sdk: Node
var game: Node
var feedback=Feedback.new()
var mood="neutral"
var mood_remaining=0.0
var timer=0.0
var generation=0
var descriptor_key=""
var revoked=false

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	expand_mode=TextureRect.EXPAND_IGNORE_SIZE; stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_build_view(null)
	if shared_sdk!=null:
		shared_sdk.connected.connect(_subscribe_shared)
		shared_sdk.avatar_changed.connect(_appearance)
		shared_sdk.identity_revoked.connect(_revoke)
		shared_sdk.closed.connect(func():
			if not shared_sdk.registered: _revoke())
		if shared_sdk.registered: _subscribe_shared()
		return
	client=Client.new(); client.app_id="art.abysstail.micro-rally"; add_child(client)
	client.appearance_changed.connect(_appearance)
	client.unavailable.connect(func(_reason): _clear())
	client.connect_host()

func _subscribe_shared() -> void:
	revoked=false; generation+=1
	if shared_sdk.capabilities.get("avatar.local")!=1: _clear(); return
	var expected=generation
	shared_sdk.request("avatar.subscribe",{},func(result,error):
		if generation!=expected or revoked: return
		if error.is_empty() and result.get("avatar") is Dictionary: _appearance(result.avatar)
		else: _clear())

func _revoke() -> void:
	revoked=true; _clear()

func _clear() -> void:
	generation+=1; descriptor_key=""; feedback.reset(); mood="neutral"; mood_remaining=0
	if is_instance_valid(model): model.clear_identity()
	model=null
	_build_view(null)

func _appearance(descriptor: Dictionary) -> void:
	if revoked: return
	# A pushed update supersedes a pending subscription reply.
	generation+=1
	var key=str(descriptor.get("profile",""))+":"+str(descriptor.get("revision",""))+":"+str(descriptor.get("sha256",""))
	if key==descriptor_key and is_instance_valid(model): return
	_clear()
	var avatar=Presenter.from_descriptor(descriptor)
	if avatar==null: return
	descriptor_key=key; model=avatar
	_build_view(model)

func _build_view(avatar: Node3D) -> void:
	texture=null
	if is_instance_valid(view):
		remove_child(view); view.queue_free()
	view=SubViewport.new(); view.size=Vector2i(360,360); view.transparent_bg=true; view.own_world_3d=true
	view.msaa_3d=Viewport.MSAA_2X; view.render_target_update_mode=SubViewport.UPDATE_ONCE; add_child(view)
	rig=Rig.new(); view.add_child(rig)
	if not rig.build(avatar):
		if is_instance_valid(avatar): avatar.clear_identity(); avatar.queue_free()
		model=null; descriptor_key=""; rig.skeleton=null; rig.model=null
	var camera=Camera3D.new(); view.add_child(camera)
	camera.position=Vector3(0.58,0.67,1.3); camera.look_at(Vector3(0,0.45,-0.07))
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=1.12; camera.h_offset=0.07; camera.near=0.01; camera.far=5
	var env=WorldEnvironment.new(); env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR; env.environment.background_color=Color.TRANSPARENT
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color=Color("cfdfeb"); env.environment.ambient_light_energy=0.5
	view.add_child(env)
	var key=DirectionalLight3D.new(); key.rotation_degrees=Vector3(-35,-25,0); key.light_energy=1.15; view.add_child(key)
	var fill=DirectionalLight3D.new(); fill.rotation_degrees=Vector3(-20,135,0); fill.light_color=Color("ffcc85"); fill.light_energy=0.65; view.add_child(fill)
	texture=view.get_texture()

func reset_race() -> void:
	feedback.reset(); set_mood("neutral",true)

func set_mood(value: String, force: bool = false) -> void:
	var expression={"focused":"neutral","excited":"happy","victory":"happy","hurt":"worried"}.get(value,value)
	if expression==mood and not force: return
	# Damage can interrupt an overtake, boost cannot perpetually reset its timer.
	if value=="excited" and mood_remaining>0: return
	mood=expression; mood_remaining=2.0 if expression in ["happy","sad"] else 0.7 if expression=="worried" else 0.0
	if is_instance_valid(model): model.set_expression("laughing" if expression=="happy" else expression)

func _process(delta: float) -> void:
	if not is_instance_valid(view): return
	var paused=game!=null and game.state=="pause"
	view.process_mode=Node.PROCESS_MODE_INHERIT if is_visible_in_tree() and not paused else Node.PROCESS_MODE_DISABLED
	if not is_visible_in_tree(): return
	if game!=null and not game.cars.is_empty():
		var reaction=feedback.observe(game,delta)
		if not reaction.is_empty(): set_mood(reaction,true)
		if game.state=="pause": return
	mood_remaining=maxf(0,mood_remaining-delta)
	if mood_remaining==0 and mood!="neutral": set_mood("neutral")
	timer+=delta
	if timer<1.0/30: return
	timer=fmod(timer,1.0/30)
	rig.rotation.y=feedback.yaw; rig.position.y=feedback.bounce
	rig.rotation.z=-feedback.steering*0.035
	rig.pose(feedback.steering,feedback.throttle,feedback.brake)
	view.render_target_update_mode=SubViewport.UPDATE_ONCE
