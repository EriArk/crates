# SPDX-License-Identifier: GPL-3.0-or-later
extends Control
const Portrait = preload("portrait.gd")
const Car = preload("car.gd")
const BotMenu = preload("bot_menu.gd")
var bots_parent = "quick"
var bot_notice = ""
var bot_axis_direction = 0
const CupMenu = preload("cup_menu.gd")
const MenuSkin = preload("menu_skin.gd")
const FrontMenu = preload("front_menu.gd")
var focus_controls: Array[Control] = []
var focus_memory: Dictionary = {}
var settings_parent = "main"
var confirm_parent = "main"
var confirm_title = ""
var confirm_body = ""
var confirm_action_title = ""
var confirm_action: Callable
var audio_status: Label
var cup_filter = 0
var cup_page = 0
var selected_cup = "forest-challenge"
var cup_entries: Array = FrontMenu.Catalog.CUPS
var game: Node3D
var portrait: TextureRect
var font: Font
var panel: PanelContainer
var message = ""
var buttons: Array[Button] = []
var fps_label = ""
var menu_mode = ""
var controls_parent = "main"
var audio_parent = "main"
var audio_notice = ""
var gearbox_notice = ""
var displayed_speed = 0.0
var speed_reset = -1
var shift_touch: Array[Button] = []
const INK = Color(0.025,0.045,0.045,0.86)
const PAPER = Color("fff6d8")
const GOLD = Color("ffcc42")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE; font=ThemeDB.fallback_font
	portrait=Portrait.new(); portrait.shared_sdk=game.net.bridge; portrait.game=game; add_child(portrait)
	panel=PanelContainer.new(); add_child(panel)
	for direction in [-1,1]:
		var b=Button.new(); b.text="−" if direction<0 else "+"
		b.add_theme_font_size_override("font_size",26); b.focus_mode=Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal",_plate()); b.size=Vector2(94,44)
		b.pressed.connect(func():
			if game.state=="race" and not game.net.overlay and not game.controls.neutral_required: game.player().request_shift(direction))
		add_child(b); shift_touch.append(b)
	menu("main")

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion and event.axis==JOY_AXIS_LEFT_X and absf(event.axis_value)<0.3:
		bot_axis_direction=0

func label(text: String, size_value: int, color: Color = PAPER) -> Label:
	var l = Label.new(); l.text=text; l.add_theme_font_size_override("font_size",size_value); l.add_theme_color_override("font_color",color)
	if size_value>=28: l.add_theme_font_override("font",MenuSkin.title_font())
	return l

func button(parent: Node, text: String, action: Callable) -> Button:
	var b = Button.new(); b.text=text; b.custom_minimum_size=Vector2(330,46); b.add_theme_font_size_override("font_size",22)
	MenuSkin.style_button(b)
	b.pressed.connect(func(): game.sound.play_event("ui"); action.call())
	parent.add_child(b); buttons.append(b); focus_controls.append(b)
	return b

