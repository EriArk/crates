# SPDX-License-Identifier: GPL-3.0-or-later
extends Control
const Portrait = preload("portrait.gd")
const Car = preload("car.gd")
const BotMenu = preload("bot_menu.gd")
var bots_parent = "quick"
var bot_notice = ""
var bot_axis_direction = 0
const CupMenu = preload("cup_menu.gd")
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
const INK = Color(0.025,0.045,0.045,0.86)
const PAPER = Color("fff6d8")
const GOLD = Color("ffcc42")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE; font=ThemeDB.fallback_font
	portrait=Portrait.new(); portrait.shared_sdk=game.net.bridge; portrait.game=game; add_child(portrait)
	panel=PanelContainer.new(); panel.position=Vector2(40,42); panel.custom_minimum_size=Vector2(390,490)
	var style = StyleBoxFlat.new(); style.bg_color=Color(0.025,0.055,0.06,0.93); style.set_corner_radius_all(24)
	style.content_margin_left=25; style.content_margin_right=25; style.content_margin_top=24; style.content_margin_bottom=24
	panel.add_theme_stylebox_override("panel",style); add_child(panel)
	menu("main")

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion and event.axis==JOY_AXIS_LEFT_X and absf(event.axis_value)<0.3:
		bot_axis_direction=0

func label(text: String, size_value: int, color: Color = PAPER) -> Label:
	var l = Label.new(); l.text=text; l.add_theme_font_size_override("font_size",size_value); l.add_theme_color_override("font_color",color)
	return l

func button(parent: Node, text: String, action: Callable) -> Button:
	var b = Button.new(); b.text=text; b.custom_minimum_size=Vector2(330,48); b.add_theme_font_size_override("font_size",22)
	var normal = StyleBoxFlat.new(); normal.bg_color=Color("254244"); normal.set_corner_radius_all(10)
	var focus = normal.duplicate(); focus.bg_color=Color("dca634"); focus.set_border_width_all(3); focus.border_color=Color("fff2b8")
	b.add_theme_stylebox_override("normal",normal); b.add_theme_stylebox_override("focus",focus); b.add_theme_stylebox_override("hover",focus)
	b.pressed.connect(func(): game.sound.play_event("ui"); action.call())
	parent.add_child(b); buttons.append(b)
	return b

