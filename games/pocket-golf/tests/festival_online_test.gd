# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var scene
var last_ply := -1

func _initialize() -> void:
	call_deferred("start")

func start() -> void:
	scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.game.shot_started.connect(func(_shot):scene.game.call_deferred("finish_shot"))

func _process(_delta: float) -> bool:
	if scene and scene.online_cup and scene.game.can_fire() and scene.game.world.ply!=last_ply:
		last_ply=scene.game.world.ply
		scene.game.fire()
	return false
