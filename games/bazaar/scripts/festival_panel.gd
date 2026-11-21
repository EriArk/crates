# SPDX-License-Identifier: GPL-3.0-or-later
extends PanelContainer
signal closed
var world: Node
var ground: Node3D
var cup=preload("festival_client.gd").new()
var headline:=Label.new()
var info:=Label.new()
var actions:=HBoxContainer.new()
var play:=Button.new()
var join:=Button.new()
var lobby:=Button.new()
var back:=Button.new()
var mode:=""
var best:=0
var local_pid:=-1
var receipt:=""
var local_line:=""
var last_board:={}
var called:=""
var timer:=0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_left=24;offset_right=-24;offset_top=-147;offset_bottom=-17
	var style: StyleBoxFlat=world.backdrop()
	style.bg_color=Color("183c40f2")
	style.border_color=Color("e7bc78")
	style.border_width_top=3
	add_theme_stylebox_override("panel",style)
	var column:=VBoxContainer.new()
	add_child(column)
	headline.add_theme_font_size_override("font_size",22)
	headline.modulate=Color("ffdc9b")
	column.add_child(headline);column.add_child(info);column.add_child(actions)
	for item in [play,join,lobby,back]:
		world.dress_button(item);actions.add_child(item)
		item.custom_minimum_size=Vector2(0,38)
	play.pressed.connect(_play)
	join.pressed.connect(func():cup.action("leave" if cup.snapshot.get("joined",false) else "join"))
	lobby.text="Open Lobby"
	lobby.pressed.connect(func():cup.action("lobby"))
	back.text="Back"
	back.pressed.connect(close)
	ground.landed.connect(_refresh)
	ground.launched.connect(cup.toss)
	cup.other_toss.connect(ground.show_other)
	cup.state_changed.connect(_cup_changed)
	add_child(cup)
	hide()

func open(kind: String) -> void:
	world.visitor.anchor.hide()
	mode=kind
	show()
	if mode=="rings":
		ground.begin()
		world.service_camera.global_position=ground.STALL+Vector3(0,2.75,3.45)
		world.service_camera.look_at(ground.STALL+Vector3(0,.98,0))
	else:
		world.service_camera.global_position=ground.ARENA+Vector3(0,2.0,5.1)
		world.service_camera.look_at(ground.ARENA+Vector3(0,1.5,-2.6))
	world.service_camera.fov=43
	world.service_camera.make_current()
	_refresh()
	if mode=="rings":play.grab_focus()
	elif not play.disabled:play.grab_focus()
	elif not join.disabled:join.grab_focus()
	else:back.grab_focus()

func _cup_changed() -> void:
	var snap:Dictionary=cup.snapshot
	var ticket:String=snap.get("ticket","")
	var result:Dictionary=snap.get("board",{})
	if not result.is_empty():
		last_board=result
	elif not cup.available or (not ticket.is_empty() and ticket!=called):
		last_board={}
	if not ticket.is_empty() and ticket!=called:
		called=ticket
		_return_to_desk()
	if not last_board.is_empty():ground.board.text=_result(last_board)
	elif not local_line.is_empty():ground.board.text=local_line
	else:ground.board.text="POCKET GOLF   /   3 HOLES"
	if visible:_refresh()

func _result(result: Dictionary) -> String:
	var strokes:Array=result.get("strokes",[])
	if strokes.size()==2:
		return "%s   /   Mint %d   ·   Coral %d"%[str(result.state).to_upper(),strokes[0],strokes[1]]
	if result.get("state")!="confirmed":return "CUP RESULT  ·  "+str(result.get("state","pending")).to_upper()
	var rows: Array=result.get("rows",[])
	var lines:=PackedStringArray()
	for row in rows:lines.append("#%d  %s  %d"%[int(row.place),row.get("name",""),int(row.score)])
	return "CONFIRMED   /   "+"     ".join(lines)