func menu(mode: String) -> void:
	if not menu_mode.is_empty():
		var focused=focus_controls.find(get_viewport().gui_get_focus_owner())
		if focused>=0: focus_memory[menu_mode]=focused
	if mode=="settings" and menu_mode not in ["settings","controls","audio","credits"]: settings_parent=menu_mode
	if mode=="audio" and menu_mode!="audio": audio_parent=menu_mode; audio_notice=""
	if mode=="controls" and menu_mode not in ["controls","bindings"]: controls_parent=menu_mode; gearbox_notice=""
	if mode=="cup_replace": focus_memory[mode]=0
	menu_mode=mode
	panel.visible=true; buttons.clear(); focus_controls.clear()
	for child in panel.get_children(): panel.remove_child(child); child.queue_free()
	var wide=mode in ["main","cups"]
	panel.position=Vector2(50,42)
	panel.custom_minimum_size=Vector2(1100,590) if wide else Vector2(900,570) if mode in ["results","standings","cup","garage","controls","bindings"] else Vector2(670,570)
	if mode in ["confirm","cup_replace"]:
		panel.custom_minimum_size=Vector2(720,320); panel.position=Vector2(280,180)
	panel.size=panel.custom_minimum_size
	var style=MenuSkin.plate(Color(0.06,0.08,0.09,0.94) if not wide else Color(0.04,0.06,0.07,0.4),24)
	style.content_margin_top=20; style.content_margin_bottom=20; style.skew=Vector2.ZERO
	panel.add_theme_stylebox_override("panel",style)
	var list = VBoxContainer.new(); list.add_theme_constant_override("separation",6 if mode in ["cup","bots","main"] else 10); panel.add_child(list)
	if mode in ["main","cups","modes","settings","audio","confirm","lobby"]:
		FrontMenu.build(self,list,mode)
	elif mode=="credits":
		list.add_child(label("CREDITS AND DATA",28,GOLD))
		list.add_child(label("Micro Rally · TrainerOS\nCode: GPL-3.0-or-later\nModels: Kenney (CC0)\nFont: Roboto Condensed · SIL OFL 1.1\n\nNordschleife:\n© OpenStreetMap contributors · ODbL\nopenstreetmap.org/copyright\n\nElevation: Terrain Tiles (Mapzen)\nCopernicus EU-DEM / USGS SRTM\nregistry.opendata.aws/terrain-tiles\n\nGeodata and licenses are included.\nGame adaptation, not affiliated with the circuit owner.",16))
		button(list,"Back",func(): menu("settings"))
	elif mode in ["cup","cup_replace","standings","garage"]:
		CupMenu.build(self,list,mode)
	elif mode=="bots":
		BotMenu.build(self,list)
	elif mode=="network_setup":
		list.add_child(label("LOBBY EVENT",36,GOLD))
		list.add_child(label("Choose the event for everyone.\nUp to 16 cars · empty seats use bots",20))
		button(list,"Racing · Dirty Valley",func(): game.net.select_event("race"))
		button(list,"Arena battle · Rust Pit",func(): game.net.select_event("arena"))
		button(list,"Leave",game.return_menu)
	elif mode=="quick":
		list.add_child(label("ARENA BATTLE" if game.is_arena() else "RACING",36,GOLD))
		list.add_child(label(game.track_title(),22))
		list.add_child(label(("8 minutes · respawns" if game.is_arena() else "1 full lap · 20+ min" if game.Tracks.TRACKS[game.current_track].get("quick_laps",4)==1 else "4 laps")+" · up to 16 cars",18,Color("bed0c6")))
		button(list,"Battle" if game.is_arena() else "Race",game.start_race)
		if not game.is_arena(): button(list,"Change track",game.cycle_track)
		button(list,"Car: "+game.car_title(),game.cycle_car)
		button(list,"Bots: %d · %s" % [game.bot_count,game.BotSettings.title(game.cup.store.bot_settings("quick"))],func(): BotMenu.open(self,"quick"))
		button(list,game.conditions.title()+(" ↗" if not game.conditions.timeline.is_empty() else ""),func(): menu("conditions"))
		button(list,"Controls",func(): menu("controls"))
		button(list,"Back",func(): menu("modes"))
	elif mode=="conditions":
		list.add_child(label("RACE CONDITIONS",28,GOLD))
		list.add_child(label(game.track_title(),22))
		button(list,"Time: "+game.conditions.time_title(),game.cycle_time)
		button(list,"Weather: "+game.conditions.weather_title(),game.cycle_weather)
		button(list,game.conditions.scenario_title(),game.cycle_scenario)
		list.add_child(label("Rain reduces grip\nand increases braking distance.\n\nConditions are shared by all drivers.\nPause also pauses the weather.\nRecords are separated by conditions.",18,Color("bed0c6")))
		button(list,"Back",func(): menu("quick"))
	elif mode=="controls":
		list.add_child(label("CONTROLS",36,GOLD))
		BotMenu.option(self,list,"Transmission: "+("manual" if game.cup.store.manual_gears() else "automatic"),func(_step): toggle_gearbox())
		BotMenu.option(self,list,"Vibration: "+game.haptics.TITLES[game.cup.store.haptics_level()],cycle_haptics)
		BotMenu.option(self,list,"Aim assist: "+game.arena.Aim.TITLES[game.arena.assist_level]+" · arena",game.arena.change_assist)
		button(list,"Button layout",func(): menu("bindings"))
		list.add_child(label("Steer left / right relative to your car.\nAim independently with the right stick.\n\nManual transmission has five gears.\nTop face button shifts up; right shifts down.",22,Color("bed0c6")))
		if not gearbox_notice.is_empty(): list.add_child(label(gearbox_notice,16,GOLD))
		button(list,"Back",back)
	elif mode=="bindings":
		list.add_child(label("BUTTON LAYOUT",36,GOLD))
		var columns=HBoxContainer.new(); columns.add_theme_constant_override("separation",32); list.add_child(columns)
		columns.add_child(label("CONTROLLER\n\nLeft stick — steer\nRight stick — aim\nRight trigger — accelerate\nLeft trigger — brake\nRight bumper — fire\nLeft bumper — boost\nBottom face button — handbrake\nLeft face button — shield\nTop / right face buttons — shift\nD-pad left / right — weapon",18))
		columns.add_child(label("KEYBOARD\n\nA / D or ← / → — steer\nW / S or ↑ / ↓ — accelerate / brake\nMouse — aim and fire\nShift — boost\nSpace — handbrake\nE — shield\nR — recover car\nC / Z — shift gears\nEscape — pause\nQ — weapon",18,Color("bed0c6")))
		button(list,"Back",func(): menu("controls"))
	elif mode=="pause":
		list.add_child(label("PAUSED",34,GOLD))
		button(list,"Resume",game.resume_race)
		button(list,"Settings",func(): menu("settings"))
		button(list,"Recover car",func(): game.recover_player(); game.resume_race())
		button(list,"Restart",func(): confirm("RESTART EVENT?","This event will restart from the beginning.\nCompleted stage results will be kept.","Restart",game.start_race))
		button(list,"Leave event",func(): confirm("LEAVE EVENT?","You will need to restart this stage.\nCompleted stage results will be kept." if game.cup.running else "This unfinished event result will not be saved.","Leave",game.cup.leave_stage if game.cup.running else game.return_menu))
	elif mode=="net_pause":
		list.add_child(label("ONLINE EVENT",30,GOLD))
		list.add_child(label("The event is still running.\nYour car has released the throttle.",19))
		button(list,"Resume",game.resume_race)
		button(list,"Settings",func(): menu("settings"))
		button(list,"Recover car",func(): game.recover_player(); game.resume_race())
		button(list,"Leave event",func(): confirm("LEAVE EVENT?","You will leave the current online event.","Leave",game.return_menu))
	elif mode=="disconnected":
		list.add_child(label("EVENT INTERRUPTED",28,GOLD))
		var reason = label(message,19); reason.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; reason.custom_minimum_size.x=330; list.add_child(reason)
		if game.net.bridge.registered: button(list,"Return to lobby",func(): game.net.bridge.open_lobby())
		else: button(list,"Return to TrainerOS",game.quit_game)
		button(list,"Solo play",func(): menu("main"))
	elif mode=="results":
		list.add_child(label("BATTLE OVER" if game.is_arena() else "FINISH!",38,GOLD))
		list.add_child(label(game.track_title()+" · "+game.BotSettings.title(game.race_bots),24))
		var rank = game.standings()
		var columns = HBoxContainer.new(); columns.add_theme_constant_override("separation",30); list.add_child(columns)
		var left = VBoxContainer.new(); var right = VBoxContainer.new(); columns.add_child(left); columns.add_child(right)
		for i in rank.size():
			var car: Node3D=rank[i]
			var column = left if i<8 else right
			var text=str(i+1)+"  "+car.driver_title()+"   "+("%.1f s" % car.finish_time if car.finish_time>=0 else "DNF")
			if game.is_arena():
				var row=game.arena.rules.ranked()[i]
				text="%d  %s   %d pts · %d K / %d D" % [row.place,car.driver_title(),row.score,row.kills,row.deaths]
			column.add_child(label(text,17 if game.is_arena() else 19,GOLD if car.local_player else PAPER))
		if game.cup.running:
			if not game.cup.pending_result.is_empty():
				list.add_child(label(game.cup.store.notice,18,GOLD))
				button(list,"Retry save",game.cup.retry_save)
			else:
				list.add_child(label("Stage points saved to the standings.",18,GOLD))
				button(list,"Stages and standings",game.cup.leave_stage)
		else:
			list.add_child(label("Single event · no cup points or rewards",16,Color("bed0c6")))
			if game.net.online and game.net.voted: list.add_child(label("Rematch: waiting for the other drivers…",19,GOLD))
			else: button(list,"Rematch",game.start_race)
			button(list,"Back to cups",game.return_menu)
	# Native controls share a deterministic vertical focus chain, including sliders.
	var enabled=focus_controls.filter(func(c): return not (c is BaseButton and c.disabled))
	for i in enabled.size():
		enabled[i].focus_neighbor_top=enabled[i].get_path_to(enabled[posmod(i-1,enabled.size())])
		enabled[i].focus_neighbor_bottom=enabled[i].get_path_to(enabled[(i+1)%enabled.size()])
	if not enabled.is_empty():
		var initial=FrontMenu.Catalog.FILTERS.size() if mode=="cups" and not FrontMenu.Catalog.cups(cup_filter,cup_entries).is_empty() else 0
		var saved=focus_controls[clampi(focus_memory.get(mode,initial),0,focus_controls.size()-1)]
		(saved if saved in enabled else enabled[0]).grab_focus()