func menu(mode: String) -> void:
	if mode=="audio" and menu_mode!="audio": audio_parent=menu_mode; audio_notice=""
	if mode=="controls": controls_parent="quick" if menu_mode=="quick" else "main"
	var previous_focus = buttons.find(get_viewport().gui_get_focus_owner()) if mode==menu_mode else 0
	menu_mode=mode
	panel.visible=true; buttons.clear()
	for child in panel.get_children(): panel.remove_child(child); child.queue_free()
	panel.custom_minimum_size=Vector2(760,490) if mode in ["results","standings"] else Vector2(640,490) if mode in ["cup","cup_replace","garage","bots"] else Vector2(390,490)
	panel.size=panel.custom_minimum_size
	var list = VBoxContainer.new(); list.add_theme_constant_override("separation",6 if mode in ["cup","bots"] else 8); panel.add_child(list)
	if mode=="main":
		list.add_child(label("MICRO RALLY (альфа)",28,GOLD))
		list.add_child(label("КУБКИ · ГАРАЖ · СЕТЕВАЯ ИГРА",17))
		button(list,"Кубок: Лесной вызов",func(): menu("cup"))
		button(list,"Гараж",game.cup.open_garage)
		button(list,"Отдельный заезд",func(): menu("quick"))
		if game.net.bridge.registered: button(list,"Играть с друзьями",game.net.bridge.open_lobby)
		button(list,"Управление",func(): menu("controls"))
		button(list,"Звук и музыка",func(): menu("audio"))
		button(list,"Выйти",game.quit_game)
	elif mode in ["cup","cup_replace","standings","garage"]:
		CupMenu.build(self,list,mode)
	elif mode=="bots":
		BotMenu.build(self,list)
	elif mode=="quick":
		list.add_child(label("ОТДЕЛЬНЫЙ ЗАЕЗД",28,GOLD))
		list.add_child(label(game.track_title(),22))
		list.add_child(label("4 круга · до 16 машин",18,Color("bed0c6")))
		button(list,"В гонку",game.start_race)
		button(list,"Сменить трассу",game.cycle_track)
		button(list,"Машина: "+game.car_title(),game.cycle_car)
		button(list,"Боты: %d · %s" % [game.bot_count,game.BotSettings.title(game.cup.store.bot_settings("quick"))],func(): BotMenu.open(self,"quick"))
		button(list,game.conditions.title()+(" ↗" if not game.conditions.timeline.is_empty() else ""),func(): menu("conditions"))
		button(list,"Управление",func(): menu("controls"))
		button(list,"Назад",func(): menu("main"))
	elif mode=="conditions":
		list.add_child(label("УСЛОВИЯ ЗАЕЗДА",28,GOLD))
		list.add_child(label(game.track_title(),22))
		button(list,"Время: "+game.conditions.time_title(),game.cycle_time)
		button(list,"Погода: "+game.conditions.weather_title(),game.cycle_weather)
		button(list,game.conditions.scenario_title(),game.cycle_scenario)
		list.add_child(label("Дождь: меньше сцепления,\nдлиннее тормозной путь.\n\nОбщий сценарий для всех.\nПауза останавливает погоду.\nРекорды разделены по условиям.",18,Color("bed0c6")))
		button(list,"Назад",func(): menu("quick"))
	elif mode=="audio":
		list.add_child(label("ЗВУК И МУЗЫКА",28,GOLD))
		list.add_child(label("Гаражный рок · грязь · металл",19,Color("bed0c6")))
		button(list,"Музыка: %d%%" % roundi(game.sound.music_volume*100),func(): cycle_audio("music"))
		button(list,"Эффекты: %d%%" % roundi(game.sound.effects_volume*100),func(): cycle_audio("effects"))
		list.add_child(label("Нажатие меняет громкость.\n0% — выключено.\n\nПеред важными сигналами\nмузыка становится тише.",19))
		if not audio_notice.is_empty(): list.add_child(label(audio_notice,17,GOLD))
		button(list,"Назад",func(): menu(audio_parent))
	elif mode=="controls":
		list.add_child(label("УПРАВЛЕНИЕ",28,GOLD))
		list.add_child(label("Левый стик — руль влево / вправо\nПравый стик — прицел\nПравый триггер — газ\nЛевый триггер — тормоз\nПравый бампер — огонь\nЛевый бампер — ускорение\nНижняя кнопка — ручник\nЛевая кнопка — щит",19))
		list.add_child(label("A / D или ← / → — руль\nW / S или ↑ / ↓ — газ / тормоз\nМышь — огонь, Shift — boost\nSpace — ручник, E — щит, R — возврат",16,Color("bed0c6")))
		button(list,"Назад",back)
	elif mode=="pause":
		list.add_child(label("ПАУЗА",34,GOLD))
		button(list,"Продолжить",game.resume_race)
		button(list,"Звук и музыка",func(): menu("audio"))
		button(list,"Вернуть машину на трассу",func(): game.recover_player(); game.resume_race())
		button(list,"Начать заново",game.start_race)
		button(list,"Выйти · этап с начала" if game.cup.running else "К кубкам",game.cup.leave_stage if game.cup.running else game.return_menu)
	elif mode=="net_pause":
		list.add_child(label("СЕТЕВОЙ ЗАЕЗД",30,GOLD))
		list.add_child(label("Гонка продолжается.\nВаша машина отпустила газ.",19))
		button(list,"Продолжить",game.resume_race)
		button(list,"Звук и музыка",func(): menu("audio"))
		button(list,"Вернуть машину",func(): game.recover_player(); game.resume_race())
		button(list,"Покинуть заезд",game.return_menu)
	elif mode=="disconnected":
		list.add_child(label("ЗАЕЗД ПРЕРВАН",28,GOLD))
		var reason = label(message,19); reason.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; reason.custom_minimum_size.x=330; list.add_child(reason)
		if game.net.bridge.registered: button(list,"Вернуться в лобби",func(): game.net.bridge.open_lobby())
		else: button(list,"Вернуться в TrainerOS",game.quit_game)
		button(list,"Одиночная игра",func(): menu("main"))
	elif mode=="results":
		list.add_child(label("ФИНИШ!",38,GOLD))
		list.add_child(label(game.track_title()+" · "+game.BotSettings.title(game.race_bots),24))
		var rank = game.standings()
		var columns = HBoxContainer.new(); columns.add_theme_constant_override("separation",30); list.add_child(columns)
		var left = VBoxContainer.new(); var right = VBoxContainer.new(); columns.add_child(left); columns.add_child(right)
		for i in rank.size():
			var car: Node3D=rank[i]
			var column = left if i<8 else right
			column.add_child(label(str(i+1)+"  "+car.driver_title()+"   "+("%.1f с" % car.finish_time if car.finish_time>=0 else "не финишировал"),19,GOLD if car.local_player else PAPER))
		if game.cup.running:
			if not game.cup.pending_result.is_empty():
				list.add_child(label(game.cup.store.notice,18,GOLD))
				button(list,"Повторить сохранение",game.cup.retry_save)
			else:
				list.add_child(label("Очки этапа сохранены в общем зачёте.",18,GOLD))
				button(list,"К этапам и зачёту",game.cup.leave_stage)
		else:
			list.add_child(label("Отдельный заезд · без очков и наград кубка",16,Color("bed0c6")))
			if game.net.online and game.net.voted: list.add_child(label("Реванш: ожидаем остальных участников…",19,GOLD))
			else: button(list,"Реванш",game.start_race)
			button(list,"К кубкам",game.return_menu)
	if not buttons.is_empty(): buttons[clampi(previous_focus,0,buttons.size()-1)].grab_focus()

