# SPDX-License-Identifier: GPL-3.0-or-later
extends "arena_track.gd"
# Real layered navigation: terrain nodes and elevated bridge nodes coexist at XZ.
const BRIDGES=[-108.0,0.0,108.0]
const FINALS=[Vector2(-132,-72),Vector2(156,60),Vector2(132,-108),Vector2(-132,108)]
var roads: Array[Rect2]=[]
var roofs: Array=[]
var bridge_nodes: Array[int]=[]
var ground_nodes: Dictionary={}
var spawns: Array[Transform3D]=[]
var pickup_types: Array=[]
func _init() -> void: map_bounds=Rect2(-180,-180,360,360)
func height_at(p: Vector3) -> float:
	var bank=12*smoothstep(8,40,absf(p.x))
	var east=18*smoothstep(70,170,p.x)*smoothstep(20,130,p.z)
	var forest=14*smoothstep(70,170,-p.x)*smoothstep(20,150,p.z)
	var quarry=10*smoothstep(65,155,p.x)*smoothstep(40,150,-p.z)
	return bank+east+forest+quarry
func on_bridge(p: Vector3) -> bool:
	for z in BRIDGES:
		if absf(p.x)<40 and absf(p.z-z)<9 and p.y>8: return true
	return false
func wet_channel(p: Vector3) -> bool: return (absf(p.x)<6 and p.z<144 and absf(p.z)>12 and absf(p.z+108)>12) or (absf(p.x)<30 and p.z< -126)
func safe_point(p: Vector3,margin: float=3) -> bool:
	if not super.safe_point(p,margin): return false
	if on_bridge(p): return true
	if p.z< -126 and absf(p.x)<30+margin: return false
	for z in BRIDGES:
		if p.y<10 and absf(absf(p.x)-28)<1.2+margin and absf(absf(p.z-z)-7)<1.2+margin: return false
	return absf(p.x)>6+margin or p.z>144+margin or absf(p.z)<12-margin or absf(p.z+108)<12-margin
func segment_clear(a: Vector3,b: Vector3) -> bool:
	for i in range(17):
		var p=a.lerp(b,i/16.0)
		if not safe_point(p,2.8): return false
		if not on_bridge(p) and absf(p.y-height_at(p))>1: return false
	return absf(a.y-b.y)<Vector2(a.x-b.x,a.z-b.z).length()*0.48+0.1
func spawn_pose(slot: int) -> Transform3D: return spawns[slot%spawns.size()]
func tire_surface_at(p: Vector3) -> int:
	if on_bridge(p): return Tires.Kind.CONCRETE
	for road in roads:
		if road.has_point(Vector2(p.x,p.z)): return Tires.Kind.ASPHALT
	return Tires.Kind.GRAVEL if p.x>65 and p.z< -30 else Tires.Kind.MUD if absf(p.x)<40 else Tires.Kind.GRASS
func district(p: Vector3) -> String:
	if absf(p.x)<42: return "HYDRO WORKS" if p.z< -65 else "RIVER CROSSING"
	if p.x<0: return "PINE RIDGE" if p.z>35 else "OLD TOWN"
	return "REDSTONE PIT" if p.z< -35 else "EAST WORKSHOPS"
func _mesh(st: SurfaceTool,mat: Material,collision: bool) -> MeshInstance3D:
	st.generate_normals(); var mesh=st.commit(); var node=MeshInstance3D.new(); node.mesh=mesh; node.material_override=mat; add_child(node)
	if collision:
		var body=StaticBody3D.new(); var shape=CollisionShape3D.new(); shape.shape=mesh.create_trimesh_shape(); body.add_child(shape); add_child(body)
	return node
func _land() -> void:
	# One stitched height field; roads are visual overlays and cannot snag tyres.
	var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-240,240,4):
		for z in range(-240,240,4):
			var corners=[Vector3(x,0,z),Vector3(x+4,0,z),Vector3(x+4,0,z+4),Vector3(x,0,z+4)]
			for n in [0,1,2,0,2,3]:
				var p: Vector3=corners[n]; p.y=height_at(p); st.set_uv(Vector2(p.x,p.z)); st.add_vertex(p)
	var mat=ShaderMaterial.new(); mat.shader=preload("res://shaders/county_ground.gdshader"); surfaces.append(mat); _mesh(st,mat,true)
