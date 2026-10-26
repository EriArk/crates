# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
const Art = preload("art.gd")
const LIMIT = 220
var particles: Array = []
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

func dust(car: Node3D) -> void:
	if particles.size()>=LIMIT: return
	var node = MeshInstance3D.new(); node.mesh=dust_quad
	node.material_override=dust_material; node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node); node.position=car.position+car.transform.basis.z*1.1-Vector3.UP*0.4
	particles.append({"node":node,"life":0.65,"total":0.65,"velocity":Vector3(randf_range(-1,1),0.8,randf_range(-1,1)),"grow":true})

func beam(from: Vector3, to: Vector3, color: Color = Color("ffd07a")) -> void:
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

func _process(delta: float) -> void:
	for i in range(particles.size()-1,-1,-1):
		var p: Dictionary=particles[i]; p.life-=delta
		if p.life<=0: p.node.queue_free(); particles.remove_at(i); continue
		p.node.position+=p.velocity*delta
		p.node.scale=Vector3.ONE*(0.6+(1.0-p.life/p.total)*2.0 if p.grow else p.life/p.total)
