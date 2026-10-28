# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
const Art = preload("art.gd")
const WIDTH = 12.0
const COUNT = 320
var points = PackedVector3Array()
var tangents = PackedVector3Array()
var length = 0.0
var rng = RandomNumberGenerator.new()
var pickup_spots: Array[Vector3] = []
var terrain_vertices = PackedVector3Array()
var road_material: ShaderMaterial
var spatial_candidates: Dictionary = {}
var map_bounds = Rect2()
const SEARCH_CELL = 8.0

func set_wetness(value: float) -> void:
	if road_material!=null: road_material.set_shader_parameter("wetness",clampf(value,0,1))

func _init() -> void:
	_sample_route(_anchors())

func _anchors() -> Array:
	# Closed authored valley route: broad sweep, bridge, climb, hairpin, return.
	return [Vector3(0,0,32),Vector3(-32,0,35),Vector3(-65,0,12),Vector3(-72,0,-24),Vector3(-45,0,-55),Vector3(-8,0,-48),Vector3(12,0,-72),Vector3(47,0,-70),Vector3(68,0,-42),Vector3(44,0,-12),Vector3(65,0,18),Vector3(45,0,54),Vector3(15,0,60)]

func _sample_route(anchors: Array) -> void:
	for i in COUNT:
		var t = float(i)/COUNT*anchors.size(); var k = int(t); var f = t-k
		var a: Vector3=anchors[posmod(k-1,anchors.size())]; var b: Vector3=anchors[k]
		var c: Vector3=anchors[(k+1)%anchors.size()]; var d: Vector3=anchors[(k+2)%anchors.size()]
		var p = 0.5*((2*b)+(-a+c)*f+(2*a-5*b+4*c-d)*f*f+(-a+3*b-3*c+d)*f*f*f)
		p.y=base_height(p.x,p.z)+0.07; points.append(p)
	for i in COUNT:
		var v = points[(i+1)%COUNT]-points[i]; length+=v.length(); v.y=0; tangents.append(v.normalized())
	map_bounds=Rect2(Vector2(points[0].x,points[0].z),Vector2.ZERO)
	for point in points: map_bounds=map_bounds.expand(Vector2(point.x,point.z))

func base_height(x: float, z: float) -> float:
	return 2.8+sin(x*0.032)*1.7+cos(z*0.035)*2.0+sin((x+z)*0.055)*0.55

func nearest(p: Vector3, hint: int = -1) -> int:
	var best = 0; var distance = INF
	if hint<0:
		var cell = Vector2i(floori(p.x/SEARCH_CELL),floori(p.z/SEARCH_CELL))
		if not spatial_candidates.has(cell):
			var center = (Vector2(cell)+Vector2(0.5,0.5))*SEARCH_CELL
			var center_distance = INF
			for point in points: center_distance=minf(center_distance,center.distance_squared_to(Vector2(point.x,point.z)))
			# Triangle inequality: any possible winner lies within d(center)+2r.
			# Keep original index order so ties match the exhaustive search exactly.
			var radius = sqrt(center_distance)+SEARCH_CELL*sqrt(2.0)+0.0001
			var candidates = PackedInt32Array()
			for i in COUNT:
				if center.distance_squared_to(Vector2(points[i].x,points[i].z))<=radius*radius: candidates.append(i)
			spatial_candidates[cell]=candidates
		for i in spatial_candidates[cell]:
			var d = Vector2(p.x-points[i].x,p.z-points[i].z).length_squared()
			if d<distance: distance=d; best=i
		return best
	var start = 0 if hint<0 else hint-22
	var end = COUNT if hint<0 else hint+23
	for n in range(start,end):
		var i = posmod(n,COUNT)
		var d = p.distance_squared_to(points[i])
		if d<distance: distance=d; best=i
	return best

func road_distance(p: Vector3, index: int) -> float:
	var side = Vector3(-tangents[index].z,0,tangents[index].x)
	return absf((p-points[index]).dot(side))

