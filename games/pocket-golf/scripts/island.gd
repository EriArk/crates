# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
# Decorative environment. The deterministic course rules own all collision/gameplay.
const SEA := preload("res://shaders/sea.gdshader")
const MEADOW := preload("res://shaders/meadow.gdshader")
const Surfaces := preload("res://scripts/surfaces.gd")
const ROOT := "res://assets/kenney/"
const RINGS := [Vector3(8.4,-0.24,11.7),Vector3(8.8,-0.42,12.1),Vector3(9.1,-0.73,12.5),Vector3(10.7,-1.30,14.2),Vector3(11.9,-2.20,15.5)]
# x/z, height and footprint. Lower foreground dunes preserve the low camera views.
const HILLS := [Vector4(-6.9,-5.4,1.7,2.6),Vector4(3.2,-10.0,2.1,3.0),Vector4(-3.7,-10.2,1.25,2.5),Vector4(7.0,-2.6,1.35,2.7),Vector4(-7.0,4.2,0.95,2.8),Vector4(2.8,10.3,0.65,2.8),Vector4(-3.6,10.0,0.55,2.3)]
var trees: Array[Node3D] = []
var planting: Array[Node3D] = []
var grass_positions: Array[Vector3] = []
var terrain_vertices := PackedVector3Array()
var terrain_cells: Dictionary = {}
var boat: Node3D
var flag: Node3D
var clock := 0.0
var models: Dictionary = {}
var materials: Dictionary = {}
var imported_count := 0

func build(hole: int) -> void:
	_terrain()
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new(); plane.size=Vector2(1600,1600)
	water.mesh=plane; water.position.y=-1.55
	var sea := ShaderMaterial.new(); sea.shader=SEA
	water.material_override=sea; water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.name="Ocean"; add_child(water)
	# Tall silhouettes stay behind or beside the playable rectangle, with low foreground planting.
	for item in [[-7.1,-6.2,2.7],[-4.9,-10.2,2.1],[6.8,-7.8,2.45],[7.8,-2.5,2.3],[-7.5,3.4,2.2]]:
		var tree := prop("nature/tree_palmDetailedTall" if trees.size()%2==0 else "nature/tree_palmBend",Vector3(item[0],-0.16,item[1]),item[2],trees.size()*1.7+hole*0.6)
		trees.append(tree)
	for item in [[-6.7,-0.7,1.9],[-3.2,-10.7,1.7],[5.5,-10.0,1.8]]:
		var tree := prop("nature/tree_oak" if hole!=1 else "nature/tree_small",Vector3(item[0],-0.16,item[1]),item[2],hole+0.6)
		trees.append(tree)
	for i in 16:
		var a := i*TAU/16.0+0.2
		var point := Vector3(cos(a)*9.9,-1.05,sin(a)*13.3)
		prop("nature/stone_largeA" if i%3 else "nature/stone_largeC",point,1.2+(i%3)*0.4,a)
	_plant_gardens(hole)
	# A small landing, moored rowboat and a distant sailboat make the sea feel inhabited.
	for i in 3: prop("pirate/structure-platform-dock",Vector3(8.5+i*1.8,-1.45,4.0),0.75,PI/2)
	prop("pirate/barrel",Vector3(8.0,-0.35,4.65),0.36,0.4)
	boat=prop("pirate/boat-row-small",Vector3(13.0,-1.52,6.3),0.70,-0.5)
	prop("pirate/ship-small",Vector3(-32,-1.55,-39),0.75,0.8)
	for i in 7:
		var step := Vector3(6.0+i*0.32,0,3.8)
		step.y=surface_height(step)+0.035
		prop("nature/stone_smallFlatA",step,1.1,0.3*i)
	# A pair of low rocky islets, well outside every gameplay camera target.
	for i in 5:
		prop("nature/rock_largeC",Vector3(26+i*1.3,-1.6,-27+i*0.6),3.3-i*0.25,i*0.8)
	prop("nature/tree_palmBend",Vector3(28,-0.8,-26),2.7,1.7)
	_clouds()

