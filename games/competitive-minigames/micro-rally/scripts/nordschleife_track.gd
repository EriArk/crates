# SPDX-License-Identifier: GPL-3.0-or-later
extends "track.gd"
# Geography is the separately licensed OSM/Mapzen data asset, not an invented loop.
const RoadClip = preload("road_projection.gd")
const CELL = 64
const STEP = 4
var data: Dictionary
var lookup: Dictionary = {}
var heights: Dictionary = {}
var tiles: Dictionary = {}
var scenery: Dictionary = {}
var banks = PackedFloat32Array()
var view_cell = Vector2i(999999,999999)
var pending: Array[Vector2i] = []
var max_scenery = 0

func _init() -> void:
	super(false)
	data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/nordschleife/circuit.json"))
	COUNT=data.route.size()
	for q in data.route: points.append(Vector3(q[0],q[1],q[2]))
	# Small authored crest detail below the DEM resolution; the large profile stays geographic.
	for i in COUNT:
		var distance=float(i)/COUNT*20832
		for crest in [2190.0,15330.0,15740.0]: points[i].y+=1.1*exp(-pow((distance-crest)/9.0,2))
	# DEM samples terrain beside/under the road, particularly in wooded cuttings.
	# Project the road profile to the published 18% climb / 11% descent envelope.
	for repeat in 8:
		for i in range(1,COUNT):
			var distance=Vector2(points[i].x-points[i-1].x,points[i].z-points[i-1].z).length()
			points[i].y=clampf(points[i].y,points[i-1].y-distance*0.11,points[i-1].y+distance*0.18)
		for i in range(COUNT-2,-1,-1):
			var distance=Vector2(points[i+1].x-points[i].x,points[i+1].z-points[i].z).length()
			points[i].y=clampf(points[i].y,points[i+1].y-distance*0.18,points[i+1].y+distance*0.11)
	for i in COUNT:
		var delta=points[(i+1)%COUNT]-points[i]; length+=delta.length(); delta.y=0; tangents.append(delta.normalized())
		var cell=Vector2i(floori(points[i].x/32),floori(points[i].z/32))
		for z in range(-4,5):
			for x in range(-4,5):
				var key=cell+Vector2i(x,z)
				if not lookup.has(key): lookup[key]=PackedInt32Array()
				lookup[key].append(i)
	map_bounds=Rect2(Vector2(points[0].x,points[0].z),Vector2.ZERO)
	for p in points: map_bounds=map_bounds.expand(Vector2(p.x,p.z))
	for i in COUNT:
		var distance=float(i)/COUNT*20832; var amount=0.0
		var curve=tangents[posmod(i-3,COUNT)].signed_angle_to(tangents[(i+3)%COUNT],Vector3.UP)/30.5
		for bank in data.banks:
			amount+=float(bank[2])*smoothstep(bank[0],bank[0]+25,distance)*(1-smoothstep(bank[1]-25,bank[1],distance))*smoothstep(0.001,0.008,curve)
		banks.append(amount)

func grid_step() -> float: return STEP
func grid_origin() -> Vector2: return Vector2.ZERO
func grid_bounded() -> bool: return false
func nearest(p: Vector3, hint: int = -1) -> int:
	if hint>=0: return super.nearest(p,hint)
	var key=Vector2i(floori(p.x/32),floori(p.z/32))
	if not lookup.has(key): return super.nearest(p)
	var best=0; var distance=INF
	for i in lookup[key]:
		var d=Vector2(p.x-points[i].x,p.z-points[i].z).length_squared()
		if d<distance: distance=d; best=i
	return best
func section_name(index: int) -> String:
	var name="T13"
	for section in data.sections:
		if section.index>posmod(index,COUNT): break
		name=section.name
	return name
func base_height(x: float, z: float) -> float:
	var grid: Dictionary=data.terrain
	var u=clampf((x-grid.origin[0])/grid.step,0,grid.nx-1.001); var v=clampf((z-grid.origin[1])/grid.step,0,grid.nz-1.001)
	var ix=int(u); var iz=int(v); var stride=int(grid.nx)
	var a=lerpf(grid.values[iz*stride+ix],grid.values[iz*stride+ix+1],u-ix)
	var b=lerpf(grid.values[(iz+1)*stride+ix],grid.values[(iz+1)*stride+ix+1],u-ix)
	return lerpf(a,b,v-iz)
