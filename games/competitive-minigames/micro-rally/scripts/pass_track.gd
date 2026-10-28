# SPDX-License-Identifier: GPL-3.0-or-later
extends "track.gd"
# Authored mountain loop, using the shared continuous ground/road collision.
func terrain_cells() -> int: return 168
func _anchors() -> Array:
	return [Vector3(-60,0,118),Vector3(-118,0,108),Vector3(-142,0,70),Vector3(-140,0,14),
		Vector3(-120,0,-16),Vector3(-68,0,-18),Vector3(-42,0,-42),Vector3(-64,0,-65),
		Vector3(-119,0,-62),Vector3(-143,0,-90),Vector3(-130,0,-128),Vector3(-80,0,-145),
		Vector3(-25,0,-137),Vector3(0,0,-100),Vector3(-10,0,-65),Vector3(17,0,-36),
		Vector3(53,0,-42),Vector3(65,0,-84),Vector3(92,0,-120),Vector3(132,0,-108),
		Vector3(144,0,-62),Vector3(130,0,-10),Vector3(91,0,8),Vector3(56,0,12),
		Vector3(34,0,43),Vector3(60,0,67),Vector3(105,0,59),Vector3(137,0,86),
		Vector3(120,0,126),Vector3(70,0,140),Vector3(12,0,128),Vector3(-20,0,100)]
func base_height(x: float, z: float) -> float:
	var ridge=exp(-pow((z+78.0)/74.0,2))
	var shoulder=exp(-pow((x-75.0)/70.0,2)-pow((z-10.0)/110.0,2))
	return 6.0+ridge*28.0+shoulder*9.0+sin(x*0.055)*cos(z*0.046)*0.35
func ground_height(x: float, z: float, index: int, _driving_surface: bool = false) -> float:
	var best=INF; var road_y=points[index].y
	for segment in [posmod(index-1,COUNT),index]:
		var a=points[segment]; var b=points[(segment+1)%COUNT]
		var av=Vector2(a.x,a.z); var bv=Vector2(b.x,b.z)
		var t=clampf((Vector2(x,z)-av).dot(bv-av)/(bv-av).length_squared(),0,1)
		var distance=Vector2(x,z).distance_squared_to(av.lerp(bv,t))
		if distance<best: best=distance; road_y=lerpf(a.y,b.y,t)
	var hill=base_height(x,z)+smoothstep(8.0,22.0,sqrt(best))*(3.0+sin(x*0.07)*cos(z*0.06)*2.0)
	return lerpf(road_y-0.035,hill,smoothstep(6.5,14.0,sqrt(best)))
func _bridge_segment(_i: int) -> bool: return false
func _build_stream() -> void: pass
func road_follows_terrain() -> bool: return true
func road_divisions() -> int: return 1
func road_vertex(point: Vector3) -> Vector3:
	point.y=surface_height(point.x,point.z)+0.035; return point
func meadow_material(grass: bool) -> ShaderMaterial:
	var mat=super.meadow_material(grass)
	mat.set_shader_parameter("meadow_dark",Color("405c32")); mat.set_shader_parameter("meadow_light",Color("78954a"))
	return mat
func _build_terrain() -> void:
	super._build_terrain()
	var corners=[Vector2(-168,-168),Vector2(-168,168),Vector2(168,168),Vector2(168,-168)]
	var faces=PackedVector3Array()
	for edge in 4:
		for step in 168:
			var a: Vector2=corners[edge].lerp(corners[(edge+1)%4],float(step)/168)
			var b: Vector2=corners[edge].lerp(corners[(edge+1)%4],float(step+1)/168)
			var c=b*(280.0/168); var d=a*(280.0/168)
			_quad(faces,Vector3(a.x,surface_height(a.x,a.y),a.y),Vector3(b.x,surface_height(b.x,b.y),b.y),
				Vector3(c.x,base_height(c.x,c.y)+10,c.y),Vector3(d.x,base_height(d.x,d.y)+10,d.y))
	var surface=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in faces: surface.set_color(Color(0.1,0.6,0.1)); surface.add_vertex(vertex)
	surface.index(); surface.generate_normals()
	var node=MeshInstance3D.new(); node.name="PassBackdrop"; node.mesh=surface.commit(); node.material_override=meadow_material(false); add_child(node)
	_static_surface(faces,"pass_backdrop")