func back() -> void:
	if menu_mode=="confirm": menu(confirm_parent); return
	if menu_mode=="settings": menu(settings_parent); return
	if menu_mode=="bots": menu(bots_parent); return
	if menu_mode=="audio": menu(audio_parent); return
	if menu_mode=="controls": menu(controls_parent); return
	if menu_mode=="main": confirm("QUIT GAME?","Completed stages and your garage are saved.","Quit",game.quit_game); return
	menu({"conditions":"quick","quick":"modes","standings":"cup","cup_replace":"cup","cup":"cups","credits":"settings","bindings":"controls"}.get(menu_mode,"main"))

func select_cup(id: String) -> void:
	if not FrontMenu.Catalog.can_start(id): return
	selected_cup=id; menu("cup")

func open_lobby() -> void:
	if game.net.bridge.registered: game.net.bridge.open_lobby()
	else: menu("lobby")

func confirm(title: String, body: String, action_title: String, action: Callable) -> void:
	confirm_parent=menu_mode; confirm_title=title; confirm_body=body
	confirm_action_title=action_title; confirm_action=action; focus_memory["confirm"]=0; menu("confirm")

func execute_confirm() -> void:
	var action=confirm_action; confirm_action=Callable()
	if action.is_valid(): action.call()

func cycle_haptics(step: int = 1) -> void:
	var value=posmod(game.cup.store.haptics_level()+step,game.haptics.LEVELS.size())
	gearbox_notice="" if game.cup.store.set_haptics_level(value) else "Could not save this setting."
	game.haptics.stop(); menu("controls")

