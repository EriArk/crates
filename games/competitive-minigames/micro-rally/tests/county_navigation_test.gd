# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var started=Time.get_ticks_msec()
	var track=preload("res://scripts/deadwater_track.gd").new(); root.add_child(track); track.build()
	var loaded=track.loaded_navigation; var first=track.navigation_snapshot()
	var load_ms=Time.get_ticks_msec()-started
	track.graph.clear(); track.nav_cells.clear(); track.bridge_nodes.clear()
	started=Time.get_ticks_msec(); track._compute_navigation()
	var computed=track.navigation_snapshot(); var rebuild_ms=Time.get_ticks_msec()-started
	var failures=0
	var baking=Array(OS.get_cmdline_user_args()).any(func(arg):return arg.begins_with("--navigation-output="))
	if not loaded and not baking: failures+=1; push_error("Ordinary build must load current baked navigation")
	if JSON.stringify(first)!=JSON.stringify(computed): failures+=1; push_error("Baked graph differs from terrain/building navigation")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--navigation-output="):
			var file=FileAccess.open(arg.trim_prefix("--navigation-output="),FileAccess.WRITE); file.store_string(JSON.stringify(computed)+"\n"); file.close()
	print("COUNTY NAV failures=",failures," loaded=",loaded," points=",track.graph.get_point_count()," build_ms=",load_ms," recompute_ms=",rebuild_ms)
	track.queue_free(); await process_frame; quit(1 if failures else 0)