func prop(id: String, at: Vector3, size: float=1.0, heading: float=0.0) -> Node3D:
	if not models.has(id): models[id]=load(ROOT+id+".glb")
	var instance: Node3D = models[id].instantiate()
	# Keep the downloaded models unchanged; make scene-local matte palette variants.
	for mesh in instance.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var original: Material = mesh.mesh.surface_get_material(surface)
			if not original is StandardMaterial3D: continue
			var key := id+"/"+original.resource_name
			if not materials.has(key):
				var mat: StandardMaterial3D = original.duplicate()
				mat.metallic=0; mat.roughness=0.95
				var palette := {"leafsGreen":"609c70","grass":"78aa76","woodBark":"b58a60","stone":"a9b9b4"}
				if palette.has(original.resource_name): mat.albedo_color=Color(palette[original.resource_name])
				materials[key]=mat
				var kind := -1
				if original.resource_name=="woodBark": kind=Surfaces.Kind.WOOD
				elif original.resource_name=="stone" or "stone_" in id or "rock_" in id: kind=Surfaces.Kind.STONE
				elif original.resource_name=="leafsGreen": kind=Surfaces.Kind.LEAF
				elif id=="pirate/structure-platform-dock" or id=="pirate/barrel": kind=Surfaces.Kind.WOOD
				if kind>=0: materials[key]=Surfaces.make(mat.albedo_color,kind,Vector3.UP,mat.albedo_texture)
			mesh.set_surface_override_material(surface,materials[key])
	instance.position=at; instance.scale=Vector3.ONE*size; instance.rotation.y=heading
	add_child(instance); imported_count+=1
	if id.begins_with("nature/") and ("tree_" in id or "plant_" in id or "flower_" in id or "grass_" in id):
		_clear_green(instance)
		# The original nature models have a -0.05 m base offset.
		if Vector2(instance.position.x,instance.position.z).length()<20:
			instance.position.y=surface_height(instance.position)+0.05*size
			planting.append(instance)
	return instance

func _plant_gardens(hole: int) -> void:
	# Local seeded randomness never consumes gameplay RNG. Clusters leave gaps and a dock path.
	var rng := RandomNumberGenerator.new(); rng.seed=7319+hole*137
	for i in 26:
		var a := i*TAU/26.0+0.1
		var center := Vector3(cos(a)*7.5,0,sin(a)*10.3)
		if center.x>5.5 and absf(center.z-3.8)<1.7: continue
		for j in 3:
			var p := center+Vector3(rng.randf_range(-0.8,0.8),0,rng.randf_range(-0.8,0.8))
			prop("nature/plant_bushDetailed" if j==0 else "nature/plant_bushSmall",p,rng.randf_range(1.4,2.4),rng.randf()*TAU)
		for j in 4:
			var p := center+Vector3(rng.randf_range(-1.0,1.0),0,rng.randf_range(-1.0,1.0))
			prop("nature/flower_yellowA" if (hole+i)%3 else "nature/flower_purpleA",p,rng.randf_range(1.0,1.7),rng.randf()*TAU)
	_meadow(hole)

func meadow_allowed(p: Vector3) -> bool:
	if absf(p.x)<5.65 and absf(p.z)<8.65: return false
	if p.x>5.5 and absf(p.z-3.8)<0.8: return false
	var a := atan2(p.z/11.7,p.x/8.4)
	var shape := 1.0+0.045*sin(a*3.0+0.4)+0.025*cos(a*7.0)
	return (Vector2(p.x,p.z)/Vector2(8.55,11.85)).length()<shape

