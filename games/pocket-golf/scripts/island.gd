# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
# Decorative environment. The deterministic course rules own all collision/gameplay.
const SEA := preload("res://shaders/sea.gdshader")
const ROOT := "res://assets/kenney/"
var trees: Array[Node3D] = []
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
	for i in 12:
		var a := i*TAU/12.0+0.15
		var p := Vector3(cos(a)*7.9,-0.18,sin(a)*10.8)
		prop("nature/plant_bushDetailed" if i%2 else "nature/plant_bushSmall",p,1.8,a)
		prop("nature/grass_large",p+Vector3(0.6,0,0.2),1.3,a)
		for j in 3:
			prop("nature/flower_yellowA" if (hole+i)%2 else "nature/flower_purpleA",p+Vector3(0.25+j*0.2,0,0.55),1.6,a+j)
	# A small landing, moored rowboat and a distant sailboat make the sea feel inhabited.
	for i in 3: prop("pirate/structure-platform-dock",Vector3(8.5+i*1.8,-1.45,4.0),0.75,PI/2)
	prop("pirate/barrel",Vector3(8.0,-0.35,4.65),0.36,0.4)
	boat=prop("pirate/boat-row-small",Vector3(13.0,-1.52,6.3),0.70,-0.5)
	prop("pirate/ship-small",Vector3(-32,-1.55,-39),0.75,0.8)
	for i in 7:
		prop("nature/stone_smallFlatA",Vector3(6.0+i*0.32,-0.15,3.8),1.1,0.3*i)
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
			mesh.set_surface_override_material(surface,materials[key])
	instance.position=at; instance.scale=Vector3.ONE*size; instance.rotation.y=heading
	add_child(instance); imported_count+=1
	if id.begins_with("nature/") and ("tree_" in id or "plant_" in id or "flower_" in id or "grass_" in id):
		_clear_green(instance)
		# The original nature models have a -0.05 m base offset.
		if Vector2(instance.position.x,instance.position.z).length()<20:
			instance.position.y=ground_height(instance.position)+0.05*size
	return instance

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
	var rings := [Vector3(8.4,-0.24,11.7),Vector3(8.8,-0.42,12.1),Vector3(9.1,-0.73,12.5),Vector3(10.7,-1.30,14.2),Vector3(11.9,-2.20,15.5)]
	var p := Vector2(point.x,point.z)
	var a := atan2(point.z/11.7,point.x/8.4)
	var shape := 1.0+0.045*sin(a*3.0+0.4)+0.025*cos(a*7.0)
	var dir := p.normalized(); var distance := p.length()
	var previous := 0.0; var height := -0.24
	for ring in rings:
		var radius: float = shape/sqrt(pow(dir.x/ring.x,2)+pow(dir.y/ring.z,2)) if distance>0 else 1.0
		if distance<=radius: return lerpf(height,ring.y,clampf((distance-previous)/(radius-previous),0,1))
		previous=radius; height=ring.y
	return height

func _outline(a: float, radius: Vector2, y: float) -> Vector3:
	var shape := 1.0+0.045*sin(a*3.0+0.4)+0.025*cos(a*7.0)
	return Vector3(cos(a)*radius.x*shape,y,sin(a)*radius.y*shape)

func _terrain() -> void:
	var rings := [Vector3(8.4,-0.24,11.7),Vector3(8.8,-0.42,12.1),Vector3(9.1,-0.73,12.5),Vector3(10.7,-1.30,14.2),Vector3(11.9,-2.20,15.5)]
	var colors := [Color("8eb87f"),Color("7fa96d"),Color("c7a873"),Color("ecd49c"),Color("b6bf98")]
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 64:
		var a := i*TAU/64.0; var b := (i+1)*TAU/64.0
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
	var mat := StandardMaterial3D.new(); mat.vertex_color_use_as_albedo=true; mat.roughness=1.0
	terrain.material_override=mat; terrain.name="IslandTerrain"; add_child(terrain)

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