func toggle_gearbox() -> void:
	var enabled=not game.cup.store.manual_gears()
	if game.cup.store.set_manual_gears(enabled):
		game.player().manual_gears=enabled; game.player().transmission.pending=0
		game.controls.neutral_required=true; gearbox_notice=""
	else: gearbox_notice="Could not save this setting."
	menu("controls")

func cycle_audio(kind: String) -> void:
	var current=game.sound.music_volume if kind=="music" else game.sound.effects_volume
	var value=fmod(roundf(current*4)+1,5)/4
	audio_notice="" if game.sound.set_volume(kind,value) else "Could not save settings."
	menu("audio")

func write(text: String, pos: Vector2, size_value: int, color: Color = PAPER) -> void:
	draw_string(font,pos+Vector2(1,2),text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value,Color(0,0,0,0.65))
	draw_string(font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value,color)

func _process(_delta: float) -> void:
	if not game.cars.is_empty():
		var car=game.player()
		var value=car.transmission.speed_kmh(car.linear_velocity)
		if speed_reset!=car.reset_serial or game.state in ["menu","countdown"]: displayed_speed=value; speed_reset=car.reset_serial
		else: displayed_speed=lerpf(displayed_speed,value,1-exp(-_delta*12))
	for i in shift_touch.size():
		shift_touch[i].position=Vector2(158+i*110,size.y-169)
		shift_touch[i].visible=game.state=="race" and not game.net.overlay and game.player().manual_gears and game.player().finish_time<0
	portrait.position=Vector2(size.x-284,size.y-290); portrait.size=Vector2(270,270)
	portrait.visible=game.state in ["race","countdown","pause","results"] and not panel.visible
	queue_redraw()

