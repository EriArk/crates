# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures=0
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func press() -> void:
	var event=InputEventJoypadButton.new(); event.button_index=JOY_BUTTON_A; event.pressed=true; root.push_input(event)
	event=event.duplicate(); event.pressed=false; root.push_input(event)
func run() -> void:
	var game=load("res://main.tscn").instantiate(); root.add_child(game); await process_frame; await process_frame
	var directory="user://cup-journey/"+str(Time.get_ticks_usec())
	game.cup.store.load_profile("journey",directory)
	press(); await process_frame
	check(game.hud.menu_mode=="cups","Primary controller action opens cup catalogue")
	press(); await process_frame
	check(game.hud.menu_mode=="cup","Selected cup opens its stages")
	press(); await process_frame
	check(game.state=="countdown" and game.laps==5 and game.cup.running,"Cup starts real five-lap stage with fixed rules")
	var id=game.cup.store.data.active.id; var roster=game.cup.store.data.active.roster.duplicate()
	game.cup.leave_stage(); game.cup.start_stage()
	check(game.cup.store.data.active.id==id and game.cup.store.data.active.roster==roster,"Interrupted stage restarts with same cup and roster")
	for car in game.cars: car.finish_time=270+car.index; car.passed=1600
	game.cup.store.fault="write"; game.finish_race()
	check(not game.cup.pending_result.is_empty() and game.cup.store.data.active.results.is_empty(),"Failed finish save retains result for retry")
	game.cup.store.fault=""; game.cup.retry_save()
	check(game.cup.pending_result.is_empty() and game.cup.store.data.active.results.size()==1,"Retry commits exactly one result")
	game.finish_race(); check(game.cup.store.data.active.results.size()==1 and game.cup.pending_result.is_empty(),"Repeated finish callback is harmless")
	game.cup.leave_stage(); game.cup.start_stage()
	check(game.state=="countdown" and game.cup.running and game.current_track==game.Tracks.QUARRY and game.laps==6,"Saved Valley result opens the actual Quarry with six laps")
	check(game.cup.store.data.active.id==id and game.cup.store.data.active.roster==roster,"Track transition retains cup identity and roster")
	game.cup.leave_stage()
	game.cup.store.load_profile("journey",directory); game.cup.start_stage()
	check(game.current_track==game.Tracks.QUARRY and game.cup.stage==1 and game.cup.store.data.active.id==id and game.cup.store.data.active.roster==roster,"Interrupted Quarry resumes from persisted Valley score and exact roster")
	game.cup.leave_stage()
	await process_frame
	check(game.hud.panel.size.y<=650,"Cup with continue, standings and new-run actions fits handheld canvas")
	check(game.cup.store.data.wins==0,"Partial cup cannot grant prize")
	var second: Array=[]
	for i in 16: second.append({"slot":i,"ms":420000+i*1000,"progress":1920})
	check(game.cup.store.finish(1,second),"Existing two-stage save can continue without a new cup")
	game.cup.store.load_profile("journey",directory); game.cup.start_stage()
	check(game.current_track==game.Tracks.PASS and game.laps==5 and game.cup.stage==2 and game.conditions.time_of_day=="dawn" and game.conditions.weather=="rain","Third stage enters mountain pass with cup conditions")
	check(game.cup.store.data.active.id==id and game.cup.store.data.active.roster==roster and game.cup.store.data.active.results.size()==2,"Pass retains existing identity, roster and both results")
	game.cup.leave_stage()

	game.hud.menu("standings"); await process_frame
	check(game.hud.panel.size.y<=650,"Sixteen-driver standings fits handheld canvas")
	game.hud.back(); check(game.hud.menu_mode=="cup","Controller Back returns from table to cup")
	game.hud.menu("quick"); game.hud.menu("controls"); game.hud.back()
	check(game.hud.menu_mode=="quick","Controls returns to the entry route")
	game.cup.open_garage(); game.cup.browse_car(3); await process_frame
	game.cup.select_car(); check(game.cup.store.data.selected=="swift","Locked prize remains preview-only")
	check(game.hud.panel.size.y<=650,"Garage fits handheld canvas")
	game.start_race(); game.cup._profile("different")
	check(game.state=="countdown","Late SDK identity does not interrupt a quick race")
	check(game.cup.store.data.active.is_empty(),"SDK profile change isolates active cup")
	game.cup._revoked(); check(not game.cup.store.writable,"Revoked profile cannot receive rewards")
	await preload("audio_drain.gd").dispose(game,self)
	print("CUP JOURNEY TEST failures=",failures); quit(1 if failures else 0)