func steps_ahead(index: int, meters: float) -> int:
	var distance=0.0
	for step in range(1,COUNT):
		distance+=points[posmod(index+step-1,COUNT)].distance_to(points[posmod(index+step,COUNT)])
		if distance>=meters: return step
	return COUNT-1

func ground_height(x: float, z: float, index: int, driving_surface: bool = false) -> float:
	var d = Vector2(x-points[index].x,z-points[index].z).length()
	var hill = smoothstep(7.5,19.0,d)*(1.8+sin(x*0.11)*cos(z*0.09)*2.2)
	var stream = 1.0-smoothstep(3.0,7.0,absf(x+30.0))
	var best_distance = INF; var road_y = points[index].y
	for segment in [posmod(index-1,COUNT),index]:
		var a = points[segment]; var b = points[(segment+1)%COUNT]
		var av = Vector2(a.x,a.z); var bv = Vector2(b.x,b.z)
		var t = clampf((Vector2(x,z)-av).dot(bv-av)/(bv-av).length_squared(),0,1)
		var distance = Vector2(x,z).distance_squared_to(av.lerp(bv,t))
		if distance<best_distance: best_distance=distance; road_y=lerpf(a.y,b.y,t)
	var distance = sqrt(best_distance)
	# One continuous driving surface: no raised ribbon edge to catch the chassis.
	# The visible creek remains below bridges; cars never drive under these spans.
	if driving_surface: stream*=smoothstep(6.3,10.0,distance)
	return lerpf(road_y-0.035,base_height(x,z)+hill,smoothstep(6.0,12.0,distance))-stream*6.0

func build() -> void:
	rng.seed=38021
	_build_terrain(); _build_road(); _build_stream(); _decorate(); _grass()
	for i in range(15,COUNT,35):
		var side = Vector3(-tangents[i].z,0,tangents[i].x)
		pickup_spots.append(points[i]+side*3.6+Vector3.UP*0.8)

func _build_terrain() -> void:
	var surface = SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const N = 108; const STEP = 2.0
	var vertices = PackedVector3Array()
	var collision_vertices = PackedVector3Array()
	var faces = PackedVector3Array()
	for z in N+1:
		for x in N+1:
			var px = (x-N/2)*STEP; var pz = (z-N/2)*STEP
			var at = nearest(Vector3(px,0,pz))
			vertices.append(Vector3(px,ground_height(px,pz,at),pz))
			collision_vertices.append(Vector3(px,ground_height(px,pz,at,true),pz))
	for z in N:
		for x in N:
			var a = z*(N+1)+x; var b = a+1; var c = a+N+1; var d = c+1
			for i in [a,b,c,b,d,c]:
				surface.set_color(Color(0.1,0.6,0.1)); surface.add_vertex(vertices[i])
				faces.append(collision_vertices[i])
	terrain_vertices=vertices
	surface.index(); surface.generate_normals()
	var mesh = surface.commit(); var node = MeshInstance3D.new(); node.mesh=mesh
	var mat = meadow_material(false); node.material_override=mat
	add_child(node)
	_static_surface(faces,"driving_surface")

func _static_surface(faces: PackedVector3Array, group: String) -> StaticBody3D:
	if faces.is_empty(): return null
	var body = StaticBody3D.new(); var collider = CollisionShape3D.new()
	var shape = ConcavePolygonShape3D.new(); shape.set_faces(faces)
	shape.backface_collision=true; collider.shape=shape
	body.add_child(collider); add_child(body); body.add_to_group(group)
	return body

