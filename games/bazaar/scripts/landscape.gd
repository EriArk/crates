# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
## Golf's bounded meadow approach adapted to a walkable, multi-district island.
const MEADOW = preload("res://shaders/meadow.gdshader")
const SEA = preload("res://shaders/sea.gdshader")
const HILLS := [Vector4(-13,-51,8,18),Vector4(20,-57,6,16),Vector4(56,22,7,17),Vector4(-50,27,6,16),Vector4(28,46,4.5,15),Vector4(-55,-50,5.5,13)]
# x/z center and half extents. Smooth aprons keep all roads and building pads level.
const PADS := [Vector4(0,0,18,24),Vector4(23,22,9,8),Vector4(14,20,8,2),Vector4(46,-20,21,21),Vector4(-39,-25,15,15),Vector4(0,59,13,9),Vector4(-36,35,12,10),Vector4(25,0,16,4),Vector4(38,-9,4,12),Vector4(-25,0,16,4),Vector4(-39,-11,4,14),Vector4(0,38,4.5,20),Vector4(-20,35,18,4)]
var vertices := PackedVector3Array()
var cells: Dictionary = {}
var grass_positions: Array[Vector3] = []
var grass_batches := 0
var world: Node3D

func radius(a: float) -> float:return 83.0+3*sin(a*5)+2*cos(a*9)

func clearance(p: Vector2) -> float:
	var distance := INF
	for pad in PADS:
		var delta := (p-Vector2(pad.x,pad.y)).abs()-Vector2(pad.z,pad.w)
		distance=minf(distance,Vector2(maxf(delta.x,0),maxf(delta.y,0)).length()+minf(maxf(delta.x,delta.y),0))
	return distance

func height(p: Vector2) -> float:
	var coast := p.length()/radius(atan2(p.x,p.y))
	var relief := 0.0
	for hill in HILLS:
		var distance: float=p.distance_to(Vector2(hill.x,hill.y))/hill.w
		relief+=hill.z*exp(-distance*distance*1.8)
	# Quiet small undulation beneath the larger silhouettes, outside paved areas.
	relief+=0.25*(sin(p.x*0.15)+cos(p.y*0.19)+2)
	return relief*smoothstep(0,6,clearance(p))*(1-smoothstep(0.86,1.0,coast))-2.65*smoothstep(0.88,1.0,coast)

func surface_height(p: Vector3) -> float:
	var cell := Vector2i(floori(p.x/4),floori(p.z/4))
	for i in cells.get(cell,[]):
		var a := vertices[i];var b := vertices[i+1];var c := vertices[i+2]
		var divisor := (b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)
		if absf(divisor)<0.000001:continue
		var u := ((b.z-c.z)*(p.x-c.x)+(c.x-b.x)*(p.z-c.z))/divisor
		var v := ((c.z-a.z)*(p.x-c.x)+(a.x-c.x)*(p.z-c.z))/divisor
		if u>=-0.00001 and v>=-0.00001 and u+v<=1.00001:return a.y*u+b.y*v+c.y*(1-u-v)
	return height(Vector2(p.x,p.z))

func point(a: float, fraction: float) -> Vector3:
	var p := Vector2(sin(a),cos(a))*radius(a)*fraction
	return Vector3(p.x,height(p),p.y)

func triangle(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3) -> void:
	for p in [a,b,c]:
		var coast := Vector2(p.x,p.z).length()/radius(atan2(p.x,p.z))
		surface.set_color(Color("c6b68b") if coast>0.94 else Color("75a56e"))
		surface.add_vertex(p)

