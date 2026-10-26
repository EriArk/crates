# SPDX-License-Identifier: GPL-3.0-or-later
extends SubViewportContainer
const Art = preload("art.gd")
var model_id = "race"
var tint = Color("ff8a28")
var model: Node3D
func _ready() -> void:
	custom_minimum_size=Vector2(520,170); stretch=true; mouse_filter=Control.MOUSE_FILTER_IGNORE
	var view=SubViewport.new(); view.size=Vector2i(520,170); view.own_world_3d=true; view.transparent_bg=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; add_child(view)
	model=Art.model("cars",model_id); view.add_child(model)
	for part in model.find_children("*","MeshInstance3D",true,false):
		for surface in part.mesh.get_surface_count():
			var original=part.mesh.surface_get_material(surface)
			if original is StandardMaterial3D and original.albedo_texture!=null:
				var paint=ShaderMaterial.new(); paint.shader=preload("res://shaders/paint.gdshader")
				paint.set_shader_parameter("palette",original.albedo_texture); paint.set_shader_parameter("paint",tint); paint.set_shader_parameter("damage",0)
				part.set_surface_override_material(surface,paint)
	var camera=Camera3D.new(); camera.position=Vector3(4,2.5,4); camera.fov=30; view.add_child(camera); camera.look_at(Vector3(0,0.5,0))
	var env=WorldEnvironment.new(); env.environment=Environment.new(); env.environment.background_mode=Environment.BG_COLOR; env.environment.background_color=Color.TRANSPARENT
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color=Color("c2ccdf"); env.environment.ambient_light_energy=0.65; view.add_child(env)
	var light=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-35,-30,0); light.light_energy=1.4; view.add_child(light)
func _process(delta: float) -> void:
	if is_instance_valid(model): model.rotation.y+=delta*0.25