func _quad(faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	faces.append_array(PackedVector3Array([a,b,c,a,c,d]))

func _bridge_segment(i: int) -> bool:
	return absf(points[posmod(i,COUNT)].lerp(points[posmod(i+1,COUNT)],0.5).x+30)<=9.0

func road_divisions() -> int: return 1
func road_vertex(point: Vector3) -> Vector3: return point

func _build_road() -> void:
	var surface = SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var distance = 0.0
	for i in COUNT:
		var j = (i+1)%COUNT; var a = points[i]; var b = points[j]
		var side_a = Vector3(-tangents[i].z,0,tangents[i].x)*WIDTH*0.5
		var side_b = Vector3(-tangents[j].z,0,tangents[j].x)*WIDTH*0.5
		var next = distance+a.distance_to(b)
		for cross_section in road_divisions():
			var u=float(cross_section)/road_divisions(); var v=float(cross_section+1)/road_divisions()
			var al=road_vertex(a+side_a*(u*2-1)); var ar=road_vertex(a+side_a*(v*2-1))
			var bl=road_vertex(b+side_b*(u*2-1)); var br=road_vertex(b+side_b*(v*2-1))
			var vertices = [al,bl,ar,ar,bl,br]
			var uvs = [Vector2(u,distance),Vector2(u,next),Vector2(v,distance),Vector2(v,distance),Vector2(u,next),Vector2(v,next)]
			for n in 6: surface.set_uv(uvs[n]); surface.add_vertex(vertices[n])
		distance=next
	surface.generate_normals(); surface.index()
	var node = MeshInstance3D.new(); node.mesh=surface.commit()
	node.name="RoadSurface"
	road_material=ShaderMaterial.new(); road_material.shader=preload("res://shaders/road.gdshader"); node.material_override=road_material
	add_child(node) # Visible road only; ground and bridge decks share one collider.
	var rail_faces = PackedVector3Array()
	# Planked bridges wherever the authored route crosses the creek.
	for i in COUNT:
		var j = (i+1)%COUNT; var center = points[i].lerp(points[j],0.5)
		if not _bridge_segment(i): continue
		var span = points[j]-points[i]
		var side_a = Vector3(-tangents[i].z,0,tangents[i].x)
		var side_b = Vector3(-tangents[j].z,0,tangents[j].x)
		var plank = Art.box(self,Vector3(WIDTH+0.3,0.15,span.length()+0.12),center+Vector3.UP*0.11,Color("8e6843"))
		plank.look_at(plank.position+span,Vector3.UP)
		for s in [-1,1]:
			var a = points[i]+side_a*(WIDTH*0.5+0.15)*s; var b = points[j]+side_b*(WIDTH*0.5+0.15)*s
			var pos = a.lerp(b,0.5); var edge = b-a
			Art.box(self,Vector3(0.22,1.5,0.22),a+Vector3.UP*0.65,Color("634a35"))
			for height in [0.45,1.1]:
				var rail = Art.box(self,Vector3(0.18,0.2,edge.length()+0.12),pos+Vector3.UP*height,Color("a27a50"))
				rail.look_at(rail.position+edge,Vector3.UP)
			# Joined wall strips have no overlapping box end-caps inside a bend.
			var ai = a-side_a*0.18; var ao = a+side_a*0.18
			var bi = b-side_b*0.18; var bo = b+side_b*0.18
			var low = Vector3.DOWN*0.1; var high = Vector3.UP*1.4
			_quad(rail_faces,ai+low,bi+low,bi+high,ai+high)
			_quad(rail_faces,ao+low,ao+high,bo+high,bo+low)
			_quad(rail_faces,ai+high,bi+high,bo+high,ao+high)
			_quad(rail_faces,ai+low,ao+low,bo+low,bi+low)
			if not _bridge_segment(i-1): _quad(rail_faces,ai+low,ai+high,ao+high,ao+low)
			if not _bridge_segment(i+1): _quad(rail_faces,bi+low,bo+low,bo+high,bi+high)
	_static_surface(rail_faces,"bridge_rail")

func _build_stream() -> void:
	var plane = PlaneMesh.new(); plane.size=Vector2(10,210); plane.subdivide_depth=30
	var water = MeshInstance3D.new(); water.mesh=plane; water.position=Vector3(-30,-0.25,0)
	var mat = ShaderMaterial.new(); mat.shader=preload("res://shaders/water.gdshader"); water.material_override=mat
	add_child(water)

func _decorate() -> void:
	var batches: Dictionary={}
	for id in ["tree_pineRoundA","tree_pineRoundB","tree_pineTallA","tree_pineSmallA","rock_largeA","rock_largeC","plant_bushDetailed","plant_bushSmall","grass_large","flower_yellowA","flower_purpleA"]: batches[id]=[]
	for n in 8500:
		var x = rng.randf_range(-100,100); var z = rng.randf_range(-100,100)
		var p = Vector3(x,0,z); var i = nearest(p); var distance = p.distance_to(Vector3(points[i].x,0,points[i].z))
		if distance<8.3 or absf(x+30)<6.3: continue
		p.y=surface_height(x,z)
		var id: String
		var scale_factor = 1.0
		if n<2100:
			id=["tree_pineRoundA","tree_pineRoundB","tree_pineTallA","tree_pineSmallA"][n%4]
			scale_factor=rng.randf_range(3.5,5.6)
			if distance<12: scale_factor*=0.65
		elif n<2600: id=["rock_largeA","rock_largeC"][n%2]; scale_factor=rng.randf_range(0.7,2.4)
		elif n<3800: id=["plant_bushDetailed","plant_bushSmall"][n%2]; scale_factor=rng.randf_range(0.8,1.8)
		else: id=["grass_large","grass_large","flower_yellowA","flower_purpleA"][n%4]; scale_factor=rng.randf_range(0.6,1.2)
		batches[id].append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale_factor),p))
	for id in batches: Art.instances(self,"nature",id,batches[id])
	# Low roadside fences and chevrons leave the racing surface unobstructed.
	for i in range(0,COUNT,5):
		if absf(points[i].x+30)<9: continue
		var side = Vector3(-tangents[i].z,0,tangents[i].x)
		for sign_value in [-1,1]:
			var pos = points[i]+side*7.8*sign_value
			var post = Art.box(self,Vector3(0.17,0.9,0.17),pos+Vector3.UP*0.4,Color("8a704c"))
			var rail = Art.box(self,Vector3(0.12,0.17,5),pos+Vector3.UP*0.75,Color("aa8758")); rail.rotation.y=atan2(-tangents[i].x,-tangents[i].z)
			post.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Start/finish arch is an actual world landmark.
	var side = Vector3(-tangents[0].z,0,tangents[0].x)
	for s in [-1,1]: Art.box(self,Vector3(0.45,5,0.45),points[0]+side*7*s+Vector3.UP*2.5,Color("e6c883"))
	var sign_node = Label3D.new(); sign_node.text="DIRTY VALLEY"; sign_node.font_size=100; sign_node.pixel_size=0.009
	sign_node.position=points[0]+Vector3.UP*4.9; sign_node.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sign_node)