func _draw() -> void:
	if game==null or game.cars.is_empty(): return
	var car: Node3D=game.player()
	if panel.visible:
		_menu_backdrop()
		return
	if game.state=="menu":
		write(game.Tracks.TRACKS[game.current_track].sign,Vector2(size.x-380,size.y-65),28,GOLD)
		write("MICRO RALLY / FIRST DRIVE",Vector2(size.x-340,size.y-35),16)
		return
	if game.state=="network_wait":
		write(message,Vector2(40,size.y*0.5),26,GOLD)
		return
	var rank: Array=game.standings()
	draw_style_box(_plate(),Rect2(22,20,194,108))
	write(str(game.arena.rules.place(car.index) if game.is_arena() else rank.find(car)+1),Vector2(38,77),58,GOLD); write("/"+str(game.cars.size()),Vector2(110,76),31)
	var seconds = int(maxf(0,game.arena.Rules.DURATION-game.elapsed) if game.is_arena() else game.elapsed)
	write("%02d:%02d.%01d" % [seconds/60,seconds%60,int(game.elapsed*10)%10],Vector2(37,111),23)
	var section: String=game.track.section_name(car.checkpoint)
	if game.is_arena(): write("%d PTS · %d KOs" % [game.arena.rules.rows[car.index].score,game.arena.rules.rows[car.index].kills],Vector2(238,53),24,GOLD)
	else: write("LAP %d / %d" % [mini(game.laps,car.laps+1),game.laps] if section.is_empty() else "%.1f / %.1f km" % [maxf(0,float(car.passed)/game.track.COUNT*game.track.length/1000),game.track.length/1000],Vector2(238,53),24)
	if not section.is_empty(): write(section,Vector2(240,106),20,GOLD)
	write(game.conditions.live_title(game.elapsed),Vector2(240,79),17,Color("d1dfd4"))
	_map()
	# Compact status bars sit below the chair; gameplay has no bottom panel.
	var status_origin=Vector2(size.x-240,size.y-24)
	draw_line(status_origin,status_origin+Vector2(182,0),INK,10,true)
	draw_line(status_origin,status_origin+Vector2(182*car.health/100,0),Color("9ddd4f"),6,true)
	if car.shield>0: draw_line(status_origin+Vector2(0,10),status_origin+Vector2(182*car.shield/100,10),Color("45c7ff"),4,true)
	var boost_center = Vector2(83,size.y-79)
	draw_circle(boost_center,52,INK); draw_arc(boost_center,43,-PI*0.88,PI*0.88,48,Color("224d5c"),9,true)
	draw_arc(boost_center,43,-PI*0.88,-PI*0.88+PI*1.76*car.boost/100,48,Color("42cff6"),9,true)
	write("BOOST",boost_center+Vector2(-32,8),19); write(str(int(car.boost)),boost_center+Vector2(-20,31),21)
	_speedometer(car)
	var weapon = Vector2(size.x-432,size.y-111)
	draw_style_box(_plate(),Rect2(weapon,Vector2(181,88)))
	var heat_color = Color("ff694b") if car.overheated else GOLD if car.weapon_heat>65 else Color("58d7ec")
	write("OVERHEATED" if car.overheated else (car.weapon.to_upper()+" · "+str(car.ammo) if game.is_arena() and car.weapon_selected and car.ammo>0 else "MACHINE GUN"),weapon+Vector2(14,26),17,heat_color)
	write("∞",weapon+Vector2(142,28),26,PAPER)
	draw_style_box(_plate(),Rect2(weapon+Vector2(14,38),Vector2(153,13)))
	draw_line(weapon+Vector2(15,44),weapon+Vector2(166,44),Color("32444a"),9,true)
	if car.weapon_heat>0: draw_line(weapon+Vector2(15,44),weapon+Vector2(15+151*car.weapon_heat/100,44),heat_color,9,true)
	write("SHIELD: "+("READY" if car.shield_item else "—"),weapon+Vector2(14,76),15,Color("7edbff"))
	if game.state in ["race","countdown"]:
		var target: Vector3=car.position+car.aim*8+Vector3.UP*0.4
		if not game.camera.is_position_behind(target):
			var p: Vector2=game.camera.unproject_position(target)
			draw_arc(p,12,0,TAU,28,PAPER,2,true)
			for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]: draw_line(p+direction*8,p+direction*18,PAPER,2,true)
	if game.state=="countdown":
		var text = str(maxi(1,ceili(game.countdown)))
		write(text,Vector2(size.x*0.5-25,size.y*0.4),90,GOLD)
	if car.disabled_time>0: write("RECOVERING",Vector2(size.x*0.5-110,size.y*0.4),25,GOLD)
	elif car.missing_wheels!=0: write("WHEEL LOST",Vector2(size.x*0.5-112,size.y-140),20,Color("ff995b"))
	if not message.is_empty(): write(message,Vector2(240,106 if section.is_empty() else 132),18,GOLD)
	if game.show_metrics: write("%.0f FPS · %d cars" % [Engine.get_frames_per_second(),game.cars.size()],Vector2(240,115),18)

