# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var ui
var failures := 0
var output := ""
func _initialize() -> void:
	output=OS.get_environment("GOLF_GROUP_CAPTURE"); call_deferred("run")
func check(ok: bool, what: String) -> void:
	if not ok: failures+=1; printerr("FAIL ",what)
func capture(name: String) -> void:
	if output.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
	root.size=Vector2i(960,540)
	ui=load("res://main.tscn").instantiate(); root.add_child(ui); await process_frame
	ui.set_process(false); ui.game.set_process(false)
	ui.popup_buttons.get_child(1).pressed.emit()
	check(ui.local_setup and ui.setup_count==2,"local match reachable from menu")
	ui._cycle_count(); ui._toggle_teams()
	check(ui._setup_roster()==[[0,1],[2,3]],"four can choose two teams")
	ui._cycle_count()
	check(ui._setup_roster()==[[0,1],[2,3,4]],"five defaults to asymmetric teams")
	ui._cycle_team(0)
	check(ui.setup_start_button.disabled,"invalid partial edit cannot start")
	ui._cycle_team(0); ui._start_configured(); ui.game.accept_turn()
	check(ui.game.world.players==2 and ui.game.participant_count==5,"five people share two balls")
	check(ui.hud.state.side_labels.size()==2,"HUD scores teams instead of duplicating member balls")
	ui._refresh(); ui._process(0); await process_frame; await capture("teams-two-v-three")
	ui.game.leave(); ui.local_setup=true; ui.setup_count=8; ui.setup_teams=true; ui._default_teams(); ui._refresh()
	for i in 8: ui.setup_assignment[i]=i/2
	ui._refresh(); await process_frame; await process_frame
	check(ui._setup_roster()==[[0,1],[2,3],[4,5],[6,7]],"eight can form four pairs")
	var rect: Rect2 = ui.popup.get_global_rect()
	check(rect.position.y>=0 and rect.end.y<=540,"eight-player setup fits 960x540")
	await capture("teams-eight-setup")
	ui._start_configured(); ui.game.accept_turn(); ui._refresh(); ui._process(0); await process_frame
	check(ui.balls.size()==4 and ui.hud.state.totals.size()==4,"four team balls and score rows")
	await capture("teams-four-pairs")
	ui.game.world.turn=3; ui.game.world.rotations[3]=1; ui._refresh()
	check(ui.game.world.actor()==7 and "P8" in ui.hud.state.side_labels[3],"current teammate shown")
	ui.game.leave(); ui.local_setup=false; ui._refresh(); ui.popup_buttons.get_child(0).pressed.emit()
	check(ui.game.solo_bot and ui.game.world.players==2,"solo starts rival match")
	ui.game.world.turn=1; ui.game.phase="aim"; ui._refresh()
	check(not ui.game.can_fire(),"human cannot control rival")
	ui.game.leave(); ui.audio.shutdown(); await create_timer(.25).timeout; ui.queue_free(); await process_frame
	print("TEAM UI ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
