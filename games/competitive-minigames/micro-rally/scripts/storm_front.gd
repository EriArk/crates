# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
var game: Node3D
var clouds=MultiMeshInstance3D.new()
var mat: ShaderMaterial
var outlines: Array[ShaderMaterial]=[]
var bolts: Array[MeshInstance3D]=[]
var clock=0.0
var haze: ShaderMaterial
var haze_layer=CanvasLayer.new()
var last_bolt=-1
var wind=AudioStreamPlayer.new()
var filter: AudioEffectLowPassFilter
var debris=MultiMeshInstance3D.new()
func _ready() -> void:
	# Portable haze is independent of backend depth-fog support, below all HUD text.
	haze_layer.layer=0; add_child(haze_layer)
	var veil=ColorRect.new(); veil.mouse_filter=Control.MOUSE_FILTER_IGNORE; veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	haze=ShaderMaterial.new(); haze.shader=preload("res://shaders/storm_haze.gdshader"); veil.material=haze; haze_layer.add_child(veil)
	add_child(wind); wind.bus=game.sound.mix_bus; wind.stream=game.sound._tone(2.0,40,true,1.0); wind.pitch_scale=0.6; wind.volume_db=-80; wind.play()
	filter=AudioEffectLowPassFilter.new(); filter.cutoff_hz=18000
	var bus=AudioServer.get_bus_index(game.sound.mix_bus)
	if bus>=0: AudioServer.add_bus_effect(bus,filter)
	var multi=MultiMesh.new(); multi.transform_format=MultiMesh.TRANSFORM_3D
	var chip=BoxMesh.new(); chip.size=Vector3(0.18,0.025,0.35); multi.mesh=chip; multi.instance_count=32
	debris.multimesh=multi; debris.material_override=game.Art.material(Color("8e9875")); debris.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(debris)
	mat=ShaderMaterial.new(); mat.shader=preload("res://shaders/storm_wall.gdshader")
	var cloud_mesh=QuadMesh.new(); cloud_mesh.size=Vector2.ONE
	var cloud_batch=MultiMesh.new(); cloud_batch.transform_format=MultiMesh.TRANSFORM_3D; cloud_batch.mesh=cloud_mesh; cloud_batch.instance_count=288
	cloud_batch.custom_aabb=AABB(Vector3(-500,-30,-500),Vector3(1000,160,1000))
	clouds.multimesh=cloud_batch; clouds.material_override=mat; clouds.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(clouds)
	for car in game.cars:
		var outline=ShaderMaterial.new(); outline.shader=preload("res://shaders/storm_outline.gdshader"); outline.render_priority=100; outlines.append(outline)
		for mesh in car.visual.find_children("*","MeshInstance3D",true,false):
			if mesh!=car.dirt_mesh: mesh.material_overlay=outline
	for i in 9:
		var node=game.Art.box(self,Vector3(0.25,1,0.25),Vector3.ZERO,Color("a4dfff")); node.material_override=game.Art.material(Color("a4dfff"),1.5)
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; node.visible=false; bolts.append(node)
func update(_delta: float) -> void:
	var active=game.is_royale() and game.state in ["race","countdown","pause","results"]
	visible=active; haze_layer.visible=active
	wind.stream_paused=not active or game.state in ["pause","results"]
	if not active: return
	clock=game.elapsed
	game.royale.update_zone(clock)
	var circle=game.royale.center; var radius=game.royale.radius
	var followed=game.royale.focus()
	var density=smoothstep(-10,12,game.royale.outside(followed.position))
	haze.set_shader_parameter("density",density); haze.set_shader_parameter("clock",clock)
	var viewport_size=game.get_viewport().get_visible_rect().size
	haze.set_shader_parameter("focus",Vector2(0.5,0.66) if game.race_camera.mode==game.race_camera.Mode.HOOD else game.camera.unproject_position(followed.position)/viewport_size); haze.set_shader_parameter("aspect",viewport_size.x/viewport_size.y)
	wind.volume_db=linear_to_db(maxf(0.0001,game.sound.effects_volume*(0.02+density*0.18)))
	filter.cutoff_hz=lerpf(18000,3800,density)
	debris.visible=density>0.05
	for i in 32:
		var p=followed.position+Vector3(fposmod(i*7.3-clock*14,48)-24,0.7+fposmod(i*1.7+clock*0.5,8),fposmod(i*13.7,40)-20)
		debris.multimesh.set_instance_transform(i,Transform3D(Basis(Vector3(1,0,0),clock*2+i),p))
	var environment=game.weather.environment
	environment.fog_depth_begin=lerpf(65,2,density); environment.fog_depth_end=lerpf(150,30,density)
	environment.fog_light_color=Color("8b9e9f").lerp(Color("263c50"),density)
	for i in 288:
		var layer=i/96; var angle=TAU*float(i%96)/96.0+float(layer)*0.025
		var edge=maxf(1,radius+layer*5+sin(i*2.3+clock*0.18)*3)
		var p=Vector3(circle.x+sin(angle)*edge,9+layer*17+sin(i*1.7+clock*0.2)*4,circle.y+cos(angle)*edge)
		var basis=game.camera.global_basis.scaled(Vector3(maxf(22,radius*0.11),38,1))
		clouds.multimesh.set_instance_transform(i,Transform3D(basis,p))
	var pulse=fmod(clock,7.0); var flash=pow(maxf(0,1-pulse/0.45),2) if clock>3 else 0.0
	mat.set_shader_parameter("clock",clock); mat.set_shader_parameter("flash",flash)
	if int(clock/7)!=last_bolt:
		last_bolt=int(clock/7)
		if clock>90: game.sound.play_event("thunder",minf(42,absf(game.royale.outside(followed.position))*0.3))
		var angle=float(last_bolt)*2.39996
		var base=Vector3(circle.x+sin(angle)*radius,0,circle.y+cos(angle)*radius); base.y=game.track.height_at(base)
		var previous=base+Vector3.UP*55
		for i in bolts.size():
			var next=base+Vector3(sin(i*17+last_bolt)*3,(8-i)*6,cos(i*13+last_bolt)*2)
			var direction=next-previous; var node=bolts[i]; node.position=(previous+next)*0.5; node.scale=Vector3(1,direction.length(),1)
			node.basis=Basis(Quaternion(Vector3.UP,direction.normalized())).scaled(node.scale); previous=next
	for node in bolts: node.visible=flash>0.05
	for car in game.cars:
		var own=car==followed
		var seen=own or game.royale.can_see(followed,car)
		car.visible=seen
		var fog=smoothstep(-12,10,game.royale.outside(car.position))
		outlines[car.index].set_shader_parameter("strength",(0.75 if own else 0.22+flash*0.35)*fog if seen and car.health>0 else 0)
func _exit_tree() -> void:
	wind.stop(); wind.stream=null
	if is_instance_valid(game.sound):
		var bus=AudioServer.get_bus_index(game.sound.mix_bus)
		if bus>=0:
			for i in range(AudioServer.get_bus_effect_count(bus)-1,-1,-1):
				if AudioServer.get_bus_effect(bus,i)==filter: AudioServer.remove_bus_effect(bus,i)
	if is_instance_valid(game.weather): game.weather.last_sample={}; game.weather.set_sample(game.conditions.sample(game.elapsed))
	for car in game.cars:
		if not is_instance_valid(car): continue
		car.visible=true
