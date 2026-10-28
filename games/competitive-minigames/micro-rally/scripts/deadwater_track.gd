# SPDX-License-Identifier: GPL-3.0-or-later
extends "arena_track.gd"
# Authored 900x700m county. Terrain, roads and planning data are generated together.
var FINALS: Array[Vector2]=[]
var roads: Array=[]
var bridges: Array=[]
var river: Array[Vector2]=[]
var roofs: Array=[]
var bridge_nodes: Array[int]=[]
var spawns: Array[Transform3D]=[]
var pickup_types: Array=[]
var data: Dictionary
var heights=PackedFloat32Array()
var road_cells: Dictionary={}
var nav_cells: Dictionary={}
var terrain_origin=Vector2.ZERO
var nx=0
var nz=0
const STEP=4.0
const NAV_REVISION=1
var rebuild_navigation=false
var loaded_navigation=false
func _init() -> void:
	map_bounds=Rect2(-450,-350,900,700)
	data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/deadwater/county.json"))
	heights=FileAccess.get_file_as_bytes("res://assets/deadwater/terrain.f32").to_float32_array()
	nx=int(data.terrain.nx); nz=int(data.terrain.nz); terrain_origin=Vector2(data.terrain.origin[0],data.terrain.origin[1])
	for p in data.finals: FINALS.append(Vector2(p[0],p[2]))
	for p in data.river: river.append(Vector2(p[0],p[1]))
	for entry in data.bridges: bridges.append({"a":v3(entry.a),"b":v3(entry.b),"width":float(entry.width),"name":entry.name})
	for entry in data.roads:
		var points=PackedVector3Array()
		for p in entry.points: points.append(v3(p))
		var road={"points":points,"width":float(entry.width),"kind":entry.kind,"name":entry.name}; roads.append(road)
		for i in points.size()-1:
			var a=points[i]; var b=points[i+1]
			for x in range(floori((minf(a.x,b.x)-20)/32),floori((maxf(a.x,b.x)+20)/32)+1):
				for z in range(floori((minf(a.z,b.z)-20)/32),floori((maxf(a.z,b.z)+20)/32)+1):
					var cell=Vector2i(x,z)
					if not road_cells.has(cell): road_cells[cell]=[]
					road_cells[cell].append([a,b,road.width,road.kind])
static func v3(p: Array) -> Vector3: return Vector3(p[0],p[1],p[2])
static func flat(p: Vector3) -> Vector2: return Vector2(p.x,p.z)
func height_at(p: Vector3) -> float:
	var f=(flat(p)-terrain_origin)/STEP; var x=clampi(floori(f.x),0,nx-2); var z=clampi(floori(f.y),0,nz-2)
	var u=clampf(f.x-x,0,1); var v=clampf(f.y-z,0,1)
	var a=heights[z*nx+x]; var b=heights[z*nx+x+1]; var c=heights[(z+1)*nx+x+1]; var d=heights[(z+1)*nx+x]
	return a+(b-a)*u+(c-b)*v if u>=v else a+(c-d)*u+(d-a)*v
func river_distance(p: Vector3) -> float:
	var result=INF
	for i in river.size()-1: result=minf(result,flat(p).distance_to(Geometry2D.get_closest_point_to_segment(flat(p),river[i],river[i+1])))
	return result
func bridge_at(p: Vector3,margin: float=0) -> int:
	for i in bridges.size():
		var bridge=bridges[i]; var a=flat(bridge.a); var b=flat(bridge.b); var delta=b-a
		var along=(flat(p)-a).dot(delta)/delta.length_squared()
		if along>=0 and along<=1 and flat(p).distance_to(a+delta*along)<bridge.width/2-margin: return i
	return -1
func on_bridge(p: Vector3) -> bool: return p.y>9.5 and bridge_at(p)>=0
func wet_channel(p: Vector3) -> bool:
	var road=road_near(p)
	return river_distance(p)<8 and not (not road.is_empty() and road[0]<0 and road[1]=="ford")
func surface_height(p: Vector3) -> float: return 12.0 if on_bridge(p) else height_at(p)
func safe_point(p: Vector3,margin: float=3) -> bool:
	if not super.safe_point(p,margin): return false
	if on_bridge(p): return bridge_at(p,margin)>=0
	return not wet_channel(p) and not (bridge_at(p)>=0 and height_at(p)>7.5)
func segment_clear(a: Vector3,b: Vector3) -> bool:
	if absf(a.y-b.y)>flat(a).distance_to(flat(b))*0.38+0.2: return false
	for i in range(1+ceili(a.distance_to(b)/3)):
		var p=a.lerp(b,float(i)/maxi(1,ceili(a.distance_to(b)/3)))
		if not safe_point(p,2.6) or absf(p.y-surface_height(p))>1.1: return false
	return true