func ground_height(x: float, z: float, index: int, _driving_surface: bool = false) -> float:
	var best=INF; var y=points[index].y
	for i in [posmod(index-1,COUNT),index]:
		var j=(i+1)%COUNT; var a=Vector2(points[i].x,points[i].z); var b=Vector2(points[j].x,points[j].z)
		var t=clampf((Vector2(x,z)-a).dot(b-a)/(b-a).length_squared(),0,1)
		var delta=Vector2(x,z)-a.lerp(b,t); var d=delta.length_squared()
		if d<best:
			best=d; var side=Vector2(-tangents[i].z,tangents[i].x)
			y=lerpf(points[i].y,points[j].y,t)+clampf(delta.dot(side),-6,6)*lerpf(banks[i],banks[j],t)
	return lerpf(y-0.035,base_height(x,z),smoothstep(7.0,24.0,sqrt(best)))
func grid_height(key: Vector2i) -> float:
	if not heights.has(key):
		var p=Vector3(key.x*STEP,0,key.y*STEP); heights[key]=ground_height(p.x,p.z,nearest(p))
	return heights[key]
func surface_height(x: float,z: float) -> float:
	var u=x/STEP; var v=z/STEP; var key=Vector2i(floori(u),floori(v)); var dx=u-floorf(u); var dz=v-floorf(v)
	var a=grid_height(key); var b=grid_height(key+Vector2i(1,0)); var c=grid_height(key+Vector2i(0,1)); var d=grid_height(key+Vector2i.ONE)
	return a+(b-a)*dx+(c-a)*dz if dx+dz<=1 else d+(c-d)*(1-dx)+(b-d)*(1-dz)
func road_pose(at: int,lane: float = 0.0,clearance: float = 0.85) -> Transform3D:
	var tangent=tangents[posmod(at,COUNT)]; var p=points[posmod(at,COUNT)]+Vector3(-tangent.z,0,tangent.x)*lane
	var normal=Vector3(-(surface_height(p.x+0.5,p.z)-surface_height(p.x-0.5,p.z)),1,-(surface_height(p.x,p.z+0.5)-surface_height(p.x,p.z-0.5))).normalized()
	var forward=tangent.slide(normal).normalized(); p.y=surface_height(p.x,p.z)
	return Transform3D(Basis(forward.cross(normal).normalized(),normal,-forward),p+normal*clearance)

func build() -> void:
	rng.seed=38021
	for p in points:
		var cell=Vector2i(floori(p.x/CELL),floori(p.z/CELL))
		for z in range(-1,2):
			for x in range(-1,2): tiles[cell+Vector2i(x,z)]=true
	var ground=meadow_material(false)
	ground.set_shader_parameter("meadow_dark",Color("365936")); ground.set_shader_parameter("meadow_light",Color("678846"))
	for key in tiles: _terrain_tile(key,ground)
	_build_nord_road(); _rails(); _landmarks()
	for i in range(18,COUNT,22):
		pickup_spots.append(road_pose(i,3.5,0).origin+Vector3.UP*0.9)
	update_view(points[0])
func _mesh_node(surface: SurfaceTool, name_value: String, material: Material, origin: Vector3, range_value: float = 160) -> MeshInstance3D:
	surface.index(); surface.generate_normals()
	var node=MeshInstance3D.new(); node.name=name_value; node.mesh=surface.commit(); node.material_override=material
	node.position=origin; node.visibility_range_end=range_value; node.visibility_range_end_margin=20; add_child(node); return node
func _terrain_tile(key: Vector2i, material: Material) -> void:
	var surface=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces=PackedVector3Array(); var origin=Vector3(key.x*CELL,0,key.y*CELL)
	for z in CELL/STEP:
		for x in CELL/STEP:
			var k=key*(CELL/STEP)+Vector2i(x,z)
			for offset in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.RIGHT,Vector2i.ONE,Vector2i.DOWN]:
				var at=k+offset; var p=Vector3(at.x*STEP,grid_height(at),at.y*STEP)
				surface.set_color(Color(0.1,0.6,0.1)); surface.add_vertex(p-origin); faces.append(p)
	_mesh_node(surface,"Ground",material,origin)
	_static_surface(faces,"nord_ground")
