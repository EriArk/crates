# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
const Art=preload("art.gd")
const Tires=preload("tire_surface.gd")
var map_bounds=Rect2(-84,-72,168,144)
var graph=AStar3D.new()
var covers: Array[Rect2]=[]
var surfaces: Array[ShaderMaterial]=[]
var pickup_spots: Array[Vector3]=[]
const PICKUP_TYPES=["rocket","repair","repair","shield","shield","cool","pulse","rocket"]

func height_at(p: Vector3) -> float:
	if p.z>=-58 and p.z<=-30: return 4.0*clampf((64-absf(p.x))/32.0,0,1)
	return 0
func tire_surface_at(p: Vector3) -> int:
	if p.y>1 or (absf(p.x)<52 and absf(p.z)<42): return Tires.Kind.CONCRETE
	return Tires.Kind.GRAVEL if p.x>45 else Tires.Kind.MUD
func set_wetness(value: float) -> void:
	for mat in surfaces: mat.set_shader_parameter("wetness",value)
func update_view(_pos: Vector3) -> void: pass
func section_name(_at: int) -> String: return ""
func safe_point(p: Vector3, margin: float=3) -> bool:
	if not map_bounds.grow(-margin).has_point(Vector2(p.x,p.z)): return false
	for rect in covers:
		if rect.grow(margin).has_point(Vector2(p.x,p.z)): return false
	return true
func segment_clear(a: Vector3,b: Vector3) -> bool:
	for i in range(13):
		var p=a.lerp(b,i/12.0)
		if not safe_point(p) or absf(p.y-height_at(p))>1.0: return false
	return true
func path(a: Vector3,b: Vector3) -> PackedVector3Array:
	return graph.get_point_path(graph.get_closest_point(a),graph.get_closest_point(b))
func spawn_pose(slot: int) -> Transform3D:
	var angle=TAU*slot/16.0
	var p=Vector3(sin(angle)*72,0,cos(angle)*60); p.y=height_at(p)+0.9
	return Transform3D(Basis(Vector3.UP,atan2(p.x,p.z)),p)
func _ground(x0: float,x1: float,z0: float,z1: float,raised: bool,color: Color) -> void:
	var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(int(x0),int(x1),4):
		for z in range(int(z0),int(z1),4):
			var corners=[Vector3(x,0,z),Vector3(minf(x+4,x1),0,z),Vector3(minf(x+4,x1),0,minf(z+4,z1)),Vector3(x,0,minf(z+4,z1))]
			for index in [0,1,2,0,2,3]:
				var p: Vector3=corners[index]
				if raised: p.y=4*clampf((64-absf(p.x))/32,0,1)
				st.set_uv(Vector2(p.x,p.z)*0.2); st.add_vertex(p)
	st.generate_normals()
	var mesh=st.commit(); var node=MeshInstance3D.new(); node.mesh=mesh
	var mat=ShaderMaterial.new(); mat.shader=preload("res://shaders/arena_ground.gdshader")
	mat.set_shader_parameter("tint",color); mat.set_shader_parameter("concrete",color.g>0.5)
	surfaces.append(mat); node.material_override=mat; add_child(node)
	var body=StaticBody3D.new(); var shape=CollisionShape3D.new(); shape.shape=mesh.create_trimesh_shape(); body.add_child(shape); add_child(body)
func _terrace_edge(z: float) -> void:
	var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ends in [[-64,-32],[-32,32],[32,64]]:
		var a=Vector3(ends[0],0,z); var b=Vector3(ends[1],0,z)
		var c=b+Vector3.UP*4*clampf((64-absf(b.x))/32,0,1)
		var d=a+Vector3.UP*4*clampf((64-absf(a.x))/32,0,1)
		for triangle in [[a,b,c],[a,c,d]]:
			if (triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).length_squared()<0.001: continue
			for p in (triangle if z==-58 else [triangle[2],triangle[1],triangle[0]]): st.add_vertex(p)
	st.generate_normals(); var mesh=st.commit()
	var node=MeshInstance3D.new(); node.mesh=mesh; node.material_override=Art.material(Color("746e5b")); add_child(node)
	var body=StaticBody3D.new(); var collider=CollisionShape3D.new(); var shape=mesh.create_trimesh_shape(); shape.backface_collision=true
	collider.shape=shape; body.add_child(collider); add_child(body)