func _menu_backdrop() -> void:
	var modal=menu_mode in ["confirm","cup_replace"]
	var shade=0.7 if modal else 0.42
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.025,0.035,0.035,shade))
	if not modal:
		var polygon=PackedVector2Array([Vector2.ZERO,Vector2(size.x*0.85,0),Vector2(size.x*0.64,size.y),Vector2(0,size.y)])
		draw_polygon(polygon,PackedColorArray([Color(0.035,0.045,0.05,0.95),Color(0.035,0.045,0.05,0.18),Color(0.035,0.045,0.05,0.18),Color(0.035,0.045,0.05,0.95)]))
		# Deterministic scuffs around the frame, outside the text area. No texture pass.
		for i in 38:
			var p=Vector2(fmod(i*173.0,size.x),14+fmod(i*7.0,18))
			draw_line(p,p+Vector2(12+i%17,-2),Color(0.88,0.85,0.73,0.08),1)
		draw_colored_polygon(PackedVector2Array([Vector2(20,48),Vector2(28,48),Vector2(23,114),Vector2(15,114)]),GOLD)
	var hints="↑ ↓ — select    Enter — confirm    Esc — back"
	var pads=Input.get_connected_joypads()
	if not pads.is_empty():
		var pad_name=Input.get_joy_name(pads[0]).to_lower()
		var accept="Bottom face button"; var cancel="Right face button"
		if "xbox" in pad_name or "xinput" in pad_name: accept="A"; cancel="B"
		elif "playstation" in pad_name or "dual" in pad_name or "ps4" in pad_name or "ps5" in pad_name: accept="×"; cancel="○"
		elif "nintendo" in pad_name or "switch" in pad_name: accept="B"; cancel="A"
		hints="Stick / D-pad — select    %s — confirm    %s — back" % [accept,cancel]
	write(hints,Vector2(52,size.y-26),18,Color("e1e5d6"))

func _speedometer(car: Node3D) -> void:
	var at=Vector2(158,size.y-117)
	draw_style_box(_plate(),Rect2(at,Vector2(204,94)))
	write("%03d" % roundi(displayed_speed),at+Vector2(12,57),48)
	write("km/h",at+Vector2(16,79),16,Color("bed0c6"))
	var hot=car.transmission.rpm>=car.transmission.SHIFT_RPM
	var tint=GOLD if hot else Color("58d7ec")
	write(car.transmission.gear_label(),at+Vector2(150,55),40,tint)
	write("MT" if car.manual_gears else "AT",at+Vector2(151,78),15)
	for i in 10:
		var lit=car.transmission.rpm/car.transmission.REDLINE>float(i)/10
		var color=(Color("ff7052") if i>=8 else GOLD if i>=6 else Color("58d7ec")) if lit else Color("284647")
		draw_line(at+Vector2(13+i*18,7),at+Vector2(26+i*18,7),color,5,true)
	if car.manual_gears and hot and car.transmission.gear<5 and not car.transmission.reverse:
		write("↑",at+Vector2(178,39),22,GOLD)

func _plate() -> StyleBoxFlat:
	var style = StyleBoxFlat.new(); style.bg_color=INK; style.set_corner_radius_all(16); return style

func _map() -> void:
	var origin=Vector2(size.x-104,110)
	var bounds: Rect2=game.track.map_bounds
	var scale_value=minf(150.0/maxf(1,bounds.size.x),148.0/maxf(1,bounds.size.y))
	var center=bounds.get_center()
	if game.is_arena():
		draw_rect(Rect2(origin-bounds.size*scale_value/2,bounds.size*scale_value),Color(0.06,0.08,0.07,0.7))
		for cover in game.track.covers: draw_rect(Rect2(origin+(cover.position-center)*scale_value,cover.size*scale_value),Color("9e9d87"))
	else:
		var path = PackedVector2Array()
		# A 150-pixel map needs at most 512 segments, independent of physics samples.
		for i in range(0,game.track.COUNT,maxi(1,ceili(game.track.COUNT/512.0))):
			var p: Vector3=game.track.points[i]; path.append(origin+(Vector2(p.x,p.z)-center)*scale_value)
		path.append(path[0]); draw_polyline(path,Color(0.04,0.08,0.07,0.7),9,true); draw_polyline(path,Color("b5c5b6"),5,true)
	for c in game.cars:
		var p: Vector2=origin+(Vector2(c.position.x,c.position.z)-center)*scale_value
		draw_circle(p,5 if c.local_player else 3.5,Car.COLORS[c.index%8])