func _grass_mesh() -> ArrayMesh:
	# Original opaque geometry: no alpha cards, texture shimmer or downloaded code.
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in 5:
		var angle := blade*2.39996
		var side := Vector3(cos(angle),0,sin(angle))
		var base := Vector3(sin(angle)*0.065,0,cos(angle)*0.065)
		var height := 0.16+0.025*(blade%3)
		var width := 0.034+0.006*(blade%2)
		var bend := Vector3(cos(angle+0.7),0,sin(angle+0.7))*0.05
		var points := [base-side*width,base+side*width,base+Vector3.UP*height*0.55+bend*0.3-side*width*0.7,base+Vector3.UP*height*0.55+bend*0.3+side*width*0.7,base+Vector3.UP*height+bend]
		for index in [0,2,1,1,2,3,2,4,3]:
			surface.set_normal(Vector3.UP); surface.set_uv(Vector2(0,points[index].y/height))
			surface.add_vertex(points[index])
	return surface.commit()

func meadow_material(grass: bool) -> ShaderMaterial:
	var mat = ShaderMaterial.new(); mat.shader=preload("res://shaders/meadow.gdshader")
	mat.set_shader_parameter("grass",grass)
	mat.set_shader_parameter("meadow_dark",Color("526c35"))
	mat.set_shader_parameter("meadow_light",Color("82964a"))
	return mat

