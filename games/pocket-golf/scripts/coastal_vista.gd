# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

static func prepare(island: Node3D, hole: int) -> void:
	var mist_color: Color=[Color("ffddbd"),Color("b4d6df"),Color("f4c7be")][hole]
	if hole==0:
		var light:=preload("res://scripts/harbour_light.gd").new()
		island.add_child(light)
		light.position=Vector3(-4.6,-1.60,-16.7)
	elif hole==1:
		sea_arch(island,Vector3(0,-1.9,-19.2))
		for i in 4:
			var side: float=-1.0 if i<2 else 1.0
			island.prop("nature/rock_largeC",Vector3(side*(5.8+i%2*1.3),-1.88,-18.6-i%2),1.6+i%2*.6,i*.91)
	else:
		for i in 3:
			var yacht: Node3D=island.prop("pirate/ship-small",Vector3(-9.0+i*8.0,-1.88,-19.5-i*3.1),0.29+i*.075,0.65-i*.54)
			island.flotilla.append(yacht)
	for i in 3:
		var bank:=MeshInstance3D.new()
		bank.name="SeaMist%d"%i
		var veil:=QuadMesh.new()
		veil.size=Vector2(27+i*5,3.4+i*.6)
		bank.mesh=veil
		bank.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat:=ShaderMaterial.new()
		mat.shader=preload("res://shaders/sea_mist.gdshader")
		mat.set_shader_parameter("tint",mist_color)
		mat.set_shader_parameter("phase",i*2.4+hole)
		bank.material_override=mat
		bank.position=[Vector3(1,.55,-18.8),Vector3(-16,.2,-4),Vector3(17,.3,-8)][i]
		bank.rotation.y=[0.0,1.22,-1.12][i]
		island.add_child(bank)
		island.mist.append(bank)

static func sea_arch(island: Node3D, at: Vector3) -> void:
	# A continuous, irregular limestone arch with a water-level opening.
	var mesh:=SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array]=[]
	for i in 11:
		var a:=PI*i/10.0
		var center:=Vector3(5.7*cos(a),6.2*sin(a),0.55*sin(2*a))
		var radial:=Vector3(cos(a),sin(a),0)
		var ring:=PackedVector3Array()
		for j in 8:
			var b:=TAU*j/8
			var thickness:=1.26+.22*sin(i*2.3+j*1.4)+.50*absf(cos(a))
			ring.append(center+radial*cos(b)*thickness+Vector3.BACK*sin(b)*thickness*1.25)
		rings.append(ring)
	for i in 10:
		for j in 8:
			var k: int=(j+1)%8
			var face: Color=Color("839799").lerp(Color("d2b88f"),0.38+.26*cos(TAU*j/8)+.14*sin(i*2.3))
			for index in [rings[i][j],rings[i+1][j],rings[i][k],rings[i][k],rings[i+1][j],rings[i+1][k]]:
				mesh.set_color(face)
				mesh.add_vertex(index)
	mesh.generate_normals()
	var draw:=MeshInstance3D.new()
	draw.name="SeaArch"
	draw.mesh=mesh.commit()
	var stone:=StandardMaterial3D.new()
	stone.vertex_color_use_as_albedo=true
	stone.vertex_color_is_srgb=true
	stone.cull_mode=BaseMaterial3D.CULL_DISABLED
	stone.roughness=1
	draw.material_override=stone
	draw.position=at
	island.add_child(draw)
