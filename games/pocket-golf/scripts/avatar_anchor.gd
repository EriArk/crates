# SPDX-License-Identifier: GPL-3.0-or-later
# Presentation seam only. TrainerOS owns identity, appearance and wardrobe.
extends Node3D
var visual: Node3D
var player_id := ""

func install_visual(sdk_visual: Node3D, id: String) -> void:
	if is_instance_valid(visual):
		remove_child(visual)
		visual.queue_free()
	visual = sdk_visual
	player_id = id
	if visual != null: add_child(visual)

func play_action(action: String) -> void:
	# A future SDK presenter translates semantic game actions to its own rig/clips.
	if is_instance_valid(visual) and visual.has_method("play_action"):
		visual.call("play_action",action)

func clear_identity() -> void:
	install_visual(null,"")
