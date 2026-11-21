# SPDX-License-Identifier: GPL-3.0-or-later
extends PanelContainer
signal closed
var world: Node
var ground: Node3D
var wallet=preload("festival_wallet.gd").new()
var focus_ticket:=false
var displayed:=""
var trigger_held:=false
var local_starting:=false
var cup=preload("festival_client.gd").new()
var headline:=Label.new()
var info:=Label.new()
var tally:=HBoxContainer.new()
var compact_row:=HBoxContainer.new()
var column:=VBoxContainer.new()
var actions:=HBoxContainer.new()
var play:=Button.new()
var join:=Button.new()
var lobby:=Button.new()
var bag:=Button.new()
var back:=Button.new()
var mode:=""
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
	add_child(column)
	headline.add_theme_font_size_override("font_size",22)
	headline.modulate=Color("ffdc9b")
	var heading:=HBoxContainer.new()
	column.add_child(heading)
	headline.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	heading.add_child(headline);heading.add_child(tally)
	tally.alignment=BoxContainer.ALIGNMENT_END
	tally.add_theme_constant_override("separation",6)
	for i in 5:
		var marker:=ColorRect.new()
		marker.custom_minimum_size=Vector2(22,8)
		marker.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		marker.mouse_filter=Control.MOUSE_FILTER_IGNORE
		tally.add_child(marker)
	column.add_child(compact_row)
	compact_row.add_theme_constant_override("separation",12)
	column.add_child(info);column.add_child(actions)
	info.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	actions.alignment=BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation",8)
	for item in [play,join,lobby,bag,back]:
		world.dress_button(item);actions.add_child(item)
		item.custom_minimum_size=Vector2(78,38)
		for state in ["normal","hover","pressed","focus"]:
			var box=item.get_theme_stylebox(state)
			box.content_margin_left=9;box.content_margin_right=9
	play.pressed.connect(_play)
	join.pressed.connect(_online)
	lobby.text="Open Lobby"
	lobby.pressed.connect(func():cup.action("lobby"))
	bag.text="View prize bag"
	bag.pressed.connect(func():wallet.checkout({"action":"inventory"}))
	back.text="Back"
	back.pressed.connect(close)
	ground.landed.connect(_refresh)
	ground.launched.connect(cup.toss)
	cup.other_toss.connect(ground.show_other)
	cup.state_changed.connect(_cup_changed)
	add_child(cup)
	wallet.changed.connect(_wallet_changed)
	wallet.recorded.connect(_recorded)
	add_child(wallet)
	hide()

func open(kind: String) -> void:
	world.visitor.anchor.hide()
	mode=kind
	var compact:=kind in ["gallery","rings"]
	var controls:Container=compact_row if compact else column
	if info.get_parent()!=controls:
		info.reparent(controls,false);actions.reparent(controls,false)
	compact_row.visible=compact
	offset_top=-111 if compact else -147
	show()
	displayed=""
	focus_ticket=true
	local_starting=false
	if mode=="gallery":
		ground.gallery.begin(world.service_camera)
	elif mode=="rings":
		world.service_camera.global_position=ground.STALL+Vector3(.12,2.95,4.32)
		world.service_camera.look_at(ground.STALL+ground.BOARD+Vector3(0,.82,.0))
	else:
		world.service_camera.global_position=ground.ARENA+Vector3(0,2.0,5.1)
		world.service_camera.look_at(ground.ARENA+Vector3(0,1.5,-2.6))
	if mode!="gallery":world.service_camera.fov=43
	world.service_camera.make_current()
	wallet.select("" if mode=="arena" else mode)
	_refresh()
	if not play.disabled:play.grab_focus()
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
	bag.visible=false
	tally.visible=false
	join.visible=mode=="arena"
	lobby.visible=mode=="arena" and cup.available
	play.disabled=false
	if mode in ["gallery","rings","golf_local","golf_online"]:
		_ticket_view()
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
	play.text="Local pair · tickets"
	play.disabled=_golf_path().is_empty() or local_pid>0 or cup.snapshot.get("joined",false)
	join.text="Withdraw" if cup.snapshot.get("joined",false) else "Online entry · tickets"
	join.disabled=not cup.available or local_pid>0 or cup.snapshot.get("phase","") in ["launching","playing"] or (not cup.snapshot.get("joined",false) and not _online_ready())

