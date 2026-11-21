# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const NAMES := ["Peach Bunny","Pond Frog","Honey Bear","Sky Bird","Moon Cat"]
const COATS := ["fa9c9c","7ab68c","dfaf61","8fc9df","ac9ad5"]
static var shapes: Dictionary = {}
static var sphere := SphereMesh.new()
static var paints := {}

static func part(parent: Node3D, pos: Vector3, size_: Vector3, color: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh=sphere
	if not paints.has(color):
		var mat:=StandardMaterial3D.new()
		mat.albedo_color=Color(color)
		mat.roughness=.94
		mat.emission_enabled=true
		mat.emission=Color(color)
		mat.emission_energy_multiplier=.22
		if color in ["fff6c5","ff764c"]:mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		paints[color]=mat
	mesh.material_override=paints[color]
	parent.add_child(mesh)
	mesh.position=pos
	mesh.scale=size_
	return mesh

static func create(i: int) -> MeshInstance3D:
	if not shapes.has(i):shapes[i]=bake(i)
	var node:=MeshInstance3D.new()
	node.mesh=shapes[i]
	return node

static func bake(i: int) -> ArrayMesh:
	var toy:=Node3D.new()
	sphere.radial_segments=14
	sphere.rings=8
	var coat:String=COATS[i]
	part(toy,Vector3(0,.21,0),Vector3(.41,.37,.34),coat)
	part(toy,Vector3(0,.40,.015),Vector3(.48,.38,.37),coat)
	for side in [-1,1]:
		part(toy,Vector3(side*.14,.08,.11),Vector3(.15,.12,.18),coat)
		part(toy,Vector3(side*.23,.24,.02),Vector3(.13,.20,.15),coat).rotation.z=side*.35
		if i==0:
			part(toy,Vector3(side*.12,.64,0),Vector3(.12,.32,.12),coat).rotation.z=-side*.15
			part(toy,Vector3(side*.12,.65,.056),Vector3(.054,.21,.035),"fbd3bd").rotation.z=-side*.15
		elif i==4:
			var ear:=part(toy,Vector3(side*.15,.57,0),Vector3(.17,.19,.14),coat)
			var tip:=CylinderMesh.new()
			tip.top_radius=0;tip.bottom_radius=.55;tip.height=1
			tip.radial_segments=4;ear.mesh=tip
			part(toy,Vector3(side*.16,.37,.17),Vector3(.10,.014,.02),"69587f").rotation.z=side*.18
		elif i in [1,2]:
			part(toy,Vector3(side*.16,.555,0),Vector3(.15,.22 if i==4 else .14,.13),coat)
		var face:=Vector3(side*.15,.555,.073) if i==1 else Vector3(side*.087,.43,.185)
		part(toy,face,Vector3(.045,.057,.025),"302f43")
		part(toy,face+Vector3(-.007,.011,.012),Vector3.ONE*.013,"fff1d2")
		if i==2:part(toy,Vector3(side*.034,.365,.185),Vector3(.116,.096,.065),"ffdeb6")
	part(toy,Vector3(0,.365,.195),Vector3(.15 if i==3 else .071,.066,.08),"efaa55" if i==3 else "704a4a")
	part(toy,Vector3(0,.18,.151),Vector3(.23,.22,.065),"ffdeb6")
	if i==1:part(toy,Vector3(0,.337,.176),Vector3(.12,.017,.024),"456d54")
	if i==3:part(toy,Vector3(.035,.595,0),Vector3(.1,.13,.09),coat).rotation.z=-.4
	# Combine coloured parts into a single surface shared by all copies of this plush.
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for child: MeshInstance3D in toy.get_children():
		var data:=child.mesh.surface_get_arrays(0)
		var vertices:PackedVector3Array=data[Mesh.ARRAY_VERTEX]
		var normals:PackedVector3Array=data[Mesh.ARRAY_NORMAL]
		var indices:PackedInt32Array=data[Mesh.ARRAY_INDEX]
		var tint:Color=child.material_override.albedo_color
		var basis:=child.transform.basis.inverse().transposed()
		for idx in indices:
			var normal:Vector3=(basis*normals[idx]).normalized()
			var shade:=.78+.22*maxf(0.0,normal.dot(Vector3(-.35,.70,.62)))
			surface.set_color(Color(tint.r*shade,tint.g*shade,tint.b*shade))
			surface.set_normal(normal)
			surface.add_vertex(child.transform*vertices[idx])
	toy.free()
	var cloth:=StandardMaterial3D.new()
	cloth.vertex_color_use_as_albedo=true
	cloth.roughness=.95
	surface.set_material(cloth)
	surface.index()
	return surface.commit()