func road_near(p: Vector3) -> Array:
	var best=[]; var distance=INF
	for s in road_cells.get(Vector2i(floori(p.x/32),floori(p.z/32)),[]):
		var d=flat(p).distance_to(Geometry2D.get_closest_point_to_segment(flat(p),flat(s[0]),flat(s[1])))-s[2]/2
		if d<distance: distance=d; best=[d,s[3]]
	return best
func tire_surface_at(p: Vector3) -> int:
	if on_bridge(p): return Tires.Kind.CONCRETE
	var road=road_near(p)
	if not road.is_empty() and road[0]<0: return Tires.Kind.GRAVEL if road[1] in ["dirt","lower","ford"] else Tires.Kind.ASPHALT
	return Tires.Kind.MUD if river_distance(p)<35 else Tires.Kind.GRAVEL if p.z>200 else Tires.Kind.GRASS
func district(p: Vector3) -> String:
	if p.x>285 and p.z< -90: return "HYDRO WORKS"
	if p.z< -100: return "PINE RIDGE" if p.x<0 else "ARGO HEIGHTS"
	if p.z>130: return "REDSTONE PIT" if p.x<20 else "EAST WORKSHOPS"
	if river_distance(p)<35: return "RIVER SERVICE"
	return "OLD TOWN"
func _mesh(st: SurfaceTool,mat: Material,collision: bool,pos: Vector3=Vector3.ZERO) -> MeshInstance3D:
	st.generate_normals(); var mesh=st.commit(); var node=MeshInstance3D.new(); node.mesh=mesh; node.material_override=mat; node.position=pos; add_child(node)
	if collision:
		var body=StaticBody3D.new(); body.position=pos; var shape=CollisionShape3D.new(); shape.shape=mesh.create_trimesh_shape(); body.add_child(shape); add_child(body)
	return node
func _land() -> void:
	var mat=ShaderMaterial.new(); mat.shader=preload("res://shaders/county_ground.gdshader"); mat.set_shader_parameter("road_map",load("res://assets/deadwater/road-mask.png")); surfaces.append(mat)
	# Local 64m mesh origins let renderer cull the world while all car physics remains.
	for cx in range(0,nx-1,16):
		for cz in range(0,nz-1,16):
			var origin=Vector3(terrain_origin.x+cx*STEP,0,terrain_origin.y+cz*STEP)
			var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for x in range(cx,mini(cx+16,nx-1)):
				for z in range(cz,mini(cz+16,nz-1)):
					for index in [Vector2i(x,z),Vector2i(x+1,z),Vector2i(x+1,z+1),Vector2i(x,z),Vector2i(x+1,z+1),Vector2i(x,z+1)]:
						var p=Vector3(terrain_origin.x+index.x*STEP,heights[index.y*nx+index.x],terrain_origin.y+index.y*STEP)
						st.set_uv(flat(p)); st.add_vertex(p-origin)
			_mesh(st,mat,true,origin)
func _roads() -> void:
	# River follows the same polyline used by wetness and gameplay checks.
	var water=SurfaceTool.new(); water.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in river.size()-1:
		var a=Vector3(river[i].x,0.18,river[i].y); var b=Vector3(river[i+1].x,0.18,river[i+1].y); var side=(b-a).cross(Vector3.UP).normalized()*7
		for p in [a+side,a-side,b-side,a+side,b-side,b+side]: water.add_vertex(p)
	_mesh(water,Art.material(Color("267f97")),false)
func _bridges() -> void:
	for bridge in bridges:
		var center: Vector3=(bridge.a+bridge.b)/2; center.y=11.4
		var direction: Vector3=(bridge.b-bridge.a).normalized(); var length: float=bridge.a.distance_to(bridge.b); var yaw=atan2(direction.x,direction.z)
		var root=Node3D.new(); add_child(root); root.position=center; root.rotation.y=yaw
		Art.box(root,Vector3(bridge.width,1.2,length),Vector3.ZERO,Color("a1a08b")); Art.collider(root,Vector3(bridge.width,1.2,length),Vector3.ZERO)
		for side in [-1,1]:
			Art.box(root,Vector3(0.55,1,length),Vector3(side*(bridge.width/2-0.25),1.1,0),Color("b4aa8a"))
			Art.collider(root,Vector3(0.55,1,length),Vector3(side*(bridge.width/2-0.25),1.1,0))
			# Supports stay outside the driveable lower bank; no hidden pillars in paths.
			for along in [-length*0.45,length*0.45]:
				Art.box(root,Vector3(1,7,1),Vector3(side*(bridge.width/2-0.6),-3.5,along),Color("777f73"))
