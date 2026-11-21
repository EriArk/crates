# SPDX-License-Identifier: GPL-3.0-or-later
extends SubViewportContainer
const Art = preload("art.gd")
var model_id = "race"
var tint = Color("ff8a28")
var model: Node3D
var preview_size = Vector2(520,170)
func _ready() -> void:
	custom_minimum_size=preview_size; stretch=true; mouse_filter=Control.MOUSE_FILTER_IGNORE
	var view=SubViewport.new(); view.size=Vector2i(preview_size); view.own_world_3d=true; view.transparent_bg=true
	view.msaa_3d=Viewport.MSAA_2X
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; add_child(view)
	var shadow=MeshInstance3D.new(); var disc=QuadMesh.new(); disc.size=Vector2(4,3)
	shadow.mesh=disc; shadow.position.y=0.01; shadow.rotation.x=-PI/2
	var shadow_image=Image.create(64,64,false,Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var radius=Vector2((x-31.5)/31.5,(y-31.5)/31.5).length()
			shadow_image.set_pixel(x,y,Color(0,0,0,(1-smoothstep(0.15,1.0,radius))*0.4))
	var shade=StandardMaterial3D.new(); shade.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	shade.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; shade.albedo_texture=ImageTexture.create_from_image(shadow_image)
	shadow.material_override=shade; view.add_child(shadow)
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