func _build_nord_road() -> void:
	road_material=ShaderMaterial.new(); road_material.shader=preload("res://shaders/nord_road.gdshader")
	road_material.set_shader_parameter("karussell",Vector2(data.banks[0][0],data.banks[0][1]))
	road_material.set_shader_parameter("mini_karussell",Vector2(data.banks[1][0],data.banks[1][1]))
	# Small independent render chunks, while all cars retain the full physical route.
	for start in range(0,COUNT,24):
		var surface=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(start,mini(start+24,COUNT)):
			var j=(i+1)%COUNT; var sa=Vector3(-tangents[i].z,0,tangents[i].x)*6; var sb=Vector3(-tangents[j].z,0,tangents[j].x)*6
			var vertices=[points[i]-sa,points[j]-sb,points[i]+sa,points[i]+sa,points[j]-sb,points[j]+sb]
			var a=float(i)/COUNT*20832; var b=float(i+1)/COUNT*20832
			var uv=[Vector2(0,a),Vector2(0,b),Vector2(1,a),Vector2(1,a),Vector2(0,b),Vector2(1,b)]
			for offset in [0,3]: RoadClip.append(self,surface,vertices.slice(offset,offset+3),uv.slice(offset,offset+3))
		# Projection returns world vertices; localise each finished mesh for useful culling bounds.
		surface.index(); surface.generate_normals()
		var arrays=surface.commit().surface_get_arrays(0); var origin=points[start]
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		for i in vertices.size(): vertices[i]-=origin
		arrays[Mesh.ARRAY_VERTEX]=vertices
		var mesh=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var local=SurfaceTool.new(); local.create_from(mesh,0)
		_mesh_node(local,"NordRoad",road_material,origin)
func _rails() -> void:
	var faces=PackedVector3Array(); var metal=Art.material(Color("a5aaa1")).duplicate()
	metal.cull_mode=BaseMaterial3D.CULL_DISABLED
	for start in range(0,COUNT,32):
		var surface=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES); var origin=points[start]
		for i in range(start,mini(start+32,COUNT)):
			var j=(i+1)%COUNT
			for sign_value in [-1,1]:
				var a=road_pose(i,7.4*sign_value,0).origin; var b=road_pose(j,7.4*sign_value,0).origin
				_quad(faces,a-Vector3.UP*0.2,b-Vector3.UP*0.2,b+Vector3.UP*0.9,a+Vector3.UP*0.9)
				for h in [0.45,0.75]:
					for p in [a+Vector3.UP*(h-0.1),b+Vector3.UP*(h-0.1),b+Vector3.UP*(h+0.1),a+Vector3.UP*(h-0.1),b+Vector3.UP*(h+0.1),a+Vector3.UP*(h+0.1)]: surface.add_vertex(p-origin)
		_mesh_node(surface,"Armco",metal,origin)
	_static_surface(faces,"nord_rail")
func _landmarks() -> void:
	for s in data.sections:
		var p=road_pose(int(s.index),9.5,0).origin
		var label=Label3D.new(); label.text=s.name.to_upper(); label.position=p+Vector3.UP*2.1
		label.font_size=72; label.pixel_size=0.012; label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate=Color("f5d968"); label.visibility_range_end=90; add_child(label)
	for mark in [{"at":0,"text":"T13 · NORDSCHLEIFE"},{"at":3785,"text":"DÖTTINGER HÖHE"}]:
		var pose=road_pose(mark.at,0,0); var root=Node3D.new(); root.transform=pose; add_child(root)
		for x in [-8,8]:
			var post=Art.box(root,Vector3(0.6,7,0.6),Vector3(x,3.5,0),Color("69756b")); post.visibility_range_end=160
			Art.collider(root,Vector3(0.6,7,0.6),Vector3(x,3.5,0))
		var beam=Art.box(root,Vector3(17,1.2,0.65),Vector3(0,6.8,0),Color("334b45")); beam.visibility_range_end=160
		var label=Label3D.new(); label.text=mark.text; label.position=Vector3(0,6.8,0.4); label.font_size=80; label.pixel_size=0.009; label.visibility_range_end=160; root.add_child(label)
	# T13 pit building and Brünnchen spectator terraces, with original unbranded geometry.
	for section in [{"at":0,"lane":-18.0,"rows":3},{"at":2805,"lane":20.0,"rows":5}]:
		var root=Node3D.new(); root.transform=road_pose(section.at,section.lane,0); add_child(root)
		for i in section.rows:
			var block=Art.box(root,Vector3(7+i*1.5,0.7,24),Vector3(i*1.4,i*0.75,0),Color("7c8a80")); block.visibility_range_end=150

