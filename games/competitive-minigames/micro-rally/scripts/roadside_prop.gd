# SPDX-License-Identifier: GPL-3.0-or-later
extends Area3D
const Art=preload("art.gd")
const LAYER=8
var slot: int
var pieces: Array[MeshInstance3D]=[]
var rest: Array[Transform3D]=[]
var motion: Tween

func build(kind: String) -> void:
	collision_layer=LAYER
	collision_mask=2
	var size: Vector3
	match kind:
		"cone":
			size=Vector3(0.65,0.85,0.65)
			Art.box(self,Vector3(0.67,0.10,0.67),Vector3.UP*0.05,Color("3b4444"))
			ring(0.28,0.15,0.38,0.29,Color("e66832"))
			ring(0.15,0.10,0.15,0.555,Color("fff1cd"))
			ring(0.10,0.035,0.20,0.73,Color("e66832"))
		"barrel":
			size=Vector3(0.92,1.12,0.92)
			ring(0.44,0.46,0.53,0.265,Color("207c82"))
			ring(0.46,0.44,0.56,0.81,Color("32858a"))
			for y in [0.25,0.83]: ring(0.47,0.47,0.085,y,Color("f4bf64"))
		"crate":
			size=Vector3(0.98,0.85,0.88)
			for i in 4:
				Art.box(self,Vector3(0.95,0.192,0.80),Vector3.UP*(0.105+i*0.21),Color("cd995f") if i%2 else Color("aa764c"))
			for end in [-1,1]:
				var brace=Art.box(self,Vector3(1.08,0.12,0.07),Vector3(0,0.44,end*0.415),Color("ead19a"))
				brace.rotation.z=0.59
	var hitbox:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=size
	hitbox.shape=shape
	hitbox.position.y=size.y*0.5
	add_child(hitbox)
	for child in get_children():
		if child is MeshInstance3D:
			child.visibility_range_end=100
			pieces.append(child)
			rest.append(child.transform)
	body_entered.connect(_impact)

func ring(bottom: float, top: float, height: float, y: float, tint: Color) -> void:
	var shape:=CylinderMesh.new()
	shape.bottom_radius=bottom; shape.top_radius=top; shape.height=height
	shape.radial_segments=10; shape.rings=0
	var piece:=MeshInstance3D.new()
	piece.mesh=shape; piece.material_override=Art.material(tint); piece.position.y=y
	add_child(piece)

func _impact(body: Node3D) -> void:
	if body is RigidBody3D and body.has_method("roadside_driver") and body.roadside_driver():
		strike()

func strike() -> void:
	var road=get_parent()
	if road.local_breaks: road.break_prop(slot)

func scatter() -> void:
	set_deferred("collision_layer",0)
	set_deferred("monitoring",false)
	motion=create_tween().set_parallel(true)
	for i in pieces.size():
		var part:=pieces[i]
		var dir:=Vector3(cos(slot+i*2.4),0,sin(slot+i*2.4))
		var lift:=0.45+0.17*(i%3)
		motion.tween_property(part,"position",part.position+dir*0.55+Vector3.UP*lift,0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		motion.tween_property(part,"position",Vector3(rest[i].origin.x,0.09,rest[i].origin.z)+dir*1.15,0.32).set_delay(0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		motion.tween_property(part,"rotation",part.rotation+Vector3(1.8,0.4,i*0.45),0.50)
	motion.chain().tween_callback(hide)

func restore() -> void:
	if motion: motion.kill()
	for i in pieces.size(): pieces[i].transform=rest[i]
	set_deferred("collision_layer",LAYER)
	set_deferred("monitoring",true)
	show()