func _block(size: Vector3,pos: Vector3,color: Color) -> void:
	Art.box(self,size,pos,color); Art.collider(self,size,pos)
func scenery_height(x: float,z: float) -> float:
	var outside=maxf(absf(x)-92,absf(z)-80)
	return -0.15+smoothstep(0,42,outside)*(6+4*sin(x*0.045)*cos(z*0.055))
func _backdrop() -> void:
	# Visual terrain continues beyond the walls and the following camera's footprint.
	# It has no gameplay collider and does not change the arena's contact surfaces.
	var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-240,240,12):
		for z in range(-240,240,12):
			var p=[Vector2(x,z),Vector2(x+12,z),Vector2(x+12,z+12),Vector2(x,z+12)]
			for index in [0,1,2,0,2,3]: st.add_vertex(Vector3(p[index].x,scenery_height(p[index].x,p[index].y),p[index].y))
	st.generate_normals(); var node=MeshInstance3D.new(); node.mesh=st.commit()
	var mat=ShaderMaterial.new(); mat.shader=preload("res://shaders/surface.gdshader"); mat.set_shader_parameter("tint",Color("596e3f")); mat.set_shader_parameter("kind",0)
	node.material_override=mat; add_child(node)
func _container(pos: Vector3,color: Color) -> void:
	var size=Vector3(14,3,5); covers.append(Rect2(pos.x-7,pos.z-2.5,14,5))
	_block(size,pos+Vector3.UP*1.5,color)
	for x in range(-6,7,2):
		for side in [-1,1]: Art.box(self,Vector3(0.15,2.7,0.12),pos+Vector3(x,1.5,side*2.55),color.lightened(0.12))
	for x in [-7.05,7.05]: Art.box(self,Vector3(0.12,0.25,5.2),pos+Vector3(x,2.85,0),Color("c2b6a0"))
	for x in [-4,0,4]:
		Art.box(self,Vector3(0.8,0.02,2),pos+Vector3(x,0.025,4),Color("b7a768"))
		var node=MeshInstance3D.new(); var drum=CylinderMesh.new(); drum.top_radius=0.55; drum.bottom_radius=0.55; drum.height=1.4; drum.radial_segments=10
		node.mesh=drum; node.material_override=Art.material(Color("685c42")); node.position=pos+Vector3(x,3.7,0); add_child(node)