func update_view(position: Vector3) -> void:
	var key=Vector2i(floori(position.x/CELL),floori(position.z/CELL))
	if key!=view_cell:
		view_cell=key; pending.clear()
		for cell in scenery.keys():
			if absi(cell.x-key.x)>1 or absi(cell.y-key.y)>1: scenery[cell].queue_free(); scenery.erase(cell)
		for z in range(-1,2):
			for x in range(-1,2):
				var cell=key+Vector2i(x,z)
				if tiles.has(cell) and not scenery.has(cell): pending.append(cell)
	# One tile per frame; bounded nine-tile scenery set, independent of lap length.
	if not pending.is_empty():
		var cell=pending.pop_front(); scenery[cell]=_scenery_tile(cell)
	max_scenery=maxi(max_scenery,scenery.size())
func _scenery_tile(key: Vector2i) -> Node3D:
	var root=Node3D.new(); root.name="ForestTile"; add_child(root)
	var random=RandomNumberGenerator.new(); random.seed=absi(key.x*73856093^key.y*19349663)+38021
	var batches={"tree_pineTallA":[],"tree_pineRoundA":[],"plant_bushDetailed":[],"rock_largeA":[],"flower_yellowA":[]}
	for i in 190:
		var p=Vector3((key.x+random.randf())*CELL,0,(key.y+random.randf())*CELL); var at=nearest(p); var edge=road_distance(p,at)
		if edge<10: continue
		p.y=surface_height(p.x,p.z); var id="tree_pineTallA" if i%3 else "tree_pineRoundA"; var factor=random.randf_range(4.5,7)
		if i>100: id="plant_bushDetailed" if i%2 else "flower_yellowA"; factor=random.randf_range(0.8,1.6)
		elif i>85: id="rock_largeA"; factor=random.randf_range(0.8,2.2)
		elif at in range(430,740) and i%3!=0: continue # Flugplatz/Schwedenkreuz clearings.
		if edge<16: factor*=0.65
		batches[id].append(Transform3D(Basis(Vector3.UP,random.randf()*TAU).scaled(Vector3.ONE*factor),p))
	for id in batches: Art.instances(root,"nature",id,batches[id])
	var poses: Array=[]
	for z in 80:
		for x in 80:
			var p=Vector3(key.x*CELL+x*0.8+random.randf()*0.25,0,key.y*CELL+z*0.8+random.randf()*0.25)
			var edge=road_distance(p,nearest(p))
			if edge<6.7 or edge>25: continue
			p.y=surface_height(p.x,p.z)-0.02
			poses.append(Transform3D(Basis(Vector3.UP,random.randf()*TAU).scaled(Vector3.ONE*random.randf_range(1.5,2.2)),p))
	if not poses.is_empty():
		var node=MultiMeshInstance3D.new(); var multi=MultiMesh.new(); multi.transform_format=MultiMesh.TRANSFORM_3D; multi.mesh=_grass_mesh(); multi.instance_count=poses.size()
		var origin=Vector3((key.x+0.5)*CELL,0,(key.y+0.5)*CELL)
		for i in poses.size(): var pose: Transform3D=poses[i]; pose.origin-=origin; multi.set_instance_transform(i,pose)
		node.position=origin; node.multimesh=multi; node.material_override=meadow_material(true); node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; node.visibility_range_end=90; root.add_child(node)
	return root

func road_surface(point: Vector3, at: int) -> int:
	# Same bank spans and inside 66% of the ribbon as nord_road.gdshader.
	var side=Vector3(-tangents[at].z,0,tangents[at].x)
	var u=0.5+(point-points[at]).dot(side)/WIDTH
	var distance=float(at)/COUNT*20832
	for span in data.banks:
		if distance>span[0]+10 and distance<span[1]-10 and u<0.66: return Tires.Kind.CONCRETE
	return Tires.Kind.ASPHALT
