# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
const Tires = preload("tire_surface.gd")
const Art = preload("art.gd")
const LIMIT = 220
const MARK_LIMIT = 96
var particles: Array = []
var loose_wheels: Array = []
const WHEEL_LIMIT = 16
var marks: Array = []
var skid_history: Dictionary = {}
var mark_mesh: PlaneMesh
var ring_mesh: TorusMesh
var tire_smoke: StandardMaterial3D
var spray_material: StandardMaterial3D
var smoke_material: StandardMaterial3D
var dust_clock = 0.0
var sphere: SphereMesh
var dust_quad: QuadMesh
var dust_material: StandardMaterial3D

func _ready() -> void:
	sphere=SphereMesh.new(); sphere.radius=0.18; sphere.height=0.28; sphere.radial_segments=6; sphere.rings=3
	dust_quad=QuadMesh.new(); dust_quad.size=Vector2(1.1,1.1)
	var gradient = Gradient.new(); gradient.offsets=PackedFloat32Array([0.0,0.5,1.0]); gradient.colors=PackedColorArray([Color(0.52,0.34,0.17,0.32),Color(0.52,0.34,0.17,0.20),Color(0.52,0.34,0.17,0)])
	var texture = GradientTexture2D.new(); texture.gradient=gradient; texture.fill=GradientTexture2D.FILL_RADIAL; texture.fill_from=Vector2(0.5,0.5); texture.fill_to=Vector2(1,0.5); texture.width=64; texture.height=64
	dust_material=StandardMaterial3D.new(); dust_material.albedo_texture=texture; dust_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; dust_material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
	dust_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; dust_material.no_depth_test=false
	smoke_material=dust_material.duplicate(); smoke_material.albedo_color=Color(0.25,0.25,0.25,0.9)
	tire_smoke=dust_material.duplicate(); tire_smoke.albedo_texture=texture.duplicate()
	var grey=Gradient.new(); grey.colors=PackedColorArray([Color(0.72,0.74,0.76,0.25),Color(0.72,0.74,0.76,0)])
	tire_smoke.albedo_texture.gradient=grey
	spray_material=tire_smoke.duplicate(); spray_material.albedo_color=Color(0.7,0.83,0.9,0.65)
	mark_mesh=PlaneMesh.new(); mark_mesh.size=Vector2.ONE
	ring_mesh=TorusMesh.new(); ring_mesh.inner_radius=0.92; ring_mesh.outer_radius=1.04; ring_mesh.rings=20; ring_mesh.ring_segments=6

func clear() -> void:
	for wheel in loose_wheels: wheel.node.queue_free()
	loose_wheels.clear()
	for p in particles: p.node.queue_free()
	for mark in marks: mark.node.queue_free()
	particles.clear(); marks.clear(); skid_history.clear()

func flash(pos: Vector3, color: Color, scale_value: float = 1.0) -> void:
	if particles.size()>=LIMIT: return
	var node=MeshInstance3D.new(); node.mesh=sphere; node.material_override=Art.material(color,2.0)
	add_child(node); node.position=pos; node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.append({"node":node,"life":0.11,"total":0.11,"velocity":Vector3.ZERO,"grow":false,"size":scale_value})

func ring(pos: Vector3, color: Color) -> void:
	if particles.size()>=LIMIT: return
	var node=MeshInstance3D.new(); node.mesh=ring_mesh; node.material_override=Art.material(color,1.5)
	add_child(node); node.position=pos; node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.append({"node":node,"life":0.4,"total":0.4,"velocity":Vector3.ZERO,"grow":true,"fade":true})

func exhaust(car: Node3D) -> void:
	for side in [-0.48,0.48]:
		flash(car.position+car.basis.z*1.2+car.basis.x*side-Vector3.UP*0.12,Color("58dfff"),2.0)

func wreck(pos: Vector3) -> void:
	flash(pos,Color("ffb64b"),5.0); burst(pos,Color("ffb64b"))
	for i in 7:
		if particles.size()>=LIMIT: return
		var node=MeshInstance3D.new(); node.mesh=dust_quad; node.material_override=smoke_material
		add_child(node); node.position=pos; node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		particles.append({"node":node,"life":1.1,"total":1.1,"velocity":Vector3(randf_range(-1,1),randf_range(1,3),randf_range(-1,1)),"grow":true,"fade":true})

func skid(car: Node3D, _track: Node3D) -> void:
	if not car.grounded: end_skid(car); return
	var id=car.get_instance_id()
	var old: Array=skid_history.get(id,[])
	var contacts: Array=[]
	for wheel in 4:
		var w: Dictionary=car.physics.wheels[wheel]
		if Tires.intensity(w)<0.08: contacts.append(null); continue
		var hit={"normal":w.normal}
		var point: Vector3=w.point+w.normal*0.018
		contacts.append(point)
		if old.size()!=4 or old[wheel]==null: continue
		var segment: Vector3=point-old[wheel]
		# Join wheel contacts along the skid, not isolated bars along the car body.
		if segment.length()<0.05 or segment.length()>3: continue
		if marks.size()>=MARK_LIMIT: marks.pop_front().node.queue_free()
		var node=MeshInstance3D.new(); node.mesh=mark_mesh; node.material_override=Art.material(Tires.MARKS[w.surface])
		add_child(node); node.position=point.lerp(old[wheel],0.5)
		var z: Vector3=segment.slide(hit.normal).normalized()
		node.basis=Basis(hit.normal.cross(z).normalized(),hit.normal,z)
		node.scale=Vector3(0.19,1,segment.length()+0.05)
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marks.append({"node":node,"life":6.0})
	skid_history[id]=contacts

