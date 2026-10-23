# SPDX-License-Identifier: GPL-3.0-or-later
extends Control
# Presentation and pointer routing only; all actions still go through Match/main.
signal pause_requested
signal view_requested
signal putt_requested
signal aim_dragged(steps: int)
signal power_selected(percent: int)
const INK := Color("183f3d")
const PAPER := Color("fff9e8")
const MINT := Color("8eddb4")
const CORAL := Color("f4aa89")
var state: Dictionary = {}
var captures: Dictionary = {}
var status := ""
var distance := 0.0
var font: Font

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	font=ThemeDB.fallback_font
	resized.connect(queue_redraw)

func update_state(next: Dictionary) -> void:
	if not next.can_shoot or (not state.is_empty() and next.mode!=state.mode): captures.clear()
	state=next
	visible=state.phase in ["aim","moving"] and not state.paused
	if not visible: captures.clear()
	queue_redraw()

func set_status(text: String) -> void:
	if status!=text: status=text; queue_redraw()

func set_distance(metres: float) -> void:
	if absf(metres-distance)>0.05: distance=metres; queue_redraw()

func ui_scale() -> float:
	return clampf(960.0/maxf(1.0,get_window().size.x),1.0,1.5)

func layout_size() -> Vector2:
	return size/ui_scale()

func screen_point(point: Vector2) -> Vector2:
	return get_viewport().get_final_transform()*get_global_transform_with_canvas()*(point*ui_scale())

func regions() -> Dictionary:
	var result := {"course":Rect2(16,16,254,62),"pause":Rect2(layout_size().x-62,16,46,48),"view":Rect2(layout_size().x-116,16,46,48)}
	result["players"]=Rect2(layout_size().x-176,86,160,50*state.get("players",1))
	if state.get("can_shoot",false):
		result["power"]=Rect2(22,layout_size().y-94,222,64)
		if state.get("mode","")=="touch":
			result["aim"]=Rect2(22,layout_size().y-170,154,60)
			result["putt"]=Rect2(layout_size().x-98,layout_size().y-98,80,80)
		else: result["putt"]=Rect2(260,layout_size().y-78,126,48)
	return result

func action_at(point: Vector2) -> String:
	for action in regions():
		if regions()[action].has_point(point): return action
	return ""

func route_pointer(event: InputEvent) -> bool:
	if not visible: return false
	var id := -1
	var pressed := false
	var released := false
	var moving := false
	var point := Vector2.ZERO
	if event is InputEventScreenTouch:
		id=event.index; point=event.position; pressed=event.pressed; released=not pressed
	elif event is InputEventScreenDrag:
		id=event.index; point=event.position; moving=true
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.device==InputEvent.DEVICE_ID_EMULATION: return false
		point=event.position; pressed=event.pressed; released=not pressed
	elif event is InputEventMouseMotion:
		if event.device==InputEvent.DEVICE_ID_EMULATION: return false
		point=event.position; moving=true
	else: return false
	point=(get_global_transform_with_canvas().affine_inverse()*point)/ui_scale()
	if pressed:
		var action := action_at(point)
		if action.is_empty(): return false
		captures[id]={"action":action,"last":point,"remainder":0.0}
		if action=="power": _power_at(point)
		return true
	if not captures.has(id): return false
	var capture: Dictionary = captures[id]
	if moving:
		if capture.action=="power": _power_at(point)
		elif capture.action=="aim":
			capture.remainder+=point.x-capture.last.x
			var steps := int(capture.remainder/10.0)
			capture.remainder-=steps*10.0
			if steps!=0: aim_dragged.emit(steps)
		capture.last=point
	elif released:
		captures.erase(id)
		if action_at(point)==capture.action:
			match capture.action:
				"pause": pause_requested.emit()
				"view": view_requested.emit()
				"putt": if state.can_shoot: putt_requested.emit()
	return true

func cancel_pointers() -> void:
	captures.clear()

func _power_at(point: Vector2) -> void:
	var amount := clampf((point.x-26.0)/210.0,0.0,1.0)
	power_selected.emit(clampi(roundi(amount*20.0)*5,10,100))

func _text(text: String, at: Vector2, pixels: int=16, color: Color=PAPER) -> void:
	draw_string_outline(font,at+Vector2(0,1),text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,4,Color(0.05,0.15,0.15,0.24))
	draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,color)

func _pill(rect: Rect2, color: Color, radius: int=16) -> void:
	var style := StyleBoxFlat.new(); style.bg_color=color; style.set_corner_radius_all(radius)
	draw_style_box(style,rect)

func _glyph(text: String, at: Vector2, width: float=28) -> void:
	_pill(Rect2(at,Vector2(width,26)),Color(0.08,0.22,0.21,0.78),9)
	var extent := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,14)
	_text(text,at+Vector2((width-extent.x)/2,18),14)