func _golf_path() -> String:
	var path:=OS.get_environment("TRAINEROS_FESTIVAL_GOLF")
	if path.is_empty():
		path=OS.get_environment("HOME").path_join(".local/share/traineros-development/pocket-golf-art-preview/current/launch")
	return path if path.is_absolute_path() and FileAccess.file_exists(path) and not OS.get_environment("XDG_RUNTIME_DIR").is_empty() else ""

func _online_ready() -> bool:
	return wallet.endpoint_override.is_empty() and cup.snapshot.get("installed",false) and cup.snapshot.get("members",[]).size()==2 and cup.snapshot.get("phase","") in ["choosing","gathering"]

func _online() -> void:
	if cup.snapshot.get("joined",false):cup.action("leave")
	elif _online_ready():open("golf_online")

func _wallet_changed() -> void:
	if not visible or mode!=wallet.game:return
	var ticket:Dictionary=wallet.ticket()
	if mode=="gallery":
		if wallet.offer.has("won"):ground.gallery.show_collection(wallet.offer.won)
		var won_index=ground.gallery.Plush.NAMES.find(ticket.get("prize"))
		if won_index>=0:ground.gallery.ribbons[won_index].show()
	var history:Array=ticket.get("attempts",[])
	var stamp:="%s/%d"%[ticket.get("id",""),history.size()]
	if displayed!=stamp:
		displayed=stamp
		if mode=="gallery":ground.gallery.restore(history)
		if mode=="rings":
			if ticket.is_empty():ground.end()
			else:ground.restore(history)
	_refresh()
	if focus_ticket and not wallet.offer.is_empty() and not play.disabled:
		focus_ticket=false
		play.grab_focus()

func _recorded(kind: String, value: Dictionary) -> void:
	if not visible or mode!=kind:return
	var r:Dictionary=value["round"]
	var shots:Array=r.attempts
	if kind=="gallery":
		displayed="%s/%d"%[r.id,shots.size()]
		ground.gallery.settle(shots,world.effects_toggle.button_pressed)
	if kind=="rings" and ground.active:
		if ground.thrown==shots.size()-1:
			ground.start_throw(Vector2(shots.back().x,shots.back().y)/100)
		if ground.thrown==shots.size() and ground.awaiting_throw:
			displayed="%s/%d"%[r.id,shots.size()]
			ground.confirm_throw(shots.back())
	if kind=="golf_local" and local_starting and _local_reserved():
		local_starting=false
		_launch_local()

func _reservation_path() -> String:
	return "user://cup-"+str(wallet.offer.get("player_id","")).sha256_text()+".txt"

func _local_reserved() -> bool:
	if mode!="golf_local" or wallet.ticket().is_empty():return false
	return FileAccess.file_exists(_reservation_path()) and FileAccess.get_file_as_string(_reservation_path())==wallet.ticket().id

func _ticket_view() -> void:
	var titles:={"gallery":"TOY GALLERY","rings":"WANAGE","golf_local":"FESTIVAL CUP   /   LOCAL PAIR","golf_online":"FESTIVAL CUP   /   ONLINE"}
	var rules:={"gallery":"5 shots · Knock down 3 different toys to keep the third.","rings":"3 rings · Land on a peg for 1, 2 or 3 points.","golf_local":"Two players share one controller for three holes.","golf_online":"One ticket per player for the three-hole cup."}
	headline.text=titles[mode]
	info.text=rules[mode]
	var r:Dictionary=wallet.ticket()
	var shots:Array=r.get("attempts",[])
	if mode in ["gallery","rings"] and not r.is_empty():
		tally.show()
		for i in 5:
			var marker:ColorRect=tally.get_child(i)
			marker.visible=i<int(wallet.offer.limit)
			marker.color=Color("668783") if i>=shots.size() else (Color("f8bd64") if int(shots[i].points)>0 else Color("b66e68"))
	var price:int=int(wallet.offer.get("price",10))
	var busy:bool=not wallet.pending.is_empty() or (mode=="rings" and ground.flying)
	var paid:bool=not r.is_empty() and (not r.complete or _local_reserved())
	play.disabled=busy
	if not r.is_empty() and mode in ["gallery","rings"]:
		var points:=0
		for shot in shots:points+=int(shot.points)
		headline.text+="   /   %d %s"%[points,"HITS" if mode=="gallery" else "POINTS"]
		if paid:info.text=("Lead the moving toys · Right stick / R2" if mode=="gallery" else "Move with left stick · A when the ring aligns")+"    ·    %d / %d left"%[int(wallet.offer.limit)-shots.size(),int(wallet.offer.limit)]
		else:info.text="Round complete"
		if r.get("prize"):
			info.text+="    ·    Won %s!"%r.prize
			bag.visible=true
			bag.disabled=busy
	if wallet.offer.get("checkout_pending",false):play.text="Resolve payment"
	elif paid:
		play.text={"gallery":"Shoot","rings":"Throw ring","golf_local":"Start cup","golf_online":"Join cup"}[mode]
		play.disabled=busy or (mode=="golf_local" and local_pid>0) or (mode=="golf_online" and not _online_ready()) or (mode=="golf_local" and _golf_path().is_empty())
	elif wallet.offer.is_empty():
		play.text="Check tickets"
		play.disabled=busy
	else:
		play.text=("Play again" if not r.is_empty() else "Buy ticket")+" · %d Sparks"%price
		play.disabled=busy or (mode=="golf_local" and local_pid>0) or not wallet.offer.get("payments_available",false) or (mode=="golf_online" and not _online_ready())
		if not wallet.offer.get("payments_available",false):info.text+="    ·    Ticket sales closed"
	if not wallet.message.is_empty():info.text=wallet.message if not paid else info.text+"    ·    "+wallet.message
	if wallet.offer.is_empty():headline.text+="   /   TICKETS"
	if not wallet.endpoint_override.is_empty():headline.text+="   /   TEST SPARKS"