func build() -> void:
	_backdrop()
	var cuts=[-92,-64,-52,-32,32,52,64,92]
	var rows=[-80,-58,-30,-28,44,80]
	for xi in cuts.size()-1:
		for zi in rows.size()-1:
			var raised=zi==1
			var concrete=raised or (xi>=2 and xi<=4 and zi>=2 and zi<=3)
			_ground(cuts[xi],cuts[xi+1],rows[zi],rows[zi+1],raised,Color("8c8b7e") if concrete else Color("866b45"))
	# Close the entire raised volume, including the triangular ends of both ramps.
	# A car below the lip must meet a wall rather than enter underneath the surface.
	_terrace_edge(-30); _terrace_edge(-58)
	Art.collider(self,Vector3(128,1,28),Vector3(0,-0.5,-44))
	for x in [-85,85]: _block(Vector3(2,2.4,148),Vector3(x,1.2,0),Color("746653"))
	for z in [-73,73]: _block(Vector3(172,2.4,2),Vector3(0,1.2,z),Color("746653"))
	for entry in [[Vector3(-24,0,-8),Color("9b4b32")],[Vector3(24,0,8),Color("3e7281")],[Vector3(0,0,32),Color("bb963b")],[Vector3(-48,0,28),Color("617451")],[Vector3(48,0,-16),Color("a85c38")],[Vector3(60,0,12),Color("8c4534")],[Vector3(-60,0,-8),Color("b69743")],[Vector3(24,0,44),Color("426d77")]]: _container(entry[0],entry[1])
	# A tank island gives the central courtyard a distinct silhouette and two exits.
	covers.append(Rect2(-6,-20,12,6)); _block(Vector3(12,1,6),Vector3(0,0.5,-17),Color("726f62"))
	for x in [-3,3]:
		var node=MeshInstance3D.new(); var tank=CylinderMesh.new(); tank.top_radius=2; tank.bottom_radius=2; tank.height=6; tank.radial_segments=14
		node.mesh=tank; node.material_override=Art.material(Color("b3b4a2")); node.position=Vector3(x,4,-17); add_child(node)
		Art.collider(self,Vector3(4,6,4),node.position)
		for h in [1.8,5.8]: Art.box(self,Vector3(4.1,0.2,0.25),Vector3(x,h,-14.95),Color("ab8330"))
	# Terrace fascia has a smooth top edge and a broad landing in front.
	for x in range(-28,29,4): Art.box(self,Vector3(1.7,0.08,1.2),Vector3(x,4.04,-30.6),Color("dfb64c"))
	# Crane silhouette outside the traversable area; no roof over the action.
	for x in [-17,17]:
		Art.box(self,Vector3(1.3,17,1.3),Vector3(x,8.5,-76),Color("bf9233"))
	Art.box(self,Vector3(38,1.4,1.5),Vector3(0,17,-76),Color("d3a341"))
	Art.box(self,Vector3(0.16,9,0.16),Vector3(7,12,-76),Color("303a38"))
	var sign=Label3D.new(); sign.text="RUST PIT"; sign.font_size=120; sign.pixel_size=0.035; sign.position=Vector3(0,12,-75); add_child(sign)
	var rng=RandomNumberGenerator.new(); rng.seed=83841
	var trees: Array=[]; var rocks: Array=[]; var shrubs: Array=[]; var grass: Array=[]
	for i in 150:
		var p=Vector3(rng.randf_range(-110,110),0,rng.randf_range(-98,98))
		if map_bounds.grow(4).has_point(Vector2(p.x,p.z)): continue
		p.y=scenery_height(p.x,p.z)
		var transform=Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*rng.randf_range(2,4)),p)
		if i%3==0: rocks.append(transform)
		else: trees.append(transform)
	Art.instances(self,"nature","tree_pineTallA",trees); Art.instances(self,"nature","rock_largeA",rocks)
	for i in 260:
		var side=1 if i%2 else -1
		var p=Vector3(side*rng.randf_range(79,95),0,rng.randf_range(-75,75)) if i%3 else Vector3(rng.randf_range(-85,85),0,side*rng.randf_range(67,83))
		if absf(p.x)<76 and absf(p.z)<65: continue
		p.y=height_at(p) if map_bounds.has_point(Vector2(p.x,p.z)) else scenery_height(p.x,p.z)
		var transform=Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*rng.randf_range(0.7,1.5)),p)
		if i%5==0: shrubs.append(transform)
		else: grass.append(transform)
	Art.instances(self,"nature","plant_bushDetailed",shrubs); Art.instances(self,"nature","grass_large",grass)
	for p in [Vector3(0,0,0),Vector3(-60,0,40),Vector3(60,0,-40),Vector3(-55,0,-35),Vector3(55,0,40),Vector3(0,0,60),Vector3(0,0,-44),Vector3(40,0,48)]:
		p.y=height_at(p)+1; pickup_spots.append(p)
	var id=0
	for x in range(-72,73,12):
		for z in range(-60,61,12):
			var p=Vector3(x,0,z); p.y=height_at(p)
			if safe_point(p,4): graph.add_point(id,p); id+=1
	for a in graph.get_point_ids():
		for b in graph.get_point_ids():
			if b<=a: continue
			var p=graph.get_point_position(a); var q=graph.get_point_position(b)
			if p.distance_to(q)<17.2 and segment_clear(p,q): graph.connect_points(a,b)
