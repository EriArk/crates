# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Catalog = preload("res://scripts/event_catalog.gd")
var failures=0
var confirmed=0
func check(ok: bool, description: String) -> void:
	if not ok: failures+=1; push_error(description)
func _initialize() -> void: call_deferred("run")
func press(action: String) -> void:
	var event=InputEventAction.new(); event.action=action; event.pressed=true; root.push_input(event)
	event=event.duplicate(); event.pressed=false; root.push_input(event)
func fit(hud, name: String) -> void:
	var area=Rect2(0,0,1280,676)
	check(area.encloses(hud.panel.get_global_rect()),name+" panel fits 720p above input hints")
	for node in hud.panel.find_children("*","Control",true,false):
		if not node.is_visible_in_tree() or node is SubViewportContainer: continue
		check(area.encloses(node.get_global_rect()),name+" control fits: "+node.name)
func run() -> void:
	root.size=Vector2i(1280,720)
	var game=load("res://main.tscn").instantiate(); root.add_child(game)
	await process_frame; await process_frame
	game.net.platform_enabled=false; game.net.set_process(false); game.net.bridge.set_process(false)
	game.cup.store.load_profile("menu","user://menu-test/"+str(Time.get_ticks_usec()))
	var hud=game.hud; hud.focus_memory.clear(); hud.menu("main")
	press("ui_accept"); await process_frame
	check(hud.menu_mode=="cups","Main controller action opens catalogue")
	press("ui_accept"); await process_frame
	check(hud.menu_mode=="cup","Default catalogue focus opens selected cup, not filter")
	press("ui_cancel"); await process_frame
	check(hud.menu_mode=="cups" and root.gui_get_focus_owner().text.begins_with("WOODLAND"),"Back restores cup-card focus")
	check(Catalog.MODES.size()==3 and Catalog.MODES.map(func(m): return m.id)==["race","arena","royale"],"Only the three accepted modes exist")
	var fixtures: Array=[]
	for i in 13: fixtures.append({"id":str(i),"category":"race" if i<10 else "mixed"})
	check(Catalog.cups(0,fixtures).size()==13 and Catalog.cups(1,fixtures).size()==10 and Catalog.cups(4,fixtures).size()==3,"Catalogue filters arbitrary cup counts and mixed series")
	check(not Catalog.can_start("unknown"),"Unknown cup cannot launch first cup by accident")
	var catalogue: Array=[]
	for i in 13:
		var entry=Catalog.CUPS[0].duplicate(true); entry.id="preview-"+str(i); entry.title="Test cup "+str(i); catalogue.append(entry)
	hud.cup_entries=catalogue; hud.menu("cups"); await process_frame; await process_frame; fit(hud,"13-cup catalogue first page")
	hud.buttons[-2].pressed.emit(); await process_frame; await process_frame
	check(hud.cup_page==1,"Next page browses additional cup descriptors")
	fit(hud,"13-cup catalogue second page")
	hud.cup_page=3; hud.menu("cups"); await process_frame; await process_frame; fit(hud,"13-cup catalogue last page")
	check(hud.buttons.size()==9,"Last page contains one card, filters, paging and Back")
	hud.cup_entries=Catalog.CUPS; hud.cup_page=0
	hud.menu("modes"); await process_frame
	check(hud.buttons[1].disabled and hud.buttons[2].disabled,"Unimplemented arena and royale cannot start racing")
	press("ui_down"); await process_frame
	check(hud.buttons[-1].has_focus(),"Controller skips unavailable modes")
	hud.menu("main"); hud.menu("settings"); hud.menu("audio"); await process_frame
	var slider=root.gui_get_focus_owner()
	check(slider is HSlider,"Audio starts with a focused native slider")
	var before=game.sound.music_volume
	press("ui_left"); await process_frame
	check(is_equal_approx(game.sound.music_volume,maxf(0,before-0.05)),"Controller changes music by five percent")
	slider.value=35; await process_frame
	check(is_equal_approx(game.sound.music_volume,0.35),"Pointer/native slider uses same volume path")
	var config=ConfigFile.new(); check(config.load("user://audio.cfg")==OK and is_equal_approx(config.get_value("mix","music"),0.35),"Slider settings persist to disk")
	press("ui_cancel"); await process_frame
	check(hud.menu_mode=="settings","Audio cancel returns to settings")
	hud.menu("controls"); hud.menu("bindings"); hud.back(); hud.back()
	check(hud.menu_mode=="settings","Control diagram returns through controls to settings without loop")
	hud.back(); check(hud.menu_mode=="main","Settings returns to its entry point")
	hud.menu("cup_replace"); hud.buttons[-1].grab_focus(); hud.back(); hud.menu("cup_replace")
	check(hud.buttons[0].has_focus(),"Reopening cup replacement always focuses preserving current progress")
	for mode in ["main","cups","cup","modes","settings","audio","quick","conditions","controls","bindings","garage","bots","credits","standings","results"]:
		hud.menu(mode); await process_frame; await process_frame; fit(hud,mode)
	hud.cup_filter=2; hud.menu("cups"); await process_frame; fit(hud,"empty catalogue")
	check(hud.buttons.size()==6,"Empty category exposes filters and Back, no fake start")
	hud.cup_filter=0
	hud.menu("main"); hud.buttons[-1].grab_focus()
	hud.confirm("CONFIRM","Please confirm this action.","Confirm",func(): confirmed+=1)
	await process_frame; fit(hud,"confirmation")
	check(hud.buttons[0].has_focus(),"Confirmation always defaults to Cancel")
	press("ui_accept"); await process_frame
	check(confirmed==0 and hud.menu_mode=="main" and hud.buttons[-1].has_focus(),"Accepting Cancel preserves state and restores trigger focus")
	hud.confirm("CONFIRM","Confirm this action.","Confirm",func(): confirmed+=1)
	hud.buttons[-1].pressed.emit(); check(confirmed==1,"Deliberate confirmation executes once")
	hud.execute_confirm(); check(confirmed==1,"Repeated confirmation cannot execute twice")
	game.start_race(); game.state="pause"; paused=true; hud.menu("pause")
	hud.menu("settings"); hud.menu("audio"); press("ui_cancel"); await process_frame
	check(game.state=="pause" and paused and hud.menu_mode=="settings","Cancel from pause audio does not resume race")
	press("ui_cancel"); await process_frame
	check(hud.menu_mode=="pause" and paused,"Settings returns to paused race")
	hud.buttons[3].pressed.emit(); await process_frame
	check(hud.menu_mode=="confirm" and paused,"Restart asks before discarding current run")
	press("ui_cancel"); await process_frame
	check(hud.menu_mode=="pause" and paused,"Cancelling restart keeps race paused")
	game.return_menu()
	# Inspect the actual SDK client queue, without claiming an authenticated host test.
	game.net.bridge.registered=true; game.net.bridge.active=true; game.net.bridge.outgoing.clear(); game.net.bridge.pending.clear()
	hud.menu("main")
	for button in hud.buttons:
		if button.text=="LOBBY": button.pressed.emit(); break
	var wire=game.net.bridge.outgoing.get_string_from_utf8()
	check(wire.contains('"method":"activity.open"') and not game.net.online,"Lobby action uses existing SDK activity route")
	game.net.bridge.active=false; game.net.bridge.registered=false; game.net.bridge.outgoing.clear(); game.net.bridge.pending.clear()
	hud.open_lobby(); check(hud.menu_mode=="lobby","Standalone launch explains existing lobby entry")
	await preload("audio_drain.gd").dispose(game,self)
	print("MENU TEST failures=",failures); quit(1 if failures else 0)