func _play() -> void:
	if not visible or play.disabled:return
	if mode=="arena":
		open("golf_local")
		return
	if wallet.offer.is_empty():
		wallet.select(mode)
		return
	if mode=="golf_local" and _local_reserved() and wallet.ticket().complete:
		_launch_local()
		return
	if not wallet.playable() or wallet.offer.get("checkout_pending",false):
		wallet.buy()
		return
	if mode=="gallery":
		if not ground.gallery.in_flight and wallet.submit(ground.gallery.ticket_impact()):ground.gallery.volley(ground.gallery.aim,world.effects_toggle.button_pressed)
	elif mode=="rings":
		if wallet.submit(ground.endpoint):ground.start_throw(ground.endpoint)
	elif mode=="golf_local":
		if _golf_path().is_empty():return
		var reservation:=FileAccess.open(_reservation_path(),FileAccess.WRITE)
		if not reservation:
			wallet.message="Could not save cup entry.";_refresh();return
		reservation.store_string(wallet.ticket().id)
		reservation.close()
		local_starting=wallet.submit(Vector2.ZERO)
	elif mode=="golf_online" and _online_ready():
		cup.action("join")
		open("arena")

func _launch_local() -> void:
	if local_pid>0 or _golf_path().is_empty():return
	var ticket:=Crypto.new().generate_random_bytes(16).hex_encode()
	receipt=OS.get_environment("XDG_RUNTIME_DIR").path_join("festival-"+ticket+".json")
	local_pid=OS.create_process(_golf_path(),["--","--festival-pair="+ticket])
	if local_pid>0:DirAccess.remove_absolute(_reservation_path())
	local_line="Local cup in progress" if local_pid>0 else "Pocket Golf could not start."
	_refresh()

func _return_to_desk() -> void:
	if visible:close()
	elif world.modal:world.hide_menu()
	world.visitor.enter_space(ground.ARENA+Vector3(0,.2,1.2),0)

func _process(delta: float) -> void:
	if visible and mode=="gallery":
		var axis:=Input.get_vector("ui_left","ui_right","ui_up","ui_down")
		var pads:=Input.get_connected_joypads()
		if not pads.is_empty():
			var stick:=Vector2(Input.get_joy_axis(pads[0],JOY_AXIS_RIGHT_X),Input.get_joy_axis(pads[0],JOY_AXIS_RIGHT_Y))
			if stick.length()>.14:axis=stick
			var pressed:=Input.get_joy_axis(pads[0],JOY_AXIS_TRIGGER_RIGHT)>.55
			if pressed and not trigger_held and wallet.playable():_play()
			trigger_held=pressed
		ground.gallery.point(ground.gallery.aim+Vector2(axis.x,-axis.y)*delta*1.85)
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
	if not visible or mode not in ["gallery","rings"] or not wallet.playable():return
	if mode=="gallery":
		if event is InputEventMouseMotion or event is InputEventScreenDrag:
			if event.position.y<global_position.y:ground.gallery.pointer(world.service_camera,event.position)
		elif (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
			if event.position.y<global_position.y:
				ground.gallery.pointer(world.service_camera,event.position)
				_play()
				get_viewport().set_input_as_handled()
		return
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
	if mode=="gallery":ground.gallery.end()
	wallet.select("")
	mode=""
	hide()
	closed.emit()
