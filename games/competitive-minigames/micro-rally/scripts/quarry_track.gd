# SPDX-License-Identifier: GPL-3.0-or-later
extends "track.gd"
# Independent authored route; common mesher keeps the shoulder collision continuous.
func _anchors() -> Array:
	return [Vector3(-20,0,84),Vector3(-70,0,82),Vector3(-91,0,45),Vector3(-86,0,-30),
		Vector3(-62,0,-82),Vector3(10,0,-91),Vector3(72,0,-73),Vector3(88,0,-27),
		Vector3(70,0,8),Vector3(35,0,12),Vector3(18,0,-15),Vector3(35,0,-43),
		Vector3(9,0,-57),Vector3(-32,0,-50),Vector3(-50,0,-16),Vector3(-40,0,18),
		Vector3(-7,0,26),Vector3(13,0,51),Vector3(58,0,63),Vector3(65,0,88),Vector3(22,0,92)]

func base_height(x: float, z: float) -> float:
	var radius=Vector2(x/94.0,z/100.0).length()
	# Broad ramps through three benches; shoulders are flattened to the road profile.
	return 2.0+smoothstep(0.24,0.43,radius)*4.0+smoothstep(0.49,0.68,radius)*4.8+smoothstep(0.76,0.95,radius)*5.2+sin(x*0.06)*cos(z*0.05)*0.3

func ground_height(x: float, z: float, index: int, _driving_surface: bool = false) -> float:
	var best=INF; var road_y=points[index].y
	for segment in [posmod(index-1,COUNT),index]:
		var a=points[segment]; var b=points[(segment+1)%COUNT]
		var av=Vector2(a.x,a.z); var bv=Vector2(b.x,b.z)
		var t=clampf((Vector2(x,z)-av).dot(bv-av)/(bv-av).length_squared(),0,1)
		var distance=Vector2(x,z).distance_squared_to(av.lerp(bv,t))
		if distance<best: best=distance; road_y=lerpf(a.y,b.y,t)
	return lerpf(road_y-0.035,base_height(x,z),smoothstep(6.0,11.0,sqrt(best)))

func _build_terrain() -> void:
	super._build_terrain()
	# Continue the plateau beyond the shared driving mesh, outside the course.
	# Match its 2 m boundary exactly, including collision for an ejected car.
	var corners=[Vector2(-108,-108),Vector2(-108,108),Vector2(108,108),Vector2(108,-108)]
	var faces=PackedVector3Array()
	for edge in 4:
		for step in 108:
			var a: Vector2=corners[edge].lerp(corners[(edge+1)%4],float(step)/108)
			var b: Vector2=corners[edge].lerp(corners[(edge+1)%4],float(step+1)/108)
			var c=b*(180.0/108); var d=a*(180.0/108)
			_quad(faces,Vector3(a.x,surface_height(a.x,a.y),a.y),Vector3(b.x,surface_height(b.x,b.y),b.y),
				Vector3(c.x,base_height(c.x,c.y),c.y),Vector3(d.x,base_height(d.x,d.y),d.y))
	var surface=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in faces: surface.add_vertex(vertex)
	surface.index(); surface.generate_normals()
	var node=MeshInstance3D.new(); node.name="QuarryBackdrop"; node.mesh=surface.commit()
	node.material_override=meadow_material(false); add_child(node)
	_static_surface(faces,"quarry_backdrop")

func _bridge_segment(_i: int) -> bool: return false
func road_divisions() -> int: return 6
func road_vertex(point: Vector3) -> Vector3:
	point.y=surface_height(point.x,point.z)+0.035; return point
func _build_stream() -> void: pass
func _grass() -> void: pass # Sparse scrub is batched with the quarry rocks below.

func meadow_material(_grass: bool) -> ShaderMaterial:
	var mat=ShaderMaterial.new(); mat.shader=preload("res://shaders/quarry.gdshader"); return mat

func _build_road() -> void:
	super._build_road()
	road_material.set_shader_parameter("mud_dark",Color("665541"))
	road_material.set_shader_parameter("mud_light",Color("a39272"))

