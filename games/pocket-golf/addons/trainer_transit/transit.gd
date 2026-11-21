# SPDX-License-Identifier: GPL-3.0-or-later
extends CanvasLayer
const GAME := "res://main.tscn"
const Party = preload("party.gd")
@export var destination: String
@export var location: String
@export var accent: Color
var screen: Control
var flight: SubViewportContainer
var artwork: TextureRect
var kicker: Label
var title: Label
var hint: Label
var credit: Label
var picture := "res://assets/transit/arrival.jpg"
var game: Node
var phase := ""
var flight_frames := 0
var since := 0
var attached_at := 0
var party := Party.new()
var awaiting_guest := false
var attach_pending := false

func _ready() -> void:
	layer=120
	process_mode=Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if destination=="Bazaar" and arg in ["--world=island","--world=station"]:
			var island:=arg=="--world=island"
			location="Mika’s Island" if island else "Ren’s Observatory"
			picture="res://assets/transit/arrival-island.jpg" if island else "res://assets/transit/arrival-station.jpg"
	_begin_flight()
	if ResourceLoader.load_threaded_request(GAME)!=OK:_load_error()

func _begin_flight() -> void:
	if screen==null:
		screen=ColorRect.new()
		screen.color=Color("101626")
		add_child(screen)
		screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		flight=load("res://addons/trainer_transit/flight.gd").new()
		screen.add_child(flight)
		flight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		artwork=TextureRect.new()
		screen.add_child(artwork)
		artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		artwork.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		artwork.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var shade:=TextureRect.new()
		var fade:=GradientTexture2D.new()
		fade.gradient=Gradient.new()
		fade.gradient.colors=PackedColorArray([Color("080e1a00"),Color("080e1af5")])
		fade.fill_from=Vector2(.5,.48)
		fade.fill_to=Vector2(.5,1.02)
		shade.texture=fade
		screen.add_child(shade)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		kicker=_label(13,32,-131)
		title=_label(36,30,-113)
		hint=_label(15,32,-53)
		credit=_label(13,0,-40)
		credit.anchor_left=1
		credit.offset_left=-165
		credit.offset_right=-28
		credit.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		credit.text="Made with Godot"
	flight.show()
	flight.set_process(true)
	flight.space.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	artwork.hide()
	kicker.text="E G R E G O R E"
	kicker.modulate=Color("b5e9e1")
	title.text=destination
	hint.text="Left stick  /  arrows     ·     Steer"
	phase="flight"
	flight_frames=0
	since=Time.get_ticks_msec()
	set_process_input(true)
	if game:game.set_transit_controls(true)

func _label(font_size: int, left: int, top: int) -> Label:
	var label:=Label.new()
	screen.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	label.offset_left=left
	label.offset_top=top
	label.offset_bottom=top+font_size*1.5
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_shadow_color",Color("101828"))
	label.add_theme_constant_override("shadow_offset_y",1)
	return label

func _process(delta: float) -> void:
	var now:=Time.get_ticks_msec()
	var flying:=phase=="flight"
	if flying:flight_frames+=1
	if party.bridge:
		party.tick(delta,flying,flight.drift if flying else Vector2.ZERO)
		if flying:flight.set_party(party.roster,party.own,party.poses)
	if phase=="error" or phase=="idle":return
	if not game:
		if attach_pending:return
		var state:=ResourceLoader.load_threaded_get_status(GAME)
		if state==ResourceLoader.THREAD_LOAD_FAILED or state==ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_load_error()
		elif state==ResourceLoader.THREAD_LOAD_LOADED and now-since>=500:
			attach_pending=true
			_attach_game.call_deferred()
		return
	if flying and flight_frames>=12 and now-since>=(4500 if not party.own.is_empty() else 2100):
		_arrive()
	elif phase=="arrival" and now-since>=850:
		if game.transit_avatar_ready():
			_reveal()
		elif not awaiting_guest and now-attached_at>=10000:
			awaiting_guest=true
			hint.text="Waiting for character   ·   A / Enter to continue as guest"

func _attach_game() -> void:
	var scene:PackedScene=ResourceLoader.load_threaded_get(GAME)
	if not scene:
		_load_error()
		return
	game=scene.instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene=game
	get_tree().root.move_child(self,-1)
	game.tree_exiting.connect(queue_free)
	game.set_transit_controls(true)
	attached_at=Time.get_ticks_msec()
	var session:Node=game.transit_session()
	if session:
		party.bind(session)
		party.bridge.session_ready.connect(_on_session)
		if not party.bridge.session.is_empty():_on_session(false)

func _on_session(_host: bool) -> void:
	party.admit()
	if party.own.is_empty():return
	_begin_flight()

func _arrive() -> void:
	phase="arrival"
	since=Time.get_ticks_msec()
	flight.hide()
	flight.set_process(false)
	flight.space.render_target_update_mode=SubViewport.UPDATE_DISABLED
	artwork.texture=load(picture)
	artwork.show()
	kicker.text=destination.to_upper()
	kicker.modulate=accent
	title.text=location
	hint.text="Arriving…" if game.transit_avatar_ready() else "Preparing your character…"

func _reveal() -> void:
	game.set_transit_controls(false)
	screen.queue_free()
	screen=null
	flight=null
	phase="idle"
	awaiting_guest=false
	set_process_input(false)
	# Keep the small lobby listener for a session admitted from the game's menu.
	print("Egregore arrival complete: ",destination)
	if not party.bridge:queue_free()

func _load_error() -> void:
	phase="error"
	title.text="Could not load "+destination
	hint.text="A / Enter to retry"
	push_error(title.text)

func _input(event: InputEvent) -> void:
	if phase=="idle":return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_accept") or (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_A):
		if phase=="error":get_tree().reload_current_scene()
		elif phase=="arrival" and awaiting_guest:_reveal()