func _refresh() -> void:
	join.visible=mode=="arena"
	lobby.visible=mode=="arena" and cup.available
	play.disabled=false
	if mode=="rings":
		headline.text="WANAGE    /    %d POINTS"%ground.score
		info.text="Aim with the left stick or arrows    ·    %d of 3 thrown"%ground.thrown
		if ground.thrown>0 and not ground.flying:info.text+=("    ·    +%d points"%ground.last_points if ground.last_points else "    ·    Miss")
		if ground.thrown==3 and not ground.flying:
			best=maxi(best,ground.score)
			info.text="Round complete    ·    Best this visit  %d"%best
		play.text="Play again" if ground.thrown==3 and not ground.flying else "Throw ring"
		play.disabled=ground.flying
		return
	headline.text="FESTIVAL CUP    /    POCKET GOLF"
	var rows:=PackedStringArray()
	for m in cup.snapshot.get("members",[]):rows.append(str(m.name)+(" ✓" if m.ready and cup.snapshot.get("cup",false) else ""))
	var status:String=cup.message
	if status.is_empty():status="  ·  ".join(rows) if not rows.is_empty() else "Form a two-player party in Lobby."
	if not last_board.is_empty():status=_result(last_board)
	elif not local_line.is_empty():status=local_line+"    "+status
	info.text=status
	if not last_board.is_empty() and not local_line.is_empty():info.text+="   ·   "+local_line
	play.text="Play on this device"
	play.disabled=_golf_path().is_empty() or local_pid>0 or cup.snapshot.get("joined",false)
	join.text="Withdraw" if cup.snapshot.get("joined",false) else "Enter online cup"
	join.disabled=not cup.available or local_pid>0 or cup.snapshot.get("phase","") in ["launching","playing"]

func _golf_path() -> String:
	var path:=OS.get_environment("TRAINEROS_FESTIVAL_GOLF")
	if path.is_empty():
		path=OS.get_environment("HOME").path_join(".local/share/traineros-development/pocket-golf-art-preview/current/launch")
	return path if path.is_absolute_path() and FileAccess.file_exists(path) and not OS.get_environment("XDG_RUNTIME_DIR").is_empty() else ""

func _play() -> void:
	if mode=="rings":
		if ground.thrown==3 and not ground.flying:ground.begin()
		else:ground.toss()
		_refresh()
		return
	if local_pid>0 or _golf_path().is_empty():return
	var ticket:=Crypto.new().generate_random_bytes(16).hex_encode()
	receipt=OS.get_environment("XDG_RUNTIME_DIR").path_join("festival-"+ticket+".json")
	local_pid=OS.create_process(_golf_path(),["--","--festival-pair="+ticket])
	local_line="Local cup in progress" if local_pid>0 else "Pocket Golf could not start."
	_refresh()

func _return_to_desk() -> void:
	if visible:close()
	elif world.modal:world.hide_menu()
	world.visitor.enter_space(ground.ARENA+Vector3(0,.2,1.2),0)

func _process(delta: float) -> void:
	if visible and mode=="rings":
		var axis:=Input.get_vector("ui_left","ui_right","ui_up","ui_down")
		var pads:=Input.get_connected_joypads()
		if not pads.is_empty():
			var stick:=Vector2(Input.get_joy_axis(pads[0],JOY_AXIS_LEFT_X),Input.get_joy_axis(pads[0],JOY_AXIS_LEFT_Y))
			if stick.length()>.15:axis=stick
		ground.move_aim(axis,delta)
	if local_pid<=0:return
	timer-=delta
	if timer>0:return
	timer=.25
	if OS.is_process_running(local_pid):return
	local_pid=-1
	local_line="Local cup ended without a score."
	var file:=FileAccess.open(receipt,FileAccess.READ)
	if file and file.get_length()<1024:
		var result=JSON.parse_string(file.get_as_text())
		if result is Array and result.size()==2 and result.all(func(n):return typeof(n) in [TYPE_INT,TYPE_FLOAT] and n==int(n) and n>=3 and n<=99):
			local_line="LOCAL CUP    Mint %d   /   Coral %d"%[result[0],result[1]]
	if file:
		file.close()
		DirAccess.remove_absolute(receipt)
	ground.board.text=local_line
	_return_to_desk()
	world.show_menu()
	world.panel.hide()
	open("arena")

func _input(event: InputEvent) -> void:
	if not visible or mode!="rings":return
	if event is InputEventScreenDrag:
		ground.move_aim(event.relative*.009,1.0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_A):
		if back.has_focus():close()
		else:_play()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.physical_keycode in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:
		get_viewport().set_input_as_handled()

func close() -> void:
	if mode=="rings":ground.end()
	mode=""
	hide()
	closed.emit()