func build(owner_world: Node3D) -> void:
	world=owner_world
	var surface := SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 128:
		var a := i*TAU/128.0;var b := (i+1)*TAU/128.0
		triangle(surface,Vector3(0,height(Vector2.ZERO),0),point(b,1.0/42),point(a,1.0/42))
		for ring in range(1,42):
			var p := point(a,ring/42.0);var q := point(b,ring/42.0)
			var r := point(a,(ring+1)/42.0);var s := point(b,(ring+1)/42.0)
			triangle(surface,p,q,s);triangle(surface,p,s,r)
	surface.generate_normals()
	var ground := MeshInstance3D.new();ground.mesh=surface.commit();ground.name="IslandTerrain"
	var mat := ShaderMaterial.new();mat.shader=MEADOW;ground.material_override=mat;add_child(ground);ground.create_trimesh_collision()
	vertices=ground.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for i in range(0,vertices.size(),3):
		var a := vertices[i];var b := vertices[i+1];var c := vertices[i+2]
		for x in range(floori(minf(a.x,minf(b.x,c.x))/4),floori(maxf(a.x,maxf(b.x,c.x))/4)+1):
			for z in range(floori(minf(a.z,minf(b.z,c.z))/4),floori(maxf(a.z,maxf(b.z,c.z))/4)+1):
				var cell := Vector2i(x,z)
				if not cells.has(cell):cells[cell]=[]
				cells[cell].append(i)
	# Sloping sandy edge, retaining wall and rock skirt close the actual island.
	var cliff := SurfaceTool.new();cliff.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 128:
		var a := point(i*TAU/128,1);var b := point((i+1)*TAU/128,1)
		var c := Vector3(a.x*1.04,-6,a.z*1.04);var d := Vector3(b.x*1.04,-6,b.z*1.04)
		for v in [a,b,c,b,d,c]:cliff.add_vertex(v)
		var wall: Node3D=world.block((a+b)*0.5+Vector3(0,0.45,0),Vector3(a.distance_to(b)+0.12,0.9,0.5),"9ca48a")
		wall.rotation.y=-atan2((b-a).z,(b-a).x)
	cliff.generate_normals();var rock := MeshInstance3D.new();rock.mesh=cliff.commit();rock.material_override=world.material("8a8e7d");add_child(rock)
	var ocean := MeshInstance3D.new();var plane := PlaneMesh.new();plane.size=Vector2(2000,2000)
	ocean.mesh=plane;ocean.position.y=-3.2;ocean.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sea := ShaderMaterial.new();sea.shader=SEA;ocean.material_override=sea;add_child(ocean)
	meadow()

func grass_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in 5:
		var angle := blade*2.39996;var side := Vector3(cos(angle),0,sin(angle))
		var base := Vector3(sin(angle)*0.08,0,cos(angle)*0.08)
		var h := 0.20+0.035*(blade%3);var w := 0.05
		var bend := Vector3(cos(angle+0.7),0,sin(angle+0.7))*0.06
		var points := [base-side*w,base+side*w,base+Vector3.UP*h*0.55+bend*0.3-side*w*0.7,base+Vector3.UP*h*0.55+bend*0.3+side*w*0.7,base+Vector3.UP*h+bend]
		for index in [0,2,1,1,2,3,2,4,3]:
			surface.set_normal(Vector3.UP);surface.set_uv(Vector2(0,points[index].y/h));surface.add_vertex(points[index])
	return surface.commit()

func grass_allowed(p: Vector2) -> bool:
	if absf(p.x)<9.5 and absf(p.y)<22.5:return false
	if absf(p.x)<14.5 and absf(p.y)<9.0:return false
	for i in range(1,PADS.size()):
		var pad: Vector4=PADS[i]
		if absf(p.x-pad.x)<pad.z+0.4 and absf(p.y-pad.y)<pad.w+0.4:return false
	# Keep flower beds and stall pads clear too.
	if absf(p.x)>10.3 and absf(p.x)<14.3 and absf(p.y)<24:return false
	return true

func meadow() -> void:
	var rng := RandomNumberGenerator.new();rng.seed=7142026
	var chunks: Dictionary = {}
	for x in range(-100,101):
		for z in range(-100,101):
			var p := Vector3(x*0.85+rng.randf_range(-0.2,0.2),0,z*0.85+rng.randf_range(-0.2,0.2))
			if Vector2(p.x,p.z).length()>radius(atan2(p.x,p.z))*0.93 or not grass_allowed(Vector2(p.x,p.z)):continue
			p.y=surface_height(p)-0.015;grass_positions.append(p)
			var cell := Vector2i(floori(p.x/12),floori(p.z/12))
			if not chunks.has(cell):chunks[cell]=[]
			chunks[cell].append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(0.9,1.35)),p))
	var mesh := grass_mesh();var mat := ShaderMaterial.new();mat.shader=MEADOW;mat.set_shader_parameter("grass",true)
	for cell in chunks:
		var batch := MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D;batch.mesh=mesh;batch.instance_count=chunks[cell].size()
		var origin := Vector3(cell.x*12,0,cell.y*12)
		for i in batch.instance_count:
			var placement: Transform3D=chunks[cell][i];placement.origin-=origin;batch.set_instance_transform(i,placement)
		var node := MultiMeshInstance3D.new();node.multimesh=batch;node.material_override=mat;node.position=origin
		node.name="Meadow_%s_%s"%[cell.x,cell.y];node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end=42;node.extra_cull_margin=0.3;add_child(node);grass_batches+=1
