# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var ui
var failures := 0
func check(ok: bool, what: String) -> void:
	if not ok: failures+=1; printerr("FAIL ",what)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	ui=load("res://main.tscn").instantiate(); root.add_child(ui)
	ui.game.local(2,[],true); ui.game.accept_turn(); ui.paused=true
	var deadline := Time.get_ticks_msec()+30000
	while not ui.avatar_roster.descriptions.has("bot") and Time.get_ticks_msec()<deadline: await process_frame
	check(ui.avatar_roster.descriptions.has("bot"),"SDK resolved stock rival")
	if failures==0:
		var first: Dictionary = ui.avatar_roster.descriptions.bot.duplicate(true)
		var own: Dictionary = ui.avatar_roster.local_recipe.duplicate(true)
		ui.game.world.turn=1; ui._refresh()
		check(ui.anchor.player_id=="session-peer:bot","rival owns anonymous identity")
		check(ui.anchor.motion!=null and ui.anchor.stroke!=null,"stock uses shared rig and golf reactions")
		check(ui.anchor.visual.find_children("*","MeshInstance3D",true,false).size()==4,"body outfit hair shoes assembled")
		ui.game.world.complete=true; ui.game.phase="result"; ui.game.rematch()
		deadline=Time.get_ticks_msec()+30000
		while not ui.avatar_roster.descriptions.has("bot") and Time.get_ticks_msec()<deadline: await process_frame
		check(ui.avatar_roster.descriptions.has("bot"),"new round resolves rival")
		if ui.avatar_roster.descriptions.has("bot"):
			check(ui.avatar_roster.descriptions.bot.sha256!=first.sha256,"different stock appearance each round")
		check(ui.avatar_roster.local_recipe==own,"rival never changes owner appearance")
		ui.game.world.turn=1; ui.game.phase="aim"; ui.paused=false; ui._refresh()
		var before: int = ui.game.world.ply
		ui.paused=true; ui._process(2); check(ui.game.world.ply==before,"paused bot cannot strike")
	ui.audio.shutdown(); ui.game.leave(); await create_timer(.25).timeout
	ui.queue_free(); await process_frame
	print("STOCK RIVAL ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