func _road(rect: Rect2) -> void:
	roads.append(rect)
	var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(int(rect.position.x),int(rect.end.x),4):
		for z in range(int(rect.position.y),int(rect.end.y),4):
			var corners=[Vector3(x,0,z),Vector3(minf(x+4,rect.end.x),0,z),Vector3(minf(x+4,rect.end.x),0,minf(z+4,rect.end.y)),Vector3(x,0,minf(z+4,rect.end.y))]
			for n in [0,1,2,0,2,3]:
				var p: Vector3=corners[n]; p.y=height_at(p)+0.045; st.add_vertex(p)
	var asphalt=ShaderMaterial.new(); asphalt.shader=preload("res://shaders/county_road.gdshader"); surfaces.append(asphalt); _mesh(st,asphalt,false)
func _bridge(z: float,index: int) -> void:
	# Clear 10m underpass; bank approaches meet the deck without a raised seam.
	_block(Vector3(80,1.2,18),Vector3(0,11.4,z),Color("989d92"))
	for side in [-1,1]:
		_block(Vector3(80,1.1,0.65),Vector3(0,12.55,z+side*8.7),Color("b0ac96"))
		for x in [-28,28]: _block(Vector3(2.4,11,2.4),Vector3(x,5.5,z+side*7),Color("827e6f"))
		for x in range(-36,37,8): Art.box(self,Vector3(2,0.035,0.22),Vector3(x,12.02,z+side*6.5),Color("dbbc5b"))
	if index==0:
		for x in [-44,44]:
			covers.append(Rect2(x-3.5,z-15.5,7,7))
			_block(Vector3(7,17,7),Vector3(x,18.5,z-12),Color("8d998d"))
			Art.box(self,Vector3(8,1,8),Vector3(x,27.5,z-12),Color("45575a"))
		Art.box(self,Vector3(96,1,2),Vector3(0,29,z-12),Color("cba049"))
		_sign("DEADWATER HYDRO",Vector3(0,24,z-12),0.045)
func _sign(text: String,pos: Vector3,pixel: float=0.025) -> void:
	var label=Label3D.new(); label.text=text; label.font_size=100; label.pixel_size=pixel; label.position=pos; add_child(label)
func _house(x: float,z: float,w: float,d: float,h: float,color: Color) -> void:
	var pos=Vector3(x,height_at(Vector3(x,0,z)),z)
	Art.box(self,Vector3(w+3,0.12,d+3),pos+Vector3.DOWN*0.04,Color("a4a48e"))
	covers.append(Rect2(x-w/2,z-d/2,w,d))
	_block(Vector3(w,h+2,d),pos+Vector3.UP*(h/2-1),color)
	var roof=Art.box(self,Vector3(w+1,0.6,d+1),pos+Vector3.UP*h,Color("8e4736")); roof.set_meta("focus",pos); roofs.append(roof)
	# A pitched cap gives the town a readable silhouette from the chase camera.
	var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a=Vector3(-w/2-0.5,0,-d/2-0.5); var b=Vector3(w/2+0.5,0,-d/2-0.5); var c=Vector3(w/2+0.5,0,d/2+0.5); var f=Vector3(-w/2-0.5,0,d/2+0.5)
	var t=Vector3(0,2.5,-d/2-0.5); var u=Vector3(0,2.5,d/2+0.5)
	for tri in [[a,t,u],[a,u,f],[t,b,c],[t,c,u],[a,b,t],[f,u,c]]:
		for p in tri: st.add_vertex(pos+Vector3.UP*h+p)
	var cap=_mesh(st,Art.material(Color("a64e38")),false); cap.set_meta("focus",pos); roofs.append(cap)
	for side in [-1,1]:
		for dx in [-w*0.27,w*0.27]:
			Art.box(self,Vector3(w*0.18,1.8,0.12),pos+Vector3(dx,h*0.6,side*(d/2+0.06)),Color("527d8c"))
		Art.box(self,Vector3(2,2.7,0.14),pos+Vector3(0,1.35,side*(d/2+0.1)),Color("4c4b3d"))
