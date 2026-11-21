# SPDX-License-Identifier: GPL-3.0-or-later
# Presentation seam only. TrainerOS owns identity, appearance and wardrobe.
extends Node3D
var visual: Node3D
var player_id := ""
const Stroke = preload("res://scripts/golf_stroke.gd")
var stroke: Node3D
const Motion = preload("res://scripts/golfer_motion.gd")
var motion: Node
var ground: Callable
signal foot_landed(side: String)

func install_visual(sdk_visual: Node3D, id: String) -> void:
	if is_instance_valid(motion):
		motion.reset(); remove_child(motion); motion.queue_free()
	motion=null
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
			if stroke!=null:
				motion=Motion.new(); add_child(motion)
				if not motion.bind(stroke,visual): motion.queue_free(); motion=null
				else:
					motion.ground=ground
					motion.foot_landed.connect(func(side): foot_landed.emit(side))

func play_action(action: String) -> void:
	if action=="golf_putt" and is_instance_valid(stroke):
		if is_instance_valid(motion): motion.reset()
		stroke.strike()
		return
	# The SDK presenter translates supported semantic actions to its own rig/clips.
	if is_instance_valid(visual) and visual.has_method("play_action"):
		visual.call("play_action",action)

func clear_identity() -> void:
	install_visual(null,"")

func seek_stroke(time: float) -> void:
	if is_instance_valid(stroke): stroke.seek(time)

func step_turn(delta: float) -> void:
	if is_instance_valid(motion): motion.turn(delta)

func celebrate(time: float, variant: int) -> void:
	if is_instance_valid(motion): motion.celebrate(time,variant)

func reset_motion() -> void:
	if is_instance_valid(motion): motion.reset()
	if is_instance_valid(stroke): stroke.seek(-1)
