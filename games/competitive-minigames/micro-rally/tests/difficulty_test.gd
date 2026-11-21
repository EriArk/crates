# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Settings=preload("res://scripts/bot_settings.gd")
const Store=preload("res://scripts/career_store.gd")
var failures=0
func check(ok: bool, label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func press(action: String) -> void:
	var event=InputEventAction.new(); event.action=action; event.pressed=true; root.push_input(event)
	event=event.duplicate(); event.pressed=false; root.push_input(event)
func stick(value: float) -> void:
	var event=InputEventJoypadMotion.new(); event.axis=JOY_AXIS_LEFT_X; event.axis_value=value; root.push_input(event)
func run() -> void:
	var game=load("res://main.tscn").instantiate(); root.add_child(game); await process_frame; await process_frame
	var store=game.cup.store; var directory="user://difficulty/"+str(Time.get_ticks_usec())
	store.load_profile("owner",directory)
	var easy=Settings.preset(0); var hard=Settings.preset(2)
	check(store.set_bot_settings("quick",easy) and store.set_bot_settings("cup",hard),"Independent presets persist")
	var custom=hard.duplicate(true); custom.style="tactical"; custom.pace=1
	check(Settings.title(custom)=="Custom" and Settings.key(custom)!=Settings.key(hard),"Custom settings have distinct identity")
	for bad in [{}, {"version":99}, {"pace":NAN}]: check(not store.set_bot_settings("quick",bad),"Malformed bot settings rejected")
	var invalid=hard.duplicate(); invalid.accuracy=INF; check(not Settings.valid(invalid),"Nonfinite difficulty rejected")
	invalid=hard.duplicate(); invalid.pace=0.5; check(not Settings.valid(invalid),"Fractional difficulty rejected")
	store.fault="write"; check(not store.set_bot_settings("quick",hard) and store.bot_settings("quick")==easy,"Failed save cannot change selected difficulty")
	store.fault=""
	check(store.set_bot_count(7),"Opponent count persists")
	store.load_profile("owner",directory); game.bot_count=store.quick_bot_count()
	check(store.bot_settings("quick")==easy and store.bot_settings("cup")==hard and game.bot_count==7,"Restart restores separate preferences and count")
	game.hud.BotMenu.open(game.hud,"quick"); await process_frame; await process_frame
	check(game.hud.panel.size.y<=650 and game.hud.panel.position.x+game.hud.panel.size.x<=1280,"Editable bot screen fits canvas")
	# Controller right/left on the focused preset uses the same persistence path as touch.
	press("ui_right"); await process_frame
	check(store.bot_settings("quick")==Settings.preset(),"Controller Right advances preset")
	press("ui_left"); await process_frame
	check(store.bot_settings("quick")==easy,"Controller Left reverses preset")
	stick(0.8); await process_frame; stick(0.9); await process_frame
	check(store.bot_settings("quick")==Settings.preset(),"Stick jitter while held cannot cycle/save options repeatedly")
	stick(0.0); await process_frame; stick(-0.8); await process_frame; stick(0.0)
	check(store.bot_settings("quick")==easy,"Releasing and tilting stick restores one step per gesture")
	game.hud.buttons[2].pressed.emit(); await process_frame
	check(store.bot_settings("quick").pace==1 and store.bot_settings("quick").reaction==0,"Direct button activation adjusts only its named axis")
	game.hud.back(); check(game.hud.menu_mode=="quick","Back returns to original setup screen")
	store.set_bot_settings("quick",custom); game.start_race()
	check(game.cars.size()==8 and game.cars.all(func(c): return c.bot.settings==custom),"Quick settings reach every actual driver")
	check(game.cars[1].driver_title().begins_with("Tactician"),"Selected character changes driver identity")
	game.hud.BotMenu.change(game.hud,"preset"); check(store.bot_settings("quick")==custom,"No in-race edit through menu handler")
	game.elapsed=90; game._save_best(); var custom_key=game.record_section()
	game.return_menu(); store.set_bot_settings("quick",easy); game.start_race(); game.elapsed=100; game._save_best()
	var records=ConfigFile.new(); records.load("user://valley.cfg")
	check(custom_key!=game.record_section() and records.get_value(custom_key,"best_seconds")==90 and records.get_value(game.record_section(),"best_seconds")==100,"Records cannot mix custom and easy opponents")
	game.return_menu(); game.cup.start_stage(); var id=store.data.active.id
	check(game.race_bots==hard and game.cars.size()==16,"Cup fixes selected difficulty and full roster")
	store.set_bot_settings("cup",easy); game.cup.leave_stage(); game.hud.BotMenu.open(game.hud,"cup")
	game.hud.BotMenu.change(game.hud,"preset"); check(store.active_bots()==hard and store.bot_settings("cup")==easy,"Active cup settings stay locked independently of next cup")
	await process_frame; check(game.hud.panel.size.y<=650,"Locked cup settings fit canvas")
	store.load_profile("owner",directory); game.cup.start_stage()
	check(game.race_bots==hard and store.data.active.id==id,"Restart resumes frozen difficulty")
	for car in game.cars: car.finish_time=240+car.index; car.passed=1600
	game.finish_race(); game.cup.leave_stage(); game.cup.start_stage()
	check(game.current_track==game.Tracks.QUARRY and game.race_bots==hard and game.cars.all(func(c): return c.bot.settings==hard),"Next stage uses the same frozen difficulty")
	game.cup.leave_stage(); check(game.bot_count==7,"Cup exit restores quick-race opponent count")
	game.hud.menu("cup_replace"); game.hud.BotMenu.open(game.hud,"cup_replace"); game.hud.BotMenu.change(game.hud,"preset")
	check(store.active_bots()==hard and store.bot_settings("cup")==Settings.preset(),"New-cup setup cannot mutate retained standings")
	game.cup.begin_new(); check(store.active_bots()==Settings.preset() and store.data.active.id!=id,"Replacement cup adopts new selection")
	# Legacy save with genuine schema-1 fields, no settings, remains readable.
	var legacy=Store.fresh(); legacy.active=store.data.active.duplicate(true); legacy.active.erase("bots")
	check(store.commit(legacy),"Legacy payload fixture saved")
	store.load_profile("owner",directory)
	check(store.writable and store.active_bots()==Settings.preset() and store.bot_settings("quick")==Settings.preset(),"Legacy career resumes ordinary AI without losing progress")
	var future=store.data.duplicate(true); future.bot_preferences={"quick":Settings.preset(),"cup":Settings.preset()}; future.bot_preferences.quick.version=2
	var payload=JSON.stringify(future); var path=store.base_path+"."+str((store.generation+1)%2)+".json"
	var file=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify({"schema":1,"generation":store.generation+1,"payload":payload,"sha256":payload.sha256_text()})); file.close()
	store.load_profile("owner",directory)
	check(not store.writable and not store.set_bot_settings("quick",easy),"Future bot schema is protected instead of downgraded to an older journal entry")
	await preload("audio_drain.gd").dispose(game,self)
	print("DIFFICULTY JOURNEY failures=",failures); quit(1 if failures else 0)
