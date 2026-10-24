# SPDX-License-Identifier: GPL-3.0-or-later
# Presentation seam only. TrainerOS owns identity, appearance and wardrobe.
extends Node3D
var visual: Node3D
var player_id := ""
const Stroke = preload("res://scripts/golf_stroke.gd")
var stroke: Node3D

func install_visual(sdk_visual: Node3D, id: String) -> void:
	if is_instance_valid(stroke):
		remove_child(stroke)
		stroke.queue_free()
	stroke=null
	if is_instance_valid(visual):
		remove_child(visual)
		visual.queue_free()
	visual = sdk_visual
	player_id = id
	if visual != null:
		add_child(visual)
		if visual is TrainerAvatarPresenter:
			stroke=Stroke.new()
			add_child(stroke)
			if not stroke.bind(visual): stroke.queue_free(); stroke=null

func play_action(action: String) -> void:
	if action=="golf_putt" and is_instance_valid(stroke):
		stroke.strike()
		return
	# The SDK presenter translates supported semantic actions to its own rig/clips.
	if is_instance_valid(visual) and visual.has_method("play_action"):
		visual.call("play_action",action)

func clear_identity() -> void:
	install_visual(null,"")

func seek_stroke(time: float) -> void:
	if is_instance_valid(stroke): stroke.seek(time)