func _box(st: SurfaceTool,size: Vector3,pos: Vector3,color: Color) -> void:
	var mesh=BoxMesh.new(); mesh.size=size
	var arrays=mesh.get_mesh_arrays(); var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]; var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	for index in indices: st.set_color(color); st.add_vertex(vertices[index]+pos)
func _buildings() -> void:
	var material=StandardMaterial3D.new(); material.vertex_color_use_as_albedo=true; material.roughness=0.9
	for entry in data.buildings:
		var pos=v3(entry.position); var size=v3(entry.size); var w=size.x; var h=size.y; var d=size.z; var yaw=float(entry.yaw)
		var root=Node3D.new(); add_child(root); root.position=pos; root.rotation.y=yaw
		var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var colors=[Color("b66d43"),Color("c1ac7c"),Color("7e9792"),Color("a49b85")]; var color: Color=colors[int(entry.variant)]
		_box(st,Vector3(w,h+4,d),Vector3(0,h/2-2,0),color)
		_box(st,Vector3(w+1,0.2,d+1),Vector3(0,0,0),Color("92978b"))
		for side in [-1,1]:
			for x in [-w*0.28,w*0.28]:
				_box(st,Vector3(w*0.22,2,0.12),Vector3(x,h*0.65,side*(d/2+0.08)),Color("426e7d"))
			_box(st,Vector3(2,2.8,0.18),Vector3(0,1.4,side*(d/2+0.1)),Color("454b42"))
		if entry.kind=="shop":
			for x in [-w*0.3,w*0.3]: _box(st,Vector3(4,2.7,0.16),Vector3(x,1.8,d/2+0.1),Color("305e70"))
			_box(st,Vector3(w+0.4,0.3,2.5),Vector3(0,3.4,d/2+0.8),Color("cda946"))
			_box(st,Vector3(w,0.9,0.3),Vector3(0,h-0.7,d/2+0.15),Color("dfc49a"))
		elif entry.kind=="warehouse":
			for x in [-w*0.27,w*0.27]: _box(st,Vector3(6,4.5,0.18),Vector3(x,2.25,d/2+0.1),Color("566971"))
		st.generate_normals(); var body=MeshInstance3D.new(); body.mesh=st.commit(); body.material_override=material; body.visibility_range_end=190; root.add_child(body)
		Art.collider(root,Vector3(w,h+4,d),Vector3(0,h/2-2,0))
		var ext=Vector2(absf(cos(yaw))*w+absf(sin(yaw))*d,absf(sin(yaw))*w+absf(cos(yaw))*d)
		covers.append(Rect2(flat(pos)-ext/2,ext))
		var roof=SurfaceTool.new(); roof.begin(Mesh.PRIMITIVE_TRIANGLES)
		if entry.kind=="house":
			var a=Vector3(-w/2-0.5,h,-d/2-0.5); var b=Vector3(w/2+0.5,h,-d/2-0.5); var c=Vector3(w/2+0.5,h,d/2+0.5); var f=Vector3(-w/2-0.5,h,d/2+0.5); var t=Vector3(0,h+3,-d/2-0.5); var u=Vector3(0,h+3,d/2+0.5)
			for tri in [[a,t,u],[a,u,f],[t,b,c],[t,c,u],[a,b,t],[f,u,c]]:
				for p in tri: roof.set_color(Color("914d36")); roof.add_vertex(p)
		else: _box(roof,Vector3(w+1,0.5,d+1),Vector3(0,h,0),Color("555f5b"))
		roof.generate_normals(); var cap=MeshInstance3D.new(); cap.mesh=roof.commit(); cap.material_override=material; cap.visibility_range_end=190; root.add_child(cap); roofs.append([cap,pos])
func _nav_add(p: Vector3) -> void:
	if not safe_point(p,3): return
	var cell=Vector2i(floori(p.x/16),floori(p.z/16))
	for id in nav_cells.get(cell,[]):
		if graph.get_point_position(id).distance_to(p)<1.8: return
	var id=graph.get_point_count(); graph.add_point(id,p)
	if not nav_cells.has(cell): nav_cells[cell]=[]
	nav_cells[cell].append(id)
	if on_bridge(p): bridge_nodes.append(id)
func navigation_identity() -> String:
	return str(NAV_REVISION)+":"+FileAccess.get_sha256("res://assets/deadwater/county.json")+":"+FileAccess.get_sha256("res://assets/deadwater/terrain.f32")
