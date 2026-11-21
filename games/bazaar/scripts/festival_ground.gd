# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
const STALL := Vector3(7.45,0,23.6)
const ARENA := Vector3(23,0,22)
const TARGETS := [Vector2(-.75,-.24),Vector2(.06,.20),Vector2(.75,-.32)]
const AWARDS := [2,1,3]
const DECK := .80
const SCALE := 1.6
const BOARD := Vector3(0,0,-1.4)
const HAND := Vector3(.25,1.41,2.85)
const PEG_HEIGHT := .34
const GRAVITY := 9.8
const SETTLE_TIME := .18
const Trim = preload("festival_trim.gd")
var gallery := preload("toy_gallery.gd").new()
var board: Label3D
var cursor: MeshInstance3D
var rings: Array[MeshInstance3D] = []
var torus := TorusMesh.new()
var aim := Vector2.ZERO
var endpoint := Vector2.ZERO
var catch_time := 0.0
var rest_time := 0.0
var elapsed := 0.0
var clock := 0.0
var active := false
var flying := false
var awaiting_throw := false
var caught_visual := false
var thrown := 0
var score := 0
var last_points := 0
var last_remote_throw := -1000
signal launched(at: Vector2)
signal landed

func piece(mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=color
	node.mesh=mesh
	node.material_override=mat
	node.position=pos
	add_child(node)
	return node

func build(s) -> void:
	add_child(gallery)
	gallery.build(s)
	s.path(ARENA,Vector3(15,0,12))
	s.path(Vector3(14,0,20),Vector3(15,0,3))
	for side in [-1,1]:
		for row in 2:
			s.block(ARENA+Vector3(side*(5.9+row*.65),.26+row*.19,0),Vector3(.56,.5+row*.38,7),"986748")
		s.model("banner-red",ARENA+Vector3(side*3,0,4.3),Vector3.ONE*2.7)
	s.block(ARENA+Vector3(0,1.58,-3.7),Vector3(6.4,2.6,.25),"25444a")
	for x in [-3.25,3.25]:
		s.block(ARENA+Vector3(x,1.53,-3.7),Vector3(.18,3.06,.35),"a0744a")
	Trim.valance(s,ARENA+Vector3(0,3.07,-3.7),6.75,["365762","a1604f","365762"],12)
	s.text3d("FESTIVAL CUP",ARENA+Vector3(0,2.43,-3.54),.011)
	board=s.text3d("POCKET GOLF   /   3 HOLES",ARENA+Vector3(0,1.52,-3.53),.0075)
	board.modulate=Color("f6d395")
	s.block(ARENA+Vector3(0,.49,-1.4),Vector3(2.65,.98,.74),"a56b47")
	s.destinations.append({"title":"Festival Cup","festival":"arena","position":ARENA+Vector3(0,0,-.55)})
	var deck:=STALL+BOARD
	s.block(deck+Vector3.UP*((DECK-.07)*.5),Vector3(4.6,DECK-.07,3.54),"834e43")
	s.block(deck+Vector3.UP*(DECK-.035),Vector3(4.76,.07,3.68),"477d79")
	for x in [-2.31,2.31]:
		s.block(deck+Vector3(x,DECK+.015,0),Vector3(.09,.075,3.7),"ecc895",false)
		s.block(deck+Vector3(x,1.39,-1.79),Vector3(.13,2.78,.14),"83503f")
		s.lantern(deck+Vector3(x,2.43,-1.54),"ed9d70")
	for z in [-1.8,1.8]:
		s.block(deck+Vector3(0,DECK+.015,z),Vector3(4.7,.075,.09),"ecc895",false)
	Trim.landscape(s,deck+Vector3(0,1.54,-1.76),Vector2(4.52,1.46),true)
	s.block(deck+Vector3(0,2.51,-1.80),Vector3(4.7,.43,.13),"354754",false)
	s.text3d("WANAGE",deck+Vector3(0,2.51,-1.72),.0074)
	Trim.valance(s,deck+Vector3(0,2.91,-1.80),4.95,["447671","34636a","b8755a"],10)
	for i in TARGETS.size():
		var pin:=CylinderMesh.new()
		pin.top_radius=.060*SCALE
		pin.bottom_radius=pin.top_radius
		pin.height=PEG_HEIGHT
		var p:=board_point(TARGETS[i])
		var dye:Color=[Color("c56a4b"),Color("eed197"),Color("6174a2")][i]
		piece(pin,dye,p+Vector3.UP*(PEG_HEIGHT*.5))
		var collar:=CylinderMesh.new()
		collar.top_radius=pin.top_radius+.001;collar.bottom_radius=collar.top_radius;collar.height=.047
		piece(collar,Color("f6da9e"),p+Vector3.UP*(PEG_HEIGHT-.055))
		var medallion:=CylinderMesh.new()
		medallion.top_radius=.34;medallion.bottom_radius=.34;medallion.height=.008
		piece(medallion,dye.darkened(.16),p+Vector3.UP*.005)
		s.text3d(str(AWARDS[i]),p+Vector3(0,.03,.43),.0042).rotation.x=-PI*.42
	torus.inner_radius=.15*SCALE
	torus.outer_radius=.191*SCALE
	torus.rings=32
	torus.ring_segments=8
	cursor=piece(torus,Color("62cbd0"),STALL)
	cursor.hide()
	s.destinations.append({"title":"Throw festival rings","festival":"rings","position":STALL+Vector3(0,0,1.45)})

func begin() -> void:
	end()
	active=true
	thrown=0
	score=0
	last_points=0
	aim=Vector2(-.33,.48)
	clock=0
	cursor.show()
	_update_cursor()

func end() -> void:
	active=false
	flying=false
	awaiting_throw=false
	if cursor:cursor.hide()
	for ring in rings:ring.queue_free()
	rings.clear()

func move_aim(direction: Vector2,delta: float) -> void:
	if active and not flying and thrown<3:
		aim=(aim+direction.limit_length()*delta*1.6).clamp(Vector2(-1.17,-.66),Vector2(1.17,.65))

func _update_cursor() -> void:
	endpoint=(aim+Vector2(.043*sin(clock*2.1),.215*sin(clock*2.8))).clamp(Vector2(-1.24,-.79),Vector2(1.24,.79))
	cursor.position=board_point(endpoint)+Vector3.UP*(PEG_HEIGHT+.016)

func board_point(at: Vector2) -> Vector3:
	return STALL+BOARD+Vector3(at.x*SCALE,DECK,at.y*SCALE)

func time_to_pin(at: Vector2) -> float:
	return (board_point(at)-STALL-HAND).length()*.12+.25

func pin_velocity(at: Vector2, duration: float, hand: Vector3) -> Vector3:
	var displacement:=board_point(at)+Vector3.UP*PEG_HEIGHT-(STALL+hand)
	return displacement/duration+Vector3.UP*(.5*GRAVITY*duration)

func flight_point(at: Vector2, time: float, duration: float, caught: bool, hand: Vector3) -> Vector3:
	var velocity:=pin_velocity(at,duration,hand)
	var point:=STALL+hand+velocity*time+Vector3.DOWN*(.5*GRAVITY*time*time)
	if caught and time>=duration:
		var peg:=board_point(at)
		point.x=peg.x;point.z=peg.z
	return point

func time_to_deck(at: Vector2, duration: float) -> float:
	var vy:=pin_velocity(at,duration,HAND).y
	return (vy+sqrt(vy*vy+2.0*GRAVITY*(HAND.y-DECK-.04)))/GRAVITY

func pose_ring(ring: MeshInstance3D, at: Vector2, time: float, duration: float, landing: float, caught: bool, hand: Vector3, stack: int) -> void:
	ring.position=flight_point(at,minf(time,landing),duration,caught,hand)
	var pitch:=sin(PI*minf(time/duration,1.0))*.32
	if time>landing:
		var settle:=clampf((time-landing)/SETTLE_TIME,0,1)
		var bounce:=sin(PI*settle)*(1.0-settle)
		ring.position.y+=bounce*(.028 if caught else .12)
		pitch+=bounce*(.12 if caught else .54)
		if not caught:ring.position.z-=.11*settle
	ring.position.y=maxf(ring.position.y,STALL.y+DECK+.045+stack*.008)
	ring.rotation=Vector3(pitch,TAU*time*1.7,0)

func restore(attempts: Array) -> void:
	begin()
	for shot in attempts:
		endpoint=Vector2(shot.x,shot.y)/100.0
		last_points=int(shot.points)
		var ring:=piece(torus,Color("ffbd59"),STALL)
		rings.append(ring)
		var duration:=time_to_pin(endpoint)
		var landing:=time_to_deck(endpoint,duration)
		pose_ring(ring,endpoint,landing+SETTLE_TIME,duration,landing,last_points>0,HAND,thrown)
		thrown+=1
		score+=last_points
	cursor.visible=thrown<3

func catches(at: Vector2) -> bool:
	# The backend receives centimetres. The hole radius minus the pin radius is 9 cm in board space.
	var cm:=Vector2i(roundi(at.x*100),roundi(at.y*100))
	for pin:Vector2 in TARGETS:
		var center:=Vector2i(roundi(pin.x*100),roundi(pin.y*100))
		if cm.distance_squared_to(center)<=81:return true
	return false

func start_throw(at: Vector2) -> void:
	if not active or flying or thrown>=3:return
	endpoint=Vector2(roundi(at.x*100),roundi(at.y*100))/100
	awaiting_throw=true
	caught_visual=catches(endpoint)
	last_points=0
	launched.emit(endpoint)
	thrown+=1
	rings.append(piece(torus,Color("ffbd59"),STALL+HAND))
	catch_time=time_to_pin(endpoint)
	rest_time=time_to_deck(endpoint,catch_time)
	flying=true;elapsed=0.0
	cursor.hide()

func confirm_throw(shot: Dictionary) -> void:
	awaiting_throw=false
	last_points=int(shot.points)
	caught_visual=last_points>0
	if not flying:
		score+=last_points
		cursor.visible=thrown<3
		landed.emit()

func _process(delta: float) -> void:
	if not active:return
	clock+=delta
	if not flying:
		if thrown<3 and not awaiting_throw:_update_cursor()
		return
	elapsed+=delta
	pose_ring(rings.back(),endpoint,elapsed,catch_time,rest_time,caught_visual,HAND,thrown-1)
	if elapsed<rest_time+SETTLE_TIME:return
	flying=false
	if awaiting_throw:return
	score+=last_points
	cursor.visible=thrown<3
	landed.emit()

func show_other(at: Vector2) -> void:
	var now:=Time.get_ticks_msec()
	if at.abs().x>1.3 or at.abs().y>.8 or now-last_remote_throw<450:return
	last_remote_throw=now
	var caught:=catches(at)
	var duration:=time_to_pin(at)
	var landing:=time_to_deck(at,duration)
	var ring:=piece(torus,Color("8ed7de"),STALL+HAND)
	var tween:=ring.create_tween()
	tween.tween_method(func(t:float):pose_ring(ring,at,t,duration,landing,caught,HAND,0),0.0,landing+SETTLE_TIME,landing+SETTLE_TIME)
	tween.tween_interval(1.2)
	tween.tween_callback(ring.queue_free)
