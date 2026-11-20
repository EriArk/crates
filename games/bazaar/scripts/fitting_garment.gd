# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
## Authored overgarments in the SDK avatar's metre-scale fitting pose.
const GOLD := Color("e6bd70")
const LEATHER := Color("684638")

func cloth(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color=color
	mat.roughness=.94
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	return mat

# Each cross-section gives height, half-width and depth; the hem can dip at the back.
func fabric(rings: Array, dye: Color, train := 0.0) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(rings.size()-1):
		for i in 32:
			for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
				var ring: Vector3=rings[j+corner.y]
				var theta: float = TAU*(i+corner.x)/32.0
				var ripple := 1.0+.025*cos(8*theta)
				var dip := train*(1-cos(theta))*.5 if j+corner.y==rings.size()-1 else 0.0
				surface.add_vertex(Vector3(sin(theta)*ring.y*ripple,ring.x-dip,.006+cos(theta)*ring.z*ripple))
	surface.generate_normals()
	var piece := MeshInstance3D.new()
	piece.mesh=surface.commit()
	piece.material_override=cloth(dye)
	add_child(piece)

# Follow the front of the flared skirt so the apron drapes over the hem.
func apron() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := [Vector3(.503,.13,.117),Vector3(.46,.133,.119),Vector3(.322,.164,.15)]
	for row in 2:
		for i in 8:
			for corner: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
				var ring: Vector3=rings[row+corner.y]
				var angle := lerpf(-.64,.64,(i+corner.x)/8.0)
				surface.add_vertex(Vector3(sin(angle)*ring.y,ring.x,.008+cos(angle)*ring.z))
	surface.generate_normals()
	var piece := MeshInstance3D.new()
	piece.mesh=surface.commit()
	piece.material_override=cloth(Color("deb98a"))
	add_child(piece)

func detail(at: Vector3, dimensions: Vector3, color: Color, tilt := 0.0) -> void:
	var item := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size=dimensions
	item.mesh=shape
	item.material_override=cloth(color)
	item.position=at
	item.rotation.z=tilt
	add_child(item)

func build(kind: String) -> void:
	var dye: Color={"traveller":Color("3e806f"),"mage":Color("675184"),"merchant":Color("ac6153")}[kind]
	var length: float={"traveller":.355,"mage":.15,"merchant":.30}[kind]
	var width: float=.163 if kind!="mage" else .195
	fabric([Vector3(.686,.074,.073),Vector3(.644,.125,.10),Vector3(.53,.117,.104),Vector3(.46,.129,.112),Vector3(length,width,.145)],dye)
	fabric([Vector3(length+.016,width-.002,.145),Vector3(length,width+.003,.147)],GOLD)
	fabric([Vector3(.506,.124,.111),Vector3(.481,.129,.114)],LEATHER)
	match kind:
		"traveller":
			fabric([Vector3(.703,.074,.076),Vector3(.666,.133,.103),Vector3(.59,.158,.125)],Color("466448"),.145)
			detail(Vector3(-.035,.54,.119),Vector3(.024,.24,.016),LEATHER,-.35)
			detail(Vector3(-.082,.427,.108),Vector3(.081,.078,.04),Color("ad7952"),-.1)
		"mage":
			fabric([Vector3(.709,.074,.077),Vector3(.661,.139,.106),Vector3(.61,.151,.121)],Color("393459"),.075)
			detail(Vector3(0,.42,.138),Vector3(.041,.35,.015),Color("4a406d"))
			for y in [.33,.42,.51,.62]:
				detail(Vector3(0,y,.15 if y<.6 else .122),Vector3(.019,.019,.008),GOLD,PI/4)
		"merchant":
			apron()
			detail(Vector3(0,.417,.143),Vector3(.097,.052,.014),LEATHER)
			for x in [-.05,.05]:
				detail(Vector3(x,.588,.103),Vector3(.025,.13,.013),GOLD,x*5)
