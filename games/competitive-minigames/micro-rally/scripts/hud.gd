# SPDX-License-Identifier: GPL-3.0-or-later
extends Control
const Portrait = preload("portrait.gd")
const Car = preload("car.gd")
var game: Node3D
var portrait: TextureRect
var font: Font
var panel: PanelContainer
var message = ""
var buttons: Array[Button] = []
var fps_label = ""
const INK = Color(0.025,0.045,0.045,0.86)
const PAPER = Color("fff6d8")
const GOLD = Color("ffcc42")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE; font=ThemeDB.fallback_font
	portrait=Portrait.new(); add_child(portrait)
	panel=PanelContainer.new(); panel.position=Vector2(46,90); panel.custom_minimum_size=Vector2(390,490)
	var style = StyleBoxFlat.new(); style.bg_color=Color(0.025,0.055,0.06,0.93); style.set_corner_radius_all(24)
	style.content_margin_left=25; style.content_margin_right=25; style.content_margin_top=24; style.content_margin_bottom=24
	panel.add_theme_stylebox_override("panel",style); add_child(panel)
	menu("main")

func label(text: String, size_value: int, color: Color = PAPER) -> Label:
	var l = Label.new(); l.text=text; l.add_theme_font_size_override("font_size",size_value); l.add_theme_color_override("font_color",color)
	return l

func button(parent: Node, text: String, action: Callable) -> Button:
	var b = Button.new(); b.text=text; b.custom_minimum_size=Vector2(330,48); b.add_theme_font_size_override("font_size",22)
	var normal = StyleBoxFlat.new(); normal.bg_color=Color("254244"); normal.set_corner_radius_all(10)
	var focus = normal.duplicate(); focus.bg_color=Color("dca634"); focus.set_border_width_all(3); focus.border_color=Color("fff2b8")
	b.add_theme_stylebox_override("normal",normal); b.add_theme_stylebox_override("focus",focus); b.add_theme_stylebox_override("hover",focus)
	b.pressed.connect(action); parent.add_child(b); buttons.append(b)
	return b

func menu(mode: String) -> void:
	panel.visible=true; buttons.clear()
	for child in panel.get_children(): panel.remove_child(child); child.queue_free()
	var list = VBoxContainer.new(); list.add_theme_constant_override("separation",12); panel.add_child(list)
	if mode=="main":
		list.add_child(label("MICRO RALLY",38,GOLD)); list.add_child(label("CUPS / КУБКИ",18))
		list.add_child(label("ЛЕСНОЙ ВЫЗОВ",27)); list.add_child(label("01  Грязевая долина",22))
		list.add_child(label("Первый игровой участок\n4 круга · до 16 машин",18,Color("bed0c6")))
		button(list,"В гонку",game.start_race)
		button(list,"Машина: "+game.car_title(),game.cycle_car)
		button(list,"Соперники: "+str(game.bot_count),game.cycle_bots)
		button(list,"Управление",func(): menu("controls"))
		button(list,"Выйти",game.quit_game)
	elif mode=="controls":
		list.add_child(label("УПРАВЛЕНИЕ",28,GOLD))
		list.add_child(label("Левый стик — направление\nПравый стик — прицел\nПравый триггер — газ\nЛевый триггер — тормоз\nПравый бампер — огонь\nЛевый бампер — ускорение\nНижняя кнопка — ручник\nЛевая кнопка — щит",19))
		list.add_child(label("Клавиатура: WASD — направление\n↑ / ↓ — газ / тормоз, мышь — огонь\nShift — boost, Space — ручник\nE — щит, R — вернуть машину",16,Color("bed0c6")))
		button(list,"Назад",func(): menu("main"))
	elif mode=="pause":
		list.add_child(label("ПАУЗА",34,GOLD))
		button(list,"Продолжить",game.resume_race)
		button(list,"Вернуть машину на трассу",func(): game.recover_player(); game.resume_race())
		button(list,"Начать заново",game.start_race)
		button(list,"К кубкам",game.return_menu)
	elif mode=="results":
		list.add_child(label("ФИНИШ!",38,GOLD))
		list.add_child(label("Грязевая долина",24))
		var rank = game.standings()
		for i in mini(rank.size(),6):
			var car: Node3D=rank[i]
			list.add_child(label(str(i+1)+"  "+("Вы" if car.index==0 else "Гонщик "+str(car.index))+"   "+("%.1f с" % car.finish_time if car.finish_time>=0 else "на трассе"),19,GOLD if car.index==0 else PAPER))
		list.add_child(label("Это первый этап будущего кубка.\nПриз кубка пока не разыгрывается.",16,Color("bed0c6")))
		button(list,"Реванш",game.start_race); button(list,"К кубкам",game.return_menu)
	if not buttons.is_empty(): buttons[0].grab_focus()