func _meadow(hole: int) -> void:
	# Stratified coverage over the whole grassy surface, including the hilltops.
	var rng := RandomNumberGenerator.new(); rng.seed=9427+hole*113
	var chunks: Dictionary = {}
	for x in range(-57,58):
		for z in range(-79,80):
			var p := Vector3(x*0.16+rng.randf_range(-0.055,0.055),0,z*0.16+rng.randf_range(-0.055,0.055))
			if not meadow_allowed(p): continue
			p.y=surface_height(p)-0.012
			grass_positions.append(p)
			var cell := Vector2i(floori(p.x/4.0),floori(p.z/4.0))
			if not chunks.has(cell): chunks[cell]=[]
			var size := rng.randf_range(0.8,1.25)
			chunks[cell].append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*size),p))
	var mesh := _grass_mesh()
	var material := ShaderMaterial.new(); material.shader=MEADOW; material.set_shader_parameter("grass",true)
	for cell in chunks:
		var batch := MultiMesh.new(); batch.transform_format=MultiMesh.TRANSFORM_3D
		batch.mesh=mesh; batch.instance_count=chunks[cell].size()
		var origin := Vector3(cell.x*4.0,0,cell.y*4.0)
		for i in batch.instance_count:
			var placement: Transform3D = chunks[cell][i]; placement.origin-=origin
			batch.set_instance_transform(i,placement)
		var draw := MultiMeshInstance3D.new(); draw.multimesh=batch; draw.material_override=material
		draw.position=origin; draw.name="Meadow_%s_%s"%[cell.x,cell.y]
		draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draw.extra_cull_margin=0.25; draw.visibility_range_end=150.0; add_child(draw)

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

func visual_bounds(instance: Node3D) -> AABB:
	var bounds := AABB(); var first := true
	for child in instance.find_children("*","MeshInstance3D",true,false):
		var box: AABB = child.global_transform*child.get_aabb()
		bounds=box if first else bounds.merge(box); first=false
	return bounds

func _clear_green(instance: Node3D) -> void:
	var b := visual_bounds(instance)
	if b.position.x>=5.4 or b.end.x<=-5.4 or b.position.z>=8.4 or b.end.z<=-8.4: return
	var dx: float = 5.5-b.position.x if instance.position.x>=0 else -5.5-b.end.x
	var dz: float = 8.5-b.position.z if instance.position.z>=0 else -8.5-b.end.z
	if absf(dx)<absf(dz): instance.position.x+=dx
	else: instance.position.z+=dz

func ground_height(point: Vector3) -> float:
	var p := Vector2(point.x,point.z)
	var a := atan2(point.z/11.7,point.x/8.4)
	var shape := 1.0+0.045*sin(a*3.0+0.4)+0.025*cos(a*7.0)
	var dir := p.normalized(); var distance := p.length()
	var previous := 0.0; var height := -0.24
	for ring in RINGS:
		var radius: float = shape/sqrt(pow(dir.x/ring.x,2)+pow(dir.y/ring.z,2)) if distance>0 else 1.0
		if distance<=radius: return lerpf(height,ring.y,clampf((distance-previous)/(radius-previous),0,1))+_relief(p)
		previous=radius; height=ring.y
	return height

func _relief(p: Vector2) -> float:
	var clearance := maxf(absf(p.x)-5.35,absf(p.y)-8.35)
	var edge := smoothstep(0.0,1.4,clearance)
	var coast := 1.0-smoothstep(0.87,1.08,(p/Vector2(8.8,12.1)).length())
	var path := smoothstep(0.55,1.5,absf(p.y-3.8)) if p.x>5.0 else 1.0
	var hills := 0.0
	for hill in HILLS:
		var distance: float = (p-Vector2(hill.x,hill.y)).length()/hill.w
		hills+=hill.z*exp(-distance*distance*1.35)
	return hills*edge*coast*path

func surface_height(point: Vector3) -> float:
	# Ground props on the rendered triangles, not the continuous curve between vertices.
	var cell := Vector2i(floori(point.x),floori(point.z))
	for i in terrain_cells.get(cell,[]):
		var a := terrain_vertices[i]; var b := terrain_vertices[i+1]; var c := terrain_vertices[i+2]
		var divisor := (b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)
		if absf(divisor)<0.000001: continue
		var u := ((b.z-c.z)*(point.x-c.x)+(c.x-b.x)*(point.z-c.z))/divisor
		var v := ((c.z-a.z)*(point.x-c.x)+(a.x-c.x)*(point.z-c.z))/divisor
		if u>=-0.00001 and v>=-0.00001 and u+v<=1.00001:
			return a.y*u+b.y*v+c.y*(1.0-u-v)
	return ground_height(point)

