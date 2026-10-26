# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
static func dispose(game: Node, tree: SceneTree) -> void:
	game.queue_free(); await tree.process_frame
	# Fixed-FPS simulation outruns the real-time Dummy audio thread. Stopped
	# voices finish their mixer fades before its deferred resources are collected.
	OS.delay_msec(180); await tree.process_frame
