# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var ui
var output := ""
var failed := false
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): output=arg.trim_prefix("--capture=")
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failed=true; printerr("FAIL: "+message)
func send(event: InputEvent) -> void:
	Input.parse_input_event(event); Input.flush_buffered_events()
func touch(id: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new(); event.index=id; event.position=point; event.pressed=pressed; send(event)
func drag(id: int, point: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new(); event.index=id; event.position=point; event.relative=relative; send(event)
func tap(action: String) -> void:
	var point: Vector2 = ui.hud.screen_point(ui.hud.regions()[action].get_center())
	touch(0,point,true); touch(0,point,false)
func key(code: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode=code; event.pressed=pressed; send(event)
func picture(name: String) -> void:
	await create_timer(0.4).timeout
	if output.is_empty(): return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"capture "+name)
func run() -> void:
	root.size=Vector2i(960,540)
	ui=load("res://main.tscn").instantiate(); root.add_child(ui)
	await process_frame
	ui._start_local(2); ui.game.accept_turn(); ui.neutral_required=false
	var digest: String = ui.game.world.digest()
	var yaw: float = ui.camera.yaw[0]
	ui._set_input("touch")
	var point: Vector2 = ui.hud.screen_point(Vector2(26+210*0.6,ui.hud.layout_size().y-67))
	touch(0,point,true)
	check(ui.game.power==60,"touch selects power through Match")
	var after: Vector2 = ui.hud.screen_point(Vector2(26+210*0.9,ui.hud.layout_size().y-67))
	drag(0,after,after-point); touch(0,after,false)
	check(ui.game.power==90 and ui.game.angle==0,"slider only changes power")
	check(ui.camera.yaw[0]==yaw and ui.touches.is_empty(),"power gesture never orbits camera")
	point=ui.hud.screen_point(ui.hud.regions().aim.get_center())
	touch(0,point,true); drag(0,point+Vector2(40,0),Vector2(40,0)); touch(0,point+Vector2(40,0),false)
	check(ui.game.angle==20 and ui.game.power==90,"drag aim keeps five-degree rules")
	check(ui.camera.yaw[0]==yaw and ui.touches.is_empty(),"aim gesture never orbits camera")
	# A second finger on the field remains a camera gesture, independent of the dial.
	touch(0,point,true); touch(1,Vector2(400,250),true)
	drag(1,Vector2(420,250),Vector2(20,0))
	check(ui.camera.yaw[0]>yaw,"field gesture still orbits with a finger on HUD")
	touch(0,point,false); touch(1,Vector2(420,250),false)
	tap("view"); check(ui.camera.view==1,"touch camera cycles once")
	# Touch-generated mouse events must not activate the same icon again.
	for pressed in [true,false]:
		var mouse := InputEventMouseButton.new(); mouse.device=InputEvent.DEVICE_ID_EMULATION
		mouse.position=ui.hud.screen_point(ui.hud.regions().view.get_center()); mouse.button_index=MOUSE_BUTTON_LEFT; mouse.pressed=pressed; send(mouse)
	check(ui.camera.view==1,"emulated mouse cannot double-cycle view")
	tap("view"); check(ui.camera.view==2,"touch camera reaches eyes")
	await picture("hud-eyes-touch")
	tap("pause"); check(ui.paused and not ui.hud.visible,"pause hides gameplay HUD and cancels gestures")
	await picture("hud-pause")
	ui.popup_buttons.get_child(0).pressed.emit()
	check(not ui.paused,"touch resume works")
	# A modality change cancels a held dial so its eventual drag/release is harmless.
	point=ui.hud.screen_point(ui.hud.regions().aim.get_center()); touch(0,point,true)
	key(KEY_TAB); var angle: int = ui.game.angle
	drag(0,point+Vector2(80,0),Vector2(80,0)); touch(0,point+Vector2(80,0),false)
	check(ui.hud.captures.is_empty() and ui.game.angle==angle,"keyboard cancels stale touch capture")
	check(ui.hud.state.mode=="keyboard" and not ui.hud.regions().has("aim"),"hardware input hides touch dial")
	check(ui.game.world.digest()==digest,"HUD adjustment and cameras leave simulation unchanged")
	ui.camera.view=0; ui.camera.reset_view(); ui._refresh()
	await picture("hud-keyboard")
	ui._set_input("pad"); await picture("hud-controller")
	root.size=Vector2i(1920,1080); await picture("hud-overview")
	root.size=Vector2i(960,540); await process_frame
	ui.game.online=true; ui.game.seat=1; ui._refresh()
	check(not ui.hud.state.can_shoot and not ui.hud.regions().has("power"),"remote turn has no local shot controls")
	await picture("hud-waiting")
	ui.game.online=false; ui._set_input("touch"); ui._refresh()
	root.size=Vector2i(640,440); await process_frame
	for region in ui.hud.regions().values():
		check(Rect2(Vector2.ZERO,ui.hud.layout_size()).encloses(region),"HUD hit targets fit small layout")
	await picture("hud-small-touch")
	point=ui.hud.screen_point(Vector2(26+210*0.5,ui.hud.layout_size().y-67))
	touch(0,point,true); touch(0,point,false)
	check(ui.game.power==50,"scaled touch slider retains correct mapping")
	point=ui.hud.screen_point(ui.hud.regions().putt.get_center())
	touch(0,point,true); drag(0,Vector2(300,200),Vector2(-100,-100)); touch(0,Vector2(300,200),false)
	check(ui.game.phase=="aim","dragging off PUTT cancels the touch action")
	tap("putt"); check(ui.game.phase=="moving","touch putt uses ordinary shot action")
	check(not ui.hud.regions().has("putt") and ui.hud.captures.is_empty(),"shot clears touch controls and held fingers")
	check(ui.hud.state.totals[0]==1,"running round total includes current stroke")
	await picture("hud-rolling")
	ui._suspend_input(); check(ui.hud.captures.is_empty(),"focus loss clears HUD pointer ownership")
	print("HUD ","FAIL" if failed else "PASS"," touch aim/power/putt, multi-touch ownership, emulated mouse, mode changes, remote turn, totals, small layout, pause")
	quit(1 if failed else 0)