func _outline(a: float, radius: Vector2, y: float) -> Vector3:
	var shape := 1.0+0.045*sin(a*3.0+0.4)+0.025*cos(a*7.0)
	var point := Vector3(cos(a)*radius.x*shape,y,sin(a)*radius.y*shape)
	point.y=ground_height(point)
	return point

func _terrain() -> void:
	var rings: Array[Vector3] = []
	var colors: Array[Color] = []
	# Subdivide the interior too: a center fan cannot represent rolling ground.
	for i in range(1,25):
		rings.append(Vector3(8.4*i/24.0,-0.24,11.7*i/24.0)); colors.append(Color("8eb87f"))
	var shore_colors := [Color("7fa96d"),Color("c7a873"),Color("ecd49c"),Color("b6bf98")]
	for i in 4:
		for j in range(1,5):
			rings.append(RINGS[i].lerp(RINGS[i+1],j/4.0)); colors.append(shore_colors[i])
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 96:
		var a := i*TAU/96.0; var b := (i+1)*TAU/96.0
		var first: Vector3 = rings[0]
		_triangle(surface,Vector3(0,first.y,0),_outline(b,Vector2(first.x,first.z),first.y),_outline(a,Vector2(first.x,first.z),first.y),colors[0])
		for r in rings.size()-1:
			var inner: Vector3 = rings[r]; var outer: Vector3 = rings[r+1]
			var p := _outline(a,Vector2(inner.x,inner.z),inner.y)
			var q := _outline(b,Vector2(inner.x,inner.z),inner.y)
			var s := _outline(a,Vector2(outer.x,outer.z),outer.y)
			var t := _outline(b,Vector2(outer.x,outer.z),outer.y)
			_triangle(surface,p,q,t,colors[r+1]); _triangle(surface,p,t,s,colors[r+1])
	surface.generate_normals()
	var terrain := MeshInstance3D.new(); terrain.mesh=surface.commit()
	var mat := ShaderMaterial.new(); mat.shader=MEADOW
	terrain.material_override=mat; terrain.name="IslandTerrain"; add_child(terrain)
	terrain_vertices=terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for i in range(0,terrain_vertices.size(),3):
		var a := terrain_vertices[i]; var b := terrain_vertices[i+1]; var c := terrain_vertices[i+2]
		for x in range(floori(minf(a.x,minf(b.x,c.x))),floori(maxf(a.x,maxf(b.x,c.x)))+1):
			for z in range(floori(minf(a.z,minf(b.z,c.z))),floori(maxf(a.z,maxf(b.z,c.z)))+1):
				var cell := Vector2i(x,z)
				if not terrain_cells.has(cell): terrain_cells[cell]=[]
				terrain_cells[cell].append(i)

func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	# Godot uses clockwise front faces.
	surface.set_color(color); surface.add_vertex(a); surface.add_vertex(c); surface.add_vertex(b)

func _clouds() -> void:
	var white := StandardMaterial3D.new(); white.albedo_color=Color("f7f6e9"); white.roughness=1
	for i in 8:
		var cloud := Node3D.new(); cloud.position=Vector3(-65+i*19,14+(i%3)*4,-60-(i%2)*20); add_child(cloud)
		for j in 4:
			var puff := MeshInstance3D.new(); var sphere := SphereMesh.new()
			sphere.radius=2.0+(j%2)*0.7; sphere.height=sphere.radius*1.5; sphere.radial_segments=16; sphere.rings=8
			puff.mesh=sphere; puff.material_override=white; puff.position=Vector3(j*2.5,0.5*(j%2),0)
			puff.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; cloud.add_child(puff)

func _process(delta: float) -> void:
	clock+=delta
	for i in trees.size(): trees[i].rotation.z=sin(clock*0.65+i)*0.012
	if boat!=null:
		boat.position.y=-1.52+sin(clock*1.2)*0.045
		boat.rotation.z=sin(clock*0.9)*0.025
	if flag!=null: flag.rotation.y=0.2+sin(clock*0.8)*0.08