func _navigation() -> void:
	var id=0
	for x in range(-168,169,12):
		for z in range(-168,169,12):
			var p=Vector3(x,0,z); p.y=height_at(p)
			var ceiling=false
			for bridge_z in BRIDGES:
				if absf(x)<40 and absf(z-bridge_z)<10 and p.y>8: ceiling=true
			if safe_point(p,3.2) and not ceiling: graph.add_point(id,p); ground_nodes[Vector2i(x,z)]=id; id+=1
	for key in ground_nodes:
		for offset in [Vector2i(12,0),Vector2i(0,12),Vector2i(12,12),Vector2i(-12,12)]:
			var next=key+offset
			if not ground_nodes.has(next): continue
			var a: int=ground_nodes[key]; var b: int=ground_nodes[next]
			if segment_clear(graph.get_point_position(a),graph.get_point_position(b)): graph.connect_points(a,b)
	for z in BRIDGES:
		var previous=-1
		for x in range(-48,49,12):
			var node_id: int
			if abs(x)>=48: node_id=ground_nodes[Vector2i(x,int(z))]
			else:
				node_id=id; id+=1; graph.add_point(node_id,Vector3(x,12,z)); bridge_nodes.append(node_id)
			if previous>=0: graph.connect_points(previous,node_id)
			previous=node_id
	# Stable, widely separated starts, projected onto the connected road graph.
	for p in [Vector2(-156,-144),Vector2(-96,-144),Vector2(-48,-108),Vector2(48,-144),Vector2(108,-144),Vector2(156,-96),Vector2(156,-24),Vector2(156,48),Vector2(144,144),Vector2(84,144),Vector2(36,156),Vector2(-36,156),Vector2(-96,144),Vector2(-156,108),Vector2(-156,36),Vector2(-156,-48)]:
		var pos=Vector3(p.x,0,p.y); pos.y=height_at(pos); pos=graph.get_point_position(graph.get_closest_point(pos))
		spawns.append(Transform3D(Basis(Vector3.UP,atan2(pos.x,pos.z)),pos+Vector3.UP*0.9))
