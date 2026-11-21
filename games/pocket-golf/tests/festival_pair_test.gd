# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var ui=load("res://main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	if ui.festival_receipt.is_empty() or ui.game.phase!="handoff":
		printerr("Expected a festival pair at the first tee")
		quit(1)
		return
	for shot_index in 90:
		ui.game.accept_turn()
		ui.game.fire()
		ui.game.finish_shot()
		if ui.game.phase=="result":break
	if not ui.game.world.complete or ui.game.world.scores[0].size()!=3 or ui.game.world.scores[1].size()!=3:
		printerr("Both players must finish three holes")
		quit(1)
		return
	ui._refresh()
	if ui.popup_buttons.get_child_count()!=1 or ui.popup_buttons.get_child(0).text!="Return to the arena":
		printerr("Tournament exit missing")
		quit(1)
		return
	print("FESTIVAL pair complete: ",ui.game.world.scores)
	ui.popup_buttons.get_child(0).pressed.emit()
