# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
const STALL := Vector3(7.45,0,20)
const ARENA := Vector3(23,0,22)
const TARGETS := [Vector2(-.75,-.24),Vector2(.06,.20),Vector2(.75,-.32)]
const AWARDS := [2,1,3]
const DECK := .97
var board: Label3D
var cursor: MeshInstance3D
var rings: Array[MeshInstance3D] = []
var torus := TorusMesh.new()
var aim := Vector2.ZERO
var endpoint := Vector2.ZERO
var elapsed := 0.0
var clock := 0.0
var active := false
var flying := false
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
	s.path(ARENA,Vector3(15,0,12))
	s.path(Vector3(14,0,20),Vector3(15,0,3))
	for side in [-1,1]:
		for row in 2:
			s.block(ARENA+Vector3(side*(5.9+row*.65),.26+row*.19,0),Vector3(.56,.5+row*.38,7),"986748")
		s.model("banner-red",ARENA+Vector3(side*3,0,4.3),Vector3.ONE*2.7)
	s.block(ARENA+Vector3(0,1.58,-3.7),Vector3(6.4,2.6,.25),"25444a")
	for x in [-3.25,3.25]:
		s.block(ARENA+Vector3(x,1.53,-3.7),Vector3(.18,3.06,.35),"a0744a")
	s.text3d("FESTIVAL CUP",ARENA+Vector3(0,2.43,-3.54),.011)
	board=s.text3d("POCKET GOLF   /   3 HOLES",ARENA+Vector3(0,1.52,-3.53),.0075)
	board.modulate=Color("f6d395")
	s.block(ARENA+Vector3(0,.49,-1.4),Vector3(2.65,.98,.74),"a56b47")
	s.destinations.append({"title":"Festival Cup","festival":"arena","position":ARENA+Vector3(0,0,-.55)})
	s.block(STALL+Vector3(0,DECK*.5,0),Vector3(2.65,DECK,1.55),"8b5640")
	s.block(STALL+Vector3(0,DECK-.035,0),Vector3(2.78,.07,1.66),"efd196")
	for x in [-1.47,1.47]:
		s.block(STALL+Vector3(x,1.32,-.68),Vector3(.11,2.64,.11),"75543e")
		s.lantern(STALL+Vector3(x,2.32,.02),"f4bc73")
	s.block(STALL+Vector3(0,2.64,-.67),Vector3(3.2,.52,.23),"a74940")
	s.text3d("WANAGE   /   RING TOSS",STALL+Vector3(0,2.65,-.537),.005)
	for i in TARGETS.size():
		var pin:=CylinderMesh.new()
		pin.top_radius=.047
		pin.bottom_radius=.069
		pin.height=.32
		var p:Vector2=TARGETS[i]
		piece(pin,Color("b64732"),STALL+Vector3(p.x,DECK+.16,p.y))
		s.text3d(str(AWARDS[i]),STALL+Vector3(p.x,DECK+.095,p.y+.11),.003)
	torus.inner_radius=.14
	torus.outer_radius=.19
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
	aim=Vector2.ZERO
	clock=0
	cursor.show()
	_update_cursor()

func end() -> void:
	active=false
	flying=false
	if cursor:cursor.hide()
	for ring in rings:ring.queue_free()
	rings.clear()

func move_aim(direction: Vector2,delta: float) -> void:
	if active and not flying and thrown<3:
		aim=(aim+direction.limit_length()*delta*1.6).clamp(Vector2(-1.17,-.66),Vector2(1.17,.65))

func _update_cursor() -> void:
	endpoint=aim+Vector2(sin(clock*2.1)*.07,cos(clock*1.7)*.05)
	cursor.position=STALL+Vector3(endpoint.x,DECK+.025,endpoint.y)

func toss() -> void:
	if not active or flying or thrown>=3:return
	_update_cursor()
	launched.emit(endpoint)
	thrown+=1
	rings.append(piece(torus,Color("ffb920"),STALL+Vector3(.25,1.42,2.5)))
	flying=true
	elapsed=0.0
	cursor.hide()

func _process(delta: float) -> void:
	if not active:return
	clock+=delta
	if not flying:
		if thrown<3:_update_cursor()
		return
	elapsed=minf(1,elapsed+delta/.72)
	var target:=STALL+Vector3(endpoint.x,DECK+.029+(thrown-1)*.012,endpoint.y)
	var ring:=rings.back() as MeshInstance3D
	ring.position=(STALL+Vector3(.25,1.42,2.5)).lerp(target,elapsed)
	ring.position.y+=3.8*elapsed*(1-elapsed)
	ring.rotation.x=sin(elapsed*TAU)*.54
	if elapsed<1:return
	flying=false
	last_points=0
	for i in TARGETS.size():
		if endpoint.distance_to(TARGETS[i])<=torus.inner_radius-.05:
			last_points=AWARDS[i]
			break
	score+=last_points
	cursor.visible=thrown<3
	landed.emit()

func show_other(at: Vector2) -> void:
	var now:=Time.get_ticks_msec()
	if at.abs().x>1.3 or at.abs().y>.8 or now-last_remote_throw<450:return
	last_remote_throw=now
	var from:=STALL+Vector3(-.25,1.42,2.5)
	var to:=STALL+Vector3(at.x,DECK+.045,at.y)
	var ring:=piece(torus,Color("8ed7de"),from)
	var tween:=ring.create_tween()
	tween.tween_method(func(t:float):
		ring.position=from.lerp(to,t)+Vector3.UP*(3.8*t*(1-t))
		ring.rotation.x=sin(t*TAU)*.54,0.0,1.0,.72)
	tween.tween_interval(1.2)
	tween.tween_callback(ring.queue_free)