func _draw() -> void:
	if state.is_empty() or font==null: return
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*ui_scale())
	# A small course seal, never a full-width header or footer.
	draw_circle(Vector2(44,44),28,Color(0.08,0.22,0.21,0.80))
	draw_arc(Vector2(44,44),26,-PI/2,TAU*state.hole/3.0-PI/2,40,MINT,2,true)
	draw_line(Vector2(40,30),Vector2(40,55),PAPER,2,true)
	draw_colored_polygon(PackedVector2Array([Vector2(42,30),Vector2(58,35),Vector2(42,41)]),CORAL)
	draw_arc(Vector2(43,56),7,0,TAU,24,PAPER,1.5,true)
	_text("HOLE %02d"%state.hole,Vector2(83,38),23)
	_text("PAR %d  ·  %s"%[state.par,state.title.capitalize()],Vector2(83,59),13)
	_text("%.1f m to pin"%distance,Vector2(22,98),15)
	# Two unobtrusive touch targets double as pointer controls. Gamepad uses shortcuts.
	for action in ["view","pause"]:
		var rect: Rect2 = regions()[action]; var center := rect.position+Vector2(23,19)
		draw_circle(center,19,Color(0.08,0.22,0.21,0.68))
		if action=="pause":
			draw_line(center+Vector2(-4,-6),center+Vector2(-4,6),PAPER,3,true)
			draw_line(center+Vector2(4,-6),center+Vector2(4,6),PAPER,3,true)
		else:
			draw_rect(Rect2(center-Vector2(10,6),Vector2(20,13)),PAPER,false,1.8)
			draw_circle(center,4,PAPER,false,1.6,true)
			draw_line(center+Vector2(-5,-8),center+Vector2(2,-8),PAPER,2,true)
		var caption: String = "PAUSE" if action=="pause" else "VIEW"
		if state.mode=="pad": caption=(state.back if action=="pause" else state.view_key)+" "+caption
		elif state.mode!="touch": caption="ESC" if action=="pause" else "TAB"
		var caption_width := font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
		_text(caption,rect.position+Vector2((46-caption_width)/2,49),10)
	for i in state.players:
		var active: bool = i==state.player
		var color := MINT if i==0 else CORAL
		var rect := Rect2(layout_size().x-176,86+i*50,160,44)
		_pill(rect,Color(0.08,0.22,0.21,0.80 if active else 0.50),22)
		var center := rect.position+Vector2(24,22)
		draw_circle(center,16,color)
		if active: draw_arc(center,19,0,TAU,32,PAPER,1.5,true)
		# Initials are placeholders, not a second avatar/wardrobe implementation.
		_text("M" if i==0 else "C",center+Vector2(-6,5),14,INK)
		_text(("MINT" if i==0 else "CORAL")+(" · YOU" if state.online and state.seat==i else ""),rect.position+Vector2(49,17),11)
		_text("%d strokes"%state.strokes[i],rect.position+Vector2(49,33),14)
		_text("Σ%d"%state.totals[i],rect.position+Vector2(128,28),16,color)
	if state.can_shoot:
		var y := layout_size().y-84
		_text("POWER",Vector2(24,y),12)
		_text("%03d°"%state.angle,Vector2(112,y),13)
		_text("%d%%"%state.power,Vector2(183,y),22)
		_pill(Rect2(22,y+10,222,14),Color(0.08,0.22,0.21,0.80),7)
		var fraction: float = state.power/100.0
		var color := MINT.lerp(Color("f2d68d"),fraction)
		_pill(Rect2(26,y+14,210*fraction,6),color,3)
		for i in range(1,10): draw_line(Vector2(26+i*21,y+12),Vector2(26+i*21,y+22),Color(0.06,0.20,0.17,0.4),1)
		draw_circle(Vector2(26+210*fraction,y+17),4,PAPER)
		if state.mode=="touch":
			var aim: Rect2 = regions().aim
			_pill(aim,Color(0.08,0.22,0.21,0.65),24)
			_text("‹     %03d°     ›"%state.angle,aim.position+Vector2(15,27),20)
			_text("DRAG TO AIM",aim.position+Vector2(34,45),10)
			var center: Vector2 = regions().putt.get_center()
			draw_circle(center,34,PAPER); draw_circle(center,30,MINT)
			_text("PUTT",center+Vector2(-21,6),17,INK)
			_text("Drag power · Pinch to zoom",Vector2(24,layout_size().y-24),12)
		else:
			var pad: bool = state.mode=="pad"
			_glyph(state.confirm if pad else "Click" if state.mode=="mouse" else "Enter",Vector2(266,y+2),28 if pad else 44)
			_text("PUTT",Vector2(304 if pad else 319,y+21),18)
			_text("L  Aim / power" if pad else "← →  Aim     ↑ ↓  Power",Vector2(24,layout_size().y-24),13)
			_text("R  Look   ·   LT/RT  Zoom" if pad else "WASD  Look   ·   Q/E  Zoom",Vector2(layout_size().x-228,layout_size().y-24),12)
	else:
		var message := status if not status.is_empty() else "Rolling…" if state.phase=="moving" else "Your friend is lining up a putt…"
		var extent := font.get_string_size(message,HORIZONTAL_ALIGNMENT_LEFT,-1,20)
		_pill(Rect2(Vector2((layout_size().x-extent.x)/2-18,layout_size().y-70),Vector2(extent.x+36,42)),Color(0.08,0.22,0.21,0.72),21)
		_text(message,Vector2((layout_size().x-extent.x)/2,layout_size().y-42),20)