func _decorate() -> void:
	var batches={"rock_largeA":[],"rock_largeC":[],"plant_bushSmall":[],"grass_large":[],"tree_pineTallA":[]}
	for n in 1900:
		var x=rng.randf_range(-102,102); var z=rng.randf_range(-102,102)
		var p=Vector3(x,0,z); var at=nearest(p)
		if Vector2(x-points[at].x,z-points[at].z).length()<9.5: continue
		p.y=surface_height(x,z)
		var id: String; var scale_value: float
		if n<1050:
			id="rock_largeA" if n%2 else "rock_largeC"; scale_value=rng.randf_range(0.65,2.3)
		elif n<1250 and p.y>12:
			id="tree_pineTallA"; scale_value=rng.randf_range(3.0,4.4)
		else:
			id="plant_bushSmall" if n%3==0 else "grass_large"; scale_value=rng.randf_range(0.7,1.5)
		batches[id].append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale_value),p))
	for id in batches: Art.instances(self,"nature",id,batches[id])
	# Continuous low safety walls along the exposed rim; no overlapping box caps.
	var rails=PackedVector3Array()
	for i in COUNT:
		var j=(i+1)%COUNT
		if points[i].y<12: continue
		var side_a=Vector3(-tangents[i].z,0,tangents[i].x)
		var side_b=Vector3(-tangents[j].z,0,tangents[j].x)
		for sign_value in [-1,1]:
			var a=points[i]+side_a*7.3*sign_value; var b=points[j]+side_b*7.3*sign_value
			_quad(rails,a-Vector3.UP*0.15,b-Vector3.UP*0.15,b+Vector3.UP*0.75,a+Vector3.UP*0.75)
			if i%2==0:
				var rail=Art.box(self,Vector3(0.35,0.8,a.distance_to(b)*1.9),a.lerp(b,0.5)+Vector3.UP*0.35,Color("c3b592") if i%4 else Color("776b55"))
				rail.look_at(rail.position+b-a,Vector3.UP)
	_static_surface(rails,"quarry_rail")
	# Roadside apex markers, deliberately outside the driveable shoulder.
	for i in range(8,COUNT,8):
		if absf(tangents[i].signed_angle_to(tangents[(i+8)%COUNT],Vector3.UP))<0.35: continue
		var side=Vector3(-tangents[i].z,0,tangents[i].x)
		var sign_node=Label3D.new(); sign_node.text="‹‹‹"; sign_node.font_size=80; sign_node.pixel_size=0.018
		var p=points[i]+side*8.2; p.y=surface_height(p.x,p.z)+1.8
		sign_node.position=p; sign_node.modulate=Color("f2d291"); sign_node.billboard=BaseMaterial3D.BILLBOARD_ENABLED; add_child(sign_node)
	_conveyor(Vector3(-12,0,-13),0.25)
	_conveyor(Vector3(53,0,-38),-0.7)
	var side=Vector3(-tangents[0].z,0,tangents[0].x)
	for s in [-1,1]: Art.box(self,Vector3(0.5,5,0.5),points[0]+side*7*s+Vector3.UP*2.5,Color("bc933e"))
	var arch=Art.box(self,Vector3(15,0.55,0.55),points[0]+Vector3.UP*5,Color("bc933e")); arch.rotation.y=atan2(-tangents[0].x,-tangents[0].z)
	var title=Label3D.new(); title.text="REDSTONE QUARRY"; title.font_size=100; title.pixel_size=0.009
	title.position=points[0]+Vector3.UP*5.6; title.billboard=BaseMaterial3D.BILLBOARD_ENABLED; add_child(title)

func _conveyor(pos: Vector3, heading: float) -> void:
	pos.y=surface_height(pos.x,pos.z)
	var root=Node3D.new(); root.position=pos; root.rotation.y=heading; add_child(root)
	for z in [-5,5]:
		for x in [-1,1]:
			Art.box(root,Vector3(0.28,4.2,0.28),Vector3(x,2.1,z),Color("a8873e"))
			Art.collider(root,Vector3(0.28,4.2,0.28),Vector3(x,2.1,z))
	var belt=Art.box(root,Vector3(2.4,0.35,16),Vector3(0,4.1,0),Color("46504f")); belt.rotation.x=-0.12
	var belt_body=Art.collider(root,Vector3(2.4,0.35,16),Vector3(0,4.1,0)); belt_body.rotation.x=-0.12
	for x in [-1.3,1.3]:
		var rail=Art.box(root,Vector3(0.16,0.5,16),Vector3(x,4.35,0),Color("b39962")); rail.rotation.x=-0.12
	# Equipment stays off the racing line, but its frame blocks cars and gunfire.