func back() -> void:
	if menu_mode=="bots": menu(bots_parent); return
	if menu_mode=="audio": menu(audio_parent); return
	menu(controls_parent if menu_mode=="controls" else {"conditions":"quick","standings":"cup","cup_replace":"cup"}.get(menu_mode,"main"))

func cycle_audio(kind: String) -> void:
	var current=game.sound.music_volume if kind=="music" else game.sound.effects_volume
	var value=fmod(roundf(current*4)+1,5)/4
	audio_notice="" if game.sound.set_volume(kind,value) else "Не удалось сохранить настройки."
	menu("audio")

func write(text: String, pos: Vector2, size_value: int, color: Color = PAPER) -> void:
	draw_string(font,pos+Vector2(1,2),text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value,Color(0,0,0,0.65))
	draw_string(font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value,color)

func _process(_delta: float) -> void:
	portrait.position=Vector2(size.x-284,size.y-290); portrait.size=Vector2(270,270)
	portrait.visible=game.state in ["race","countdown","pause","results"]
	queue_redraw()

func _draw() -> void:
	if game==null or game.cars.is_empty(): return
	var car: Node3D=game.player()
	if game.state=="menu":
		write(game.Tracks.TRACKS[game.current_track].sign,Vector2(size.x-380,size.y-65),28,GOLD)
		write("MICRO RALLY / FIRST DRIVE",Vector2(size.x-340,size.y-35),16)
		return
	if game.state=="network_wait":
		write(message,Vector2(40,size.y*0.5),26,GOLD)
		return
	var rank: Array=game.standings()
	draw_style_box(_plate(),Rect2(22,20,194,108))
	write(str(rank.find(car)+1),Vector2(38,77),58,GOLD); write("/"+str(game.cars.size()),Vector2(110,76),31)
	var seconds = int(game.elapsed)
	write("%02d:%02d.%01d" % [seconds/60,seconds%60,int(game.elapsed*10)%10],Vector2(37,111),23)
	write("КРУГ %d / %d" % [mini(game.laps,car.laps+1),game.laps],Vector2(238,53),24)
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
	var weapon = Vector2(size.x-432,size.y-111)
	draw_style_box(_plate(),Rect2(weapon,Vector2(181,88)))
	var heat_color = Color("ff694b") if car.overheated else GOLD if car.weapon_heat>65 else Color("58d7ec")
	write("ПЕРЕГРЕВ" if car.overheated else "ПУЛЕМЁТ",weapon+Vector2(14,26),17,heat_color)
	write("∞",weapon+Vector2(142,28),26,PAPER)
	draw_style_box(_plate(),Rect2(weapon+Vector2(14,38),Vector2(153,13)))
	draw_line(weapon+Vector2(15,44),weapon+Vector2(166,44),Color("32444a"),9,true)
	if car.weapon_heat>0: draw_line(weapon+Vector2(15,44),weapon+Vector2(15+151*car.weapon_heat/100,44),heat_color,9,true)
	write("ЩИТ: "+("ГОТОВ" if car.shield_item else "—"),weapon+Vector2(14,76),15,Color("7edbff"))
	if game.state in ["race","countdown"]:
		var target: Vector3=car.position+car.aim*8+Vector3.UP*0.4
		if not game.camera.is_position_behind(target):
			var p: Vector2=game.camera.unproject_position(target)
			draw_arc(p,12,0,TAU,28,PAPER,2,true)
			for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]: draw_line(p+direction*8,p+direction*18,PAPER,2,true)
	if game.state=="countdown":
		var text = str(maxi(1,ceili(game.countdown)))
		write(text,Vector2(size.x*0.5-25,size.y*0.4),90,GOLD)
	if car.disabled_time>0: write("ВОССТАНОВЛЕНИЕ",Vector2(size.x*0.5-110,size.y*0.4),25,GOLD)
	elif car.missing_wheels!=0: write("КОЛЕСО ПОТЕРЯНО",Vector2(size.x*0.5-112,size.y-140),20,Color("ff995b"))
	if not message.is_empty(): write(message,Vector2(240,106),18,GOLD)
	if game.show_metrics: write("%.0f FPS · %d машин" % [Engine.get_frames_per_second(),game.cars.size()],Vector2(240,115),18)

func _plate() -> StyleBoxFlat:
	var style = StyleBoxFlat.new(); style.bg_color=INK; style.set_corner_radius_all(16); return style

func _map() -> void:
	var origin=Vector2(size.x-104,110)
	var bounds: Rect2=game.track.map_bounds
	var scale_value=minf(150.0/maxf(1,bounds.size.x),148.0/maxf(1,bounds.size.y))
	var center=bounds.get_center()
	var path = PackedVector2Array()
	for p in game.track.points: path.append(origin+(Vector2(p.x,p.z)-center)*scale_value)
	path.append(path[0]); draw_polyline(path,Color(0.04,0.08,0.07,0.7),9,true); draw_polyline(path,Color("b5c5b6"),5,true)
	for c in game.cars:
		var p: Vector2=origin+(Vector2(c.position.x,c.position.z)-center)*scale_value
		draw_circle(p,5 if c.local_player else 3.5,Car.COLORS[c.index%8])