func build() -> void:
	_land()
	for x in [-132,-96,-60,60,108,156]: _road(Rect2(x-7,-172,14,344))
	for z in [-108,-72,-24,0,60,108,156]:
		_road(Rect2(-174,z-6,134,12)); _road(Rect2(40,z-6,134,12))
	for z in range(-164,169,8):
		for x in [-132,-96,-60,60,108,156]:
			var mark=Vector3(x,height_at(Vector3(x,0,z))+0.065,z)
			Art.box(self,Vector3(0.18,0.025,2.6),mark,Color("bcba94"))
	for i in BRIDGES.size(): _bridge(BRIDGES[i],i)
	_road(Rect2(-40,148,80,16))
	for extent in [[-180,-120],[-96,-12],[12,144]]:
		var water=Art.box(self,Vector3(10,0.1,extent[1]-extent[0]),Vector3(0,0.25,(extent[0]+extent[1])*0.5),Color("286c86")); water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_road(Rect2(-16,-10,32,20)); _road(Rect2(-16,-118,32,20))
	var reservoir=Art.box(self,Vector3(60,0.12,54),Vector3(0,9,-153),Color("286c86")); reservoir.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x in [-114,-78]:
		for z in [-138,-90,-48,24]: _house(x,z,15,19,6+(int(z)%3),Color("b9b092") if x==-114 else Color("bda072"))
	_sign("DEADWATER",Vector3(-96,18,-158))
	for z in [-120,-60,12,48]:
		for x in [-123,-87,-51]:
			var p=Vector3(x,height_at(Vector3(x,0,z)),z)
			Art.box(self,Vector3(0.25,6,0.25),p+Vector3.UP*3,Color("394a4a"))
			Art.box(self,Vector3(1.2,0.22,0.65),p+Vector3(0.4,6,0),Color("e4cb87"))
	for z in [-138,-48,24]:
		for x in [-114,-78]:
			var p=Vector3(x,height_at(Vector3(x,0,z)),z+13)
			for side in [-1,1]:
				for step in range(2,8): Art.box(self,Vector3(0.18,1,0.18),p+Vector3(side*step,0.5,0),Color("827552"))
				Art.box(self,Vector3(5.8,0.15,0.16),p+Vector3(side*4.7,0.7,0),Color("a2966b"))
	# Workshops surround a traversable court; each block is separated by a full street.
	for p in [Vector2(82,30),Vector2(132,30),Vector2(82,90),Vector2(132,90)]: _house(p.x,p.y,23,22,7,Color("79938e"))
	_sign("EAST WORKSHOPS",Vector3(110,25,12))
	for p in [Vector3(78,0,-42),Vector3(138,0,-72),Vector3(132,0,-126)]:
		p.y=height_at(p); _container(p,Color("b37b3f"))
	_sign("REDSTONE PIT",Vector3(114,25,-150))
	# Broad outlying slopes, forest pockets and rock groups remain out of road corridors.
	var rng=RandomNumberGenerator.new(); rng.seed=71604
	var trees: Array=[]; var rocks: Array=[]; var grass: Array=[]
	for i in 1600:
		var p=Vector3(rng.randf_range(-215,215),0,rng.randf_range(-210,210)); p.y=height_at(p)
		if absf(p.x)<42 or not safe_point(p,5): continue
		var road=false
		for rect in roads:
			if rect.grow(4).has_point(Vector2(p.x,p.z)): road=true; break
		if road: continue
		var transform=Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*rng.randf_range(1.7,3.4)),p)
		if i%9==0: rocks.append(transform)
		elif p.z>40 and p.x< -40 or absf(p.x)>165: trees.append(transform)
		else: grass.append(Transform3D(transform.basis.scaled(Vector3.ONE*0.5),p))
	Art.instances(self,"nature","tree_pineTallA",trees); Art.instances(self,"nature","rock_largeA",rocks); Art.instances(self,"nature","grass_large",grass)
	for side in [-1,1]:
		for v in range(-180,180,12):
			var p=Vector3(side*183,0,v); p.y=height_at(p)+2; _block(Vector3(3,6,12),p,Color("737b64"))
			p=Vector3(v,0,side*183); p.y=height_at(p)+2; _block(Vector3(12,6,3),p,Color("737b64"))
	# Drive-through service shed: solid side walls, a real roof, open ends.
	var shed=Vector3(108,height_at(Vector3(108,0,132)),132)
	for side in [-1,1]:
		var wall=shed+Vector3(side*10,3,0); _block(Vector3(2,6,16),wall,Color("7e8580")); covers.append(Rect2(wall.x-1,wall.z-8,2,16))
	var roof=Art.box(self,Vector3(24,0.5,19),shed+Vector3.UP*6.5,Color("536a70")); roof.set_meta("focus",shed); roofs.append(roof)
	Art.collider(self,Vector3(24,0.5,19),shed+Vector3.UP*6.5)
	_sign("SERVICE",shed+Vector3(0,5,9),0.02)
	_navigation()
	for p in [Vector2(-96,-72),Vector2(-60,-24),Vector2(-144,-108),Vector2(-132,108),Vector2(-96,156),Vector2(-60,60),Vector2(60,60),Vector2(108,60),Vector2(156,108),Vector2(108,-84),Vector2(60,-108),Vector2(156,-24),Vector2(0,0),Vector2(0,108),Vector2(0,-108),Vector2(0,156)]:
		var pos=Vector3(p.x,12 if p.x==0 and p.y!=156 else height_at(Vector3(p.x,0,p.y)),p.y)
		pos=graph.get_point_position(graph.get_closest_point(pos)); pickup_spots.append(pos+Vector3.UP)
		pickup_types.append(["repair","rocket","shield","cool","pulse"][pickup_types.size()%5])
func pickup_kind(i: int) -> String: return pickup_types[i]
func update_view(pos: Vector3) -> void:
	# Hide only roof decoration close to the followed car; buildings stay physical.
	for roof in roofs: roof.visible=Vector3(roof.get_meta("focus")).distance_to(pos)>15