func write(text: String, pos: Vector2, size_value: int, color: Color = PAPER) -> void:
	draw_string(font,pos+Vector2(1,2),text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value,Color(0,0,0,0.65))
	draw_string(font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value,color)

func _process(_delta: float) -> void:
	portrait.position=Vector2(size.x*0.5-37,size.y-109); portrait.size=Vector2(74,74)
	portrait.visible=game.state in ["race","countdown","pause","results"]
	queue_redraw()

func _draw() -> void:
	if game==null or game.cars.is_empty(): return
	var car: Node3D=game.cars[0]
	if game.state=="menu":
		write("DIRTY VALLEY",Vector2(size.x-340,size.y-65),28,GOLD)
		write("MICRO RALLY / FIRST DRIVE",Vector2(size.x-340,size.y-35),16)
		return
	var rank: Array=game.standings()
	draw_style_box(_plate(),Rect2(22,20,194,108))
	write(str(rank.find(car)+1),Vector2(38,77),58,GOLD); write("/"+str(game.cars.size()),Vector2(110,76),31)
	var seconds = int(game.elapsed)
	write("%02d:%02d.%01d" % [seconds/60,seconds%60,int(game.elapsed*10)%10],Vector2(37,111),23)
	write("КРУГ %d / %d" % [mini(game.laps,car.laps+1),game.laps],Vector2(238,53),24)
	_map()
	var center = Vector2(size.x*0.5,size.y-72)
	draw_circle(center,55,INK)
	draw_arc(center,49,deg_to_rad(95),deg_to_rad(265),42,Color("28483e"),7,true)
	draw_arc(center,49,deg_to_rad(95),deg_to_rad(95+170*car.health/100),42,Color("9ddd4f"),7,true)
	draw_arc(center,49,deg_to_rad(-85),deg_to_rad(85),42,Color("24394a"),7,true)
	if car.shield>0: draw_arc(center,49,deg_to_rad(-85),deg_to_rad(-85+170*car.shield/100),42,Color("45c7ff"),7,true)
	if portrait.texture==null:
		# Neutral driver icon while the SDK is absent; no substituted wardrobe.
		draw_circle(center,31,Color("d9aa79")); draw_arc(center+Vector2(0,-3),28,PI,TAU,24,Color("4d3431"),11,true)
		draw_circle(center+Vector2(-10,-2),3,INK); draw_circle(center+Vector2(10,-2),3,INK)
		draw_line(center+Vector2(-9,14),center+Vector2(9,14),INK,3,true)
	var boost_center = Vector2(83,size.y-79)
	draw_circle(boost_center,52,INK); draw_arc(boost_center,43,-PI*0.88,PI*0.88,48,Color("224d5c"),9,true)
	draw_arc(boost_center,43,-PI*0.88,-PI*0.88+PI*1.76*car.boost/100,48,Color("42cff6"),9,true)
	write("BOOST",boost_center+Vector2(-32,8),19); write(str(int(car.boost)),boost_center+Vector2(-20,31),21)
	var weapon = Vector2(size.x-203,size.y-115)
	draw_style_box(_plate(),Rect2(weapon,Vector2(181,88)))
	write("ПУЛЕМЁТ",weapon+Vector2(14,26),17); write("%02d" % car.ammo,weapon+Vector2(118,64),35,GOLD)
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
	if not message.is_empty(): write(message,Vector2(240,87),18)
	if game.show_metrics: write("%.0f FPS · %d машин" % [Engine.get_frames_per_second(),game.cars.size()],Vector2(240,115),18)

func _plate() -> StyleBoxFlat:
	var style = StyleBoxFlat.new(); style.bg_color=INK; style.set_corner_radius_all(16); return style

func _map() -> void:
	var origin = Vector2(size.x-180,34); var scale_value = 0.75
	var path = PackedVector2Array()
	for p in game.track.points: path.append(origin+Vector2(p.x+78,p.z+80)*scale_value)
	path.append(path[0]); draw_polyline(path,Color(0.04,0.08,0.07,0.7),9,true); draw_polyline(path,Color("b5c5b6"),5,true)
	for c in game.cars:
		var p: Vector2=origin+Vector2(c.position.x+78,c.position.z+80)*scale_value
		draw_circle(p,5 if c.index==0 else 3.5,Car.COLORS[c.index%8])