func surface_height(x: float, z: float) -> float:
	var gx = clampf((x+108)/2,0,107.999); var gz = clampf((z+108)/2,0,107.999)
	var ix = int(gx); var iz = int(gz); var dx = gx-ix; var dz = gz-iz
	var a = terrain_vertices[iz*109+ix].y; var b = terrain_vertices[iz*109+ix+1].y
	var c = terrain_vertices[(iz+1)*109+ix].y; var d = terrain_vertices[(iz+1)*109+ix+1].y
	return a+(b-a)*dx+(c-a)*dz if dx+dz<=1 else d+(c-d)*(1-dx)+(b-d)*(1-dz)

func _grass() -> void:
	var mesh = _grass_mesh(); var mat = meadow_material(true)
	var cells: Dictionary={}
	# Golf's five-blade opaque tufts, triangle height, and spatial chunks.
	for x_step in range(-204,205):
		for z_step in range(-204,205):
			var x = x_step*0.5+rng.randf_range(-0.16,0.16); var z = z_step*0.5+rng.randf_range(-0.16,0.16)
			var p = Vector3(x,0,z); var at = nearest(p)
			var distance = Vector2(x-points[at].x,z-points[at].z).length()
			if distance<6.7 or distance>30 or absf(x+30)<5.8: continue
			p.y=surface_height(x,z)-0.018
			var key = Vector2i(floori(x/16),floori(z/16))
			if not cells.has(key): cells[key]=[]
			cells[key].append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(1.5,2.3)),p))
	for key in cells:
		var node = MultiMeshInstance3D.new(); var multi = MultiMesh.new(); multi.transform_format=MultiMesh.TRANSFORM_3D; multi.mesh=mesh
		multi.instance_count=cells[key].size(); var origin = Vector3(key.x*16,0,key.y*16)
		for i in cells[key].size():
			var pose: Transform3D=cells[key][i]; pose.origin-=origin; multi.set_instance_transform(i,pose)
		node.multimesh=multi; node.material_override=mat; node.position=origin; node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end=65; node.visibility_range_end_margin=10; add_child(node)


func surface_at(point: Vector3) -> Vector3:
	var at=nearest(point)
	var edge=road_distance(point,at)
	# x: friction, y: lateral ratio, z: rolling resistance. Weather scales friction in the car.
	if edge>WIDTH*0.5+1.0: return Vector3(0.72,0.92,1.15)
	return Vector3(1.22,1.0,0.35)

func road_pose(at: int, lane: float = 0.0, clearance: float = 0.85) -> Transform3D:
	var tangent=tangents[posmod(at,COUNT)]
	var side=Vector3(-tangent.z,0,tangent.x)
	var point=points[posmod(at,COUNT)]+side*lane
	var eps=0.5
	var dx=ground_height(point.x+eps,point.z,nearest(point+Vector3.RIGHT*eps),true)-ground_height(point.x-eps,point.z,nearest(point-Vector3.RIGHT*eps),true)
	var dz=ground_height(point.x,point.z+eps,nearest(point+Vector3.BACK*eps),true)-ground_height(point.x,point.z-eps,nearest(point-Vector3.BACK*eps),true)
	var normal=Vector3(-dx/(2*eps),1,-dz/(2*eps)).normalized()
	var forward=tangent.slide(normal).normalized()
	point.y=ground_height(point.x,point.z,at,true)
	return Transform3D(Basis(forward.cross(normal).normalized(),normal,-forward),point+normal*clearance)
