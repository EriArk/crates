# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var ui
var failures := 0
var output := ""
func _initialize() -> void:
	output=OS.get_environment("GOLF_SCORE_CAPTURE"); call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failures+=1; printerr("FAIL ",label)
func capture(name: String) -> void:
	await process_frame; await process_frame
	var rectangle: Rect2 = ui.popup.get_global_rect()
	check(rectangle.position.y>=0 and rectangle.end.y<=540,"modal fits 960 x 540: "+name)
	if not output.is_empty() and DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
	root.size=Vector2i(960,540)
	ui=load("res://main.tscn").instantiate(); root.add_child(ui)
	await create_timer(.2).timeout; ui.set_process(false); ui.game.set_process(false)
	await capture("menu")
	ui.boards_open=true; ui.board_mode="teams"; ui._refresh()
	ui.game.scorecards.board={"items":[],"offset":0,"next_offset":5,"revision":"2","profiles":{
		"11111111-a":{"display_name":"Sakura"},"22222222-b":{"display_name":"Alexandra Longname"},"33333333-c":{"display_name":"River"}}}
	for i in 5:
		ui.game.scorecards.board.items.append({"place":i+1,"value":7+i,"members":["11111111-a","22222222-b","33333333-c"]})
	var portraits := OS.has_environment("GOLF_TEST_BOARD_PORTRAITS")
	if portraits:
		for i in 100:
			if not ui.avatar_roster.local_recipe.is_empty(): break
			await create_timer(.1).timeout
		check(not ui.avatar_roster.local_recipe.is_empty(),"SDK supplied avatar recipe")
		var count := 0
		for profile in ui.game.scorecards.board.profiles.values():
			profile.avatar=ui.avatar_roster.local_recipe.duplicate(true)
			profile.avatar.appearance.hair=["bob","crop","ponytail"][count]; count+=1
	ui.game.scorecards.board_message="Confirmed by every participant"; ui._refresh()
	if portraits:
		for i in 150:
			if ui.board_profiles.textures.size()==3: break
			await create_timer(.1).timeout
		check(ui.board_profiles.textures.size()==3 and ui.board_profiles.textures.values().all(func(t):return t!=null),"three SDK portraits rendered")
	check(ui.board_rows.get_child_count()==5,"five visible teams")
	check(ui.board_rows.get_child(0).get_child(1).get_child(1).text=="Sakura","server display name replaces UUID")
	check(ui._popup_controls().size()==5,"controller skips unavailable Previous")
	ui._direction(0,1); check(ui.get_viewport().gui_get_focus_owner()!=null,"table controller focus")
	await capture("shared-teams")
	ui._pause(); check(not ui.boards_open,"back closes table")
	ui.game.local(8,[[0,1],[2,3],[4,5],[6,7]])
	ui.game.world.scores=[[2,3,4],[3,4,5],[4,5,6],[5,6,7]]; ui.game.world.complete=true
	ui.game.phase="result"; ui.game.scorecards.message="Confirmed by all players · added to shared tables"; ui._refresh()
	await capture("shared-result")
	ui.game.scorecards.busy=true; ui._refresh()
	check(ui.popup_buttons.get_child(0).disabled,"rematch cannot overtake result request")
	ui.game.scorecards.busy=false; ui.game.voted=true; ui._refresh()
	check(ui.popup_buttons.get_child(1).disabled,"waiting rematch cannot start an unrelated table request")
	ui.game.voted=false; ui.game.scorecards.poll_at=Time.get_ticks_msec()+5000
	ui.game.rematch(); check(ui.game.scorecards.poll_at==0,"accepted rematch stops old-result polling")
	ui.game.info="Connecting shared results…"; ui.game.leave()
	check(ui.game.info=="A little green. A good time.","leaving clears stale connection text")
	ui.audio.shutdown(); await create_timer(.2).timeout
	ui.queue_free(); await process_frame
	print("SCORECARD UI ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(0 if failures==0 else 1)