func navigation_snapshot() -> Dictionary:
	var points=[]; var edges=[]
	for id in graph.get_point_ids():
		var p=graph.get_point_position(id); points.append([id,p.x,p.y,p.z])
		for other in graph.get_point_connections(id):
			if other>id: edges.append([id,other])
	return {"identity":navigation_identity(),"points":points,"edges":edges}
func _navigation() -> void:
	var path="res://assets/deadwater/navigation.json"
	if not rebuild_navigation and FileAccess.file_exists(path):
		var cache=JSON.parse_string(FileAccess.get_file_as_string(path))
		if cache is Dictionary and cache.get("identity","")==navigation_identity():
			for p in cache.points:
				graph.add_point(int(p[0]),Vector3(p[1],p[2],p[3]))
				if on_bridge(graph.get_point_position(int(p[0]))): bridge_nodes.append(int(p[0]))
			for edge in cache.edges: graph.connect_points(int(edge[0]),int(edge[1]))
			loaded_navigation=true
	if not loaded_navigation: _compute_navigation()
	_navigation_items()
func _compute_navigation() -> void:
	for x in range(-432,433,16):
		for z in range(-336,337,16):
			var p=Vector3(x,0,z); p.y=height_at(p)
			if bridge_at(p)>=0 and p.y>7: continue
			_nav_add(p)
	for road in roads:
		for i in range(0,road.points.size(),2):
			var p: Vector3=road.points[i]; p.y=12 if road.kind=="bridge" and bridge_at(p)>=0 else height_at(p); _nav_add(p)
	for cell in nav_cells:
		for a in nav_cells[cell]:
			var p=graph.get_point_position(a)
			for dx in range(-2,3):
				for dz in range(-2,3):
					for b in nav_cells.get(cell+Vector2i(dx,dz),[]):
						if b<=a: continue
						var q=graph.get_point_position(b)
						if p.distance_to(q)<23 and segment_clear(p,q): graph.connect_points(a,b)
	# Remove unreachable decorative pockets; retained routes are checked separately.
	var seed=graph.get_closest_point(v3(data.spawns[0])); var seen={seed:true}; var queue=[seed]; var cursor=0
	while cursor<queue.size():
		for id in graph.get_point_connections(queue[cursor]):
			if not seen.has(id): seen[id]=true; queue.append(id)
		cursor+=1
	for id in graph.get_point_ids():
		if not seen.has(id): graph.remove_point(id)
func _navigation_items() -> void:
	for index in data.spawns.size():
		var p=v3(data.spawns[index]); p.y=height_at(p); p=graph.get_point_position(graph.get_closest_point(p)); spawns.append(Transform3D(Basis.IDENTITY,p+Vector3.UP*0.9))
	for road in roads:
		for i in range(8,road.points.size(),30):
			var p: Vector3=road.points[i]; p.y=12 if road.kind=="bridge" and bridge_at(p)>=0 else height_at(p); p=graph.get_point_position(graph.get_closest_point(p))
			if pickup_spots.any(func(q):return q.distance_to(p)<36): continue
			pickup_spots.append(p+Vector3.UP); pickup_types.append(["repair","rocket","shield","cool","pulse"][pickup_types.size()%5])
func _scenery() -> void:
	var rng=RandomNumberGenerator.new(); rng.seed=716042
	var trees=[]; var grass=[]; var rocks=[]
	for i in 5200:
		var p=Vector3(rng.randf_range(-475,475),0,rng.randf_range(-375,375)); p.y=height_at(p)
		var road=road_near(p)
		if not safe_point(p,5) or (not road.is_empty() and road[0]<7): continue
		var tr=Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*rng.randf_range(1.4,3.2)),p)
		if p.z< -120 and i%3==0: trees.append(tr)
		elif i%11==0: rocks.append(tr)
		else: grass.append(tr)
	Art.instances(self,"nature","tree_pineTallA",trees); Art.instances(self,"nature","rock_largeA",rocks); Art.instances(self,"nature","grass_large",grass)
	for x in [-454,454]:
		for z in range(-350,351,16): _block(Vector3(4,8,16),Vector3(x,height_at(Vector3(x,0,z))+2,z),Color("6d775b"))
	for z in [-354,354]:
		for x in range(-450,451,16): _block(Vector3(16,8,4),Vector3(x,height_at(Vector3(x,0,z))+2,z),Color("6d775b"))
func spawn_pose(slot: int) -> Transform3D: return spawns[slot%spawns.size()]
func pickup_kind(i: int) -> String: return pickup_types[i]
func build() -> void:
	_land(); _roads(); _bridges(); _buildings(); _navigation(); _scenery()
func update_view(pos: Vector3) -> void:
	for item in roofs: item[0].visible=item[1].distance_to(pos)>19
