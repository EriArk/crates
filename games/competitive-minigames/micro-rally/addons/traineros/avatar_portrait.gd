# SPDX-License-Identifier: GPL-3.0-or-later
class_name TrainerAvatarPortrait
extends Node
## One short-lived offscreen scene produces a static head-and-shoulders texture.
## No avatar assets or private paths are sent to another player.
const Presenter = preload("avatar_presenter.gd")

static func capture(owner: Node, descriptor: Dictionary) -> Texture2D:
	if DisplayServer.get_name()=="headless": return null
	var model = Presenter.from_descriptor(descriptor)
	if model==null: return null
	var viewport := SubViewport.new()
	viewport.size=Vector2i(256,256)
	viewport.transparent_bg=true
	viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	owner.add_child(viewport)
	viewport.add_child(model)
	var camera := Camera3D.new()
	camera.position=Vector3(0,0.81,1.2)
	camera.fov=28
	camera.near=0.01
	camera.far=10
	viewport.add_child(camera)
	var environment := WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(0,0,0,0)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("aaaaaa")
	environment.environment.ambient_light_energy=0.65
	environment.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	viewport.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees=Vector3(-25,-25,0)
	key.light_energy=1.4
	viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(-15,150,0)
	fill.light_energy=0.7
	viewport.add_child(fill)
	await owner.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var texture := ImageTexture.create_from_image(viewport.get_texture().get_image())
	viewport.queue_free()
	return texture