func _build_road() -> void:
	super._build_road()
	road_material.set_shader_parameter("mud_dark",Color("493d2d")); road_material.set_shader_parameter("mud_light",Color("8a7149"))
func _decorate() -> void:
	var batches={"tree_pineTallA":[],"tree_pineRoundA":[],"rock_largeA":[],"rock_largeC":[],"plant_bushDetailed":[],"grass_large":[],"flower_yellowA":[]}
	for n in 12000:
		var x=rng.randf_range(-163,163); var z=rng.randf_range(-163,163)
		var p=Vector3(x,0,z); var at=nearest(p)
		var distance=Vector2(x-points[at].x,z-points[at].z).length()
		if distance<10.5: continue
		p.y=surface_height(x,z)
		var id: String; var factor: float
		if n<4100:
			id="tree_pineTallA" if n%3 else "tree_pineRoundA"; factor=rng.randf_range(3.8,6.3)
			if distance<17: factor*=0.7
		elif n<5600:
			id="rock_largeA" if n%2 else "rock_largeC"; factor=rng.randf_range(0.8,2.8)
		else:
			id="plant_bushDetailed" if n%3==0 else "flower_yellowA" if n%7==0 else "grass_large"; factor=rng.randf_range(0.8,1.7)
		batches[id].append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*factor),p))
	for id in batches: Art.instances(self,"nature",id,batches[id])
	_build_rails()
	_tower(Vector3(-77,0,-95))
	_cabin(Vector3(-105,0,48))
	var side=Vector3(-tangents[0].z,0,tangents[0].x)
	for s in [-1,1]: Art.box(self,Vector3(0.5,5.2,0.5),points[0]+side*7.5*s+Vector3.UP*2.6,Color("584638"))
	var banner=Art.box(self,Vector3(15.5,0.9,0.4),points[0]+Vector3.UP*5.0,Color("cfad51")); banner.rotation.y=atan2(-tangents[0].x,-tangents[0].z)
	var title=Label3D.new(); title.text="PINECREST PASS"; title.font_size=100; title.pixel_size=0.009
	title.position=points[0]+Vector3.UP*5.7; title.billboard=BaseMaterial3D.BILLBOARD_ENABLED; add_child(title)
func _build_rails() -> void:
	var rails=PackedVector3Array()
	for i in COUNT:
		var j=(i+1)%COUNT
		var curve=absf(tangents[i].signed_angle_to(tangents[(i+3)%COUNT],Vector3.UP))
		if points[i].y<18 and curve<0.24: continue
		var sa=Vector3(-tangents[i].z,0,tangents[i].x); var sb=Vector3(-tangents[j].z,0,tangents[j].x)
		for s in [-1,1]:
			var a=points[i]+sa*7.5*s; var b=points[j]+sb*7.5*s
			a.y=surface_height(a.x,a.z); b.y=surface_height(b.x,b.z)
			_quad(rails,a-Vector3.UP*0.2,b-Vector3.UP*0.2,b+Vector3.UP*0.9,a+Vector3.UP*0.9)
			var beam=Art.box(self,Vector3(0.18,0.22,a.distance_to(b)+0.1),a.lerp(b,0.5)+Vector3.UP*0.7,Color("b3b9ac"))
			beam.look_at(beam.position+b-a,Vector3.UP)
			if i%2==0: Art.box(self,Vector3(0.2,0.9,0.2),a+Vector3.UP*0.4,Color("5d635c"))
		if curve>0.24 and i%3==0:
			var at=points[i]+sa*8.8; at.y=surface_height(at.x,at.z)+1.5
			var sign_node=Label3D.new(); sign_node.text="‹‹‹" if tangents[i].signed_angle_to(tangents[(i+3)%COUNT],Vector3.UP)>0 else "›››"
			sign_node.position=at; sign_node.font_size=90; sign_node.pixel_size=0.014; sign_node.modulate=Color("f2c84a"); sign_node.billboard=BaseMaterial3D.BILLBOARD_ENABLED; add_child(sign_node)
	_static_surface(rails,"pass_rail")
