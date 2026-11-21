# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
## Bake the north-up plan at 16:9; no player, HUD or NPC overlays.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var square = preload("res://scripts/square.gd").new()
	root.add_child(square)
	var camera := Camera3D.new()
	square.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 43.0
	camera.position = Vector3(0, 60, 0)
	camera.rotation.x = -PI / 2
	camera.make_current()
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	square.life.stop_sound()
	await create_timer(0.15).timeout
	quit(0 if result == OK else 1)