func end_skid(car: Node3D) -> void:
	skid_history.erase(car.get_instance_id())

func dust(car: Node3D, wetness: float = 0.0) -> void:
	# At most two emissions per car per trail tick, sharing the global VFX budget.
	var emitted=0
	for contact in car.physics.wheels:
		if particles.size()>=LIMIT or emitted>=2: return
		if not contact.contact or contact.missing: continue
		var slip=Tires.intensity(contact)
		var loose: bool=contact.surface>=Tires.Kind.GRAVEL
		var rolling: bool=car.linear_velocity.length()>3
		if not (slip>0.08 or (rolling and (loose or wetness>0.15))): continue
		var node=MeshInstance3D.new(); node.mesh=dust_quad
		node.material_override=dust_material if loose else tire_smoke
		var splat: bool=loose and wetness>0.5
		if splat: node.mesh=sphere; node.material_override=Art.material(Tires.MARKS[contact.surface])
		elif not loose and wetness>0.15: node.material_override=spray_material
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node); node.position=contact.point+contact.normal*0.08
		var life=0.24 if splat else 0.65
		var kick= -car.basis.z*clampf(contact.long_slip*0.12,-2,2)
		particles.append({"node":node,"life":life,"total":life,"velocity":Vector3(randf_range(-1,1),0.8,randf_range(-1,1))-kick,"grow":not splat,"fade":not splat})
		emitted+=1

func beam(from: Vector3, to: Vector3, color: Color = Color("ffd07a")) -> void:
	flash(from,color,1.8)
	if particles.size()>=LIMIT: return
	var distance = from.distance_to(to)
	if distance<0.01: return
	var node = Art.box(self,Vector3(0.045,0.045,distance),from.lerp(to,0.5),color)
	node.material_override=Art.material(color,2.0); node.look_at(to,Vector3.UP)
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.append({"node":node,"life":0.085,"total":0.085,"velocity":Vector3.ZERO,"grow":false})

func burst(pos: Vector3, color: Color) -> void:
	for i in 12:
		if particles.size()>=LIMIT: return
		var node = MeshInstance3D.new(); node.mesh=sphere; node.material_override=Art.material(color,0.5)
		add_child(node); node.position=pos; node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		particles.append({"node":node,"life":0.45,"total":0.45,"velocity":Vector3(randf_range(-4,4),randf_range(1,4),randf_range(-4,4)),"grow":false})

func detach_wheel(car: Node3D, index: int) -> void:
	if loose_wheels.size()>=WHEEL_LIMIT: loose_wheels.pop_front().node.queue_free()
	var wheel: Dictionary=car.physics.wheels[index]
	var body=RigidBody3D.new(); body.mass=3; body.collision_layer=0; body.collision_mask=1
	body.continuous_cd=true; body.linear_damp=0.1; body.angular_damp=0.2
	var collision=CollisionShape3D.new(); var shape=CylinderShape3D.new()
	shape.radius=wheel.radius; shape.height=0.35; collision.shape=shape; collision.rotation.z=PI/2; body.add_child(collision)
	var mesh=car.wheel_pivots[index].get_child(0).duplicate(); body.add_child(mesh)
	add_child(body); body.global_transform=car.wheel_pivots[index].global_transform
	body.linear_velocity=car.linear_velocity+car.angular_velocity.cross(body.position-car.position)+Vector3.UP*1.5
	body.angular_velocity=car.angular_velocity-car.wheel_pivots[index].global_basis.x*wheel.omega
	loose_wheels.append({"node":body,"life":5.0})
	burst(body.position,Color("d6b88c"))

func _process(delta: float) -> void:
	for i in range(loose_wheels.size()-1,-1,-1):
		loose_wheels[i].life-=delta
		if loose_wheels[i].life<=0: loose_wheels[i].node.queue_free(); loose_wheels.remove_at(i)
	for i in range(marks.size()-1,-1,-1):
		marks[i].life-=delta
		if marks[i].life<=0: marks[i].node.queue_free(); marks.remove_at(i)
		else: marks[i].node.transparency=1-clampf(marks[i].life/2,0,1)
	for i in range(particles.size()-1,-1,-1):
		var p: Dictionary=particles[i]; p.life-=delta
		if p.life<=0: p.node.queue_free(); particles.remove_at(i); continue
		p.node.position+=p.velocity*delta
		p.node.scale=Vector3.ONE*float(p.get("size",1.0))*(0.6+(1.0-p.life/p.total)*2.0 if p.grow else p.life/p.total)
		if p.get("fade",false): p.node.transparency=1-p.life/p.total