func _tower(point: Vector3) -> void:
	point.y=surface_height(point.x,point.z)
	var root=Node3D.new(); root.name="RidgeLookout"; root.position=point; add_child(root)
	for x in [-2,2]:
		for z in [-2,2]:
			Art.box(root,Vector3(0.38,7,0.38),Vector3(x,3.5,z),Color("705033")); Art.collider(root,Vector3(0.4,7,0.4),Vector3(x,3.5,z))
	Art.box(root,Vector3(5.5,0.4,5.5),Vector3(0,6.8,0),Color("b28d56"))
	Art.box(root,Vector3(4.5,2.2,4.5),Vector3(0,8.0,0),Color("78634a"))
	Art.box(root,Vector3(5.6,0.45,5.6),Vector3(0,9.3,0),Color("486464"))
	for s in [-1,1]: Art.box(root,Vector3(4.0,0.8,0.04),Vector3(0,8.3,s*2.28),Color("8cbab2"))
func _cabin(point: Vector3) -> void:
	point.y=surface_height(point.x,point.z)
	var root=Node3D.new(); root.name="ForestCabin"; root.position=point; root.rotation.y=0.3; add_child(root)
	Art.box(root,Vector3(7,3.6,5),Vector3(0,1.8,0),Color("987044")); Art.collider(root,Vector3(7,3.6,5),Vector3(0,1.8,0))
	for s in [-1,1]:
		var roof=Art.box(root,Vector3(4.5,0.25,6),Vector3(s*1.9,4.15,0),Color("784534")); roof.rotation.z=s*-0.35
	Art.box(root,Vector3(1.25,2.4,0.05),Vector3(0,1.2,2.53),Color("423d30"))
	for x in [-2,2]: Art.box(root,Vector3(1.2,1.1,0.06),Vector3(x,2.1,2.54),Color("abc3ac"))
func _grass() -> void:
	var mesh=_grass_mesh(); var mat=meadow_material(true); var cells: Dictionary={}
	# Ribbon sampling concentrates opaque tufts around the long route, not an enormous square.
	for i in COUNT:
		var j=(i+1)%COUNT
		var steps=maxi(1,ceili(points[i].distance_to(points[j])/0.7))
		for along in steps:
			var center=points[i].lerp(points[j],float(along)/steps)
			var side=Vector3(-tangents[i].z,0,tangents[i].x)
			for cross_step in range(10,29):
				for sign_value in [-1,1]:
					var p=center+side*(cross_step*0.7+rng.randf_range(-0.2,0.2))*sign_value
					p.y=surface_height(p.x,p.z)-0.018
					if road_distance(p,nearest(p))<6.7: continue
					var key=Vector2i(floori(p.x/16),floori(p.z/16))
					if not cells.has(key): cells[key]=[]
					cells[key].append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(1.5,2.2)),p))
	for key in cells:
		var node=MultiMeshInstance3D.new(); var multi=MultiMesh.new(); multi.transform_format=MultiMesh.TRANSFORM_3D; multi.mesh=mesh; multi.instance_count=cells[key].size()
		var origin=Vector3(key.x*16,0,key.y*16)
		for i in cells[key].size():
			var pose: Transform3D=cells[key][i]; pose.origin-=origin; multi.set_instance_transform(i,pose)
		node.position=origin; node.multimesh=multi; node.material_override=mat; node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end=65; node.visibility_range_end_margin=10; add_child(node)
