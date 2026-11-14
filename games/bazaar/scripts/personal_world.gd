# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
## Two local, empty starting grounds. Scenery never grants ownership or purchases.
var kind := "island"
var destinations: Array[Dictionary] = []
var spawn := Vector3(0,1.6,18)
var materials: Dictionary = {}
var build_radius := 24.0
var terrain: MeshInstance3D

func title() -> String:return "Mika's Island" if kind=="island" else "Ren's Observatory"
func district(_at: Vector3) -> String:return title()
func description() -> String:return "One empty square to make your own. Shops, stalls, training arenas and social spaces will be added later. This local test world has no purchases or multiplayer."
func material(color: String, glow := false) -> StandardMaterial3D:
	var key := color+str(glow)
	if not materials.has(key):
		var m := StandardMaterial3D.new();m.albedo_color=Color(color);m.roughness=0.84
		if glow:m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		materials[key]=m
	return materials[key]
func geometry(mesh: Mesh, mat: Material, at := Vector3.ZERO, solid := false) -> MeshInstance3D:
	var node := MeshInstance3D.new();node.mesh=mesh;node.material_override=mat;node.position=at;add_child(node)
	if solid:node.create_trimesh_collision()
	return node
func tri(s: SurfaceTool,a: Vector3,b: Vector3,c: Vector3) -> void:
	s.add_vertex(a);s.add_vertex(b);s.add_vertex(c)
func surface() -> SurfaceTool:
	var s := SurfaceTool.new();s.begin(Mesh.PRIMITIVE_TRIANGLES);return s
func finish(s: SurfaceTool, mat: Material, solid := false) -> MeshInstance3D:
	s.generate_normals();return geometry(s.commit(),mat,Vector3.ZERO,solid)
func ring(radius: float, width: float, y: float, mat: Material) -> void:
	var s := surface()
	for i in 128:
		var a := i*TAU/128;var b := (i+1)*TAU/128
		var p := Vector3(sin(a),0,cos(a));var q := Vector3(sin(b),0,cos(b));var up := Vector3.UP*y
		tri(s,p*(radius-width/2)+up,q*(radius-width/2)+up,q*(radius+width/2)+up)
		tri(s,p*(radius-width/2)+up,q*(radius+width/2)+up,p*(radius+width/2)+up)
	finish(s,mat)
func tube(s: SurfaceTool, points: Array[Vector3], radius: float) -> void:
	for i in range(points.size()-1):
		var axis := (points[i+1]-points[i]).normalized()
		var side := axis.cross(Vector3.UP).normalized() if absf(axis.y)<0.95 else axis.cross(Vector3.RIGHT).normalized()
		var up := axis.cross(side).normalized()
		for j in 6:
			var u := (side*cos(j*TAU/6)+up*sin(j*TAU/6))*radius
			var v := (side*cos((j+1)*TAU/6)+up*sin((j+1)*TAU/6))*radius
			tri(s,points[i]+u,points[i+1]+u,points[i+1]+v);tri(s,points[i]+u,points[i+1]+v,points[i]+v)
func coast(a: float) -> float:return 50.0+1.8*sin(a*3)+0.9*cos(a*7)
func ground_height(p: Vector2) -> float:
	var r := p.length();var edge := coast(atan2(p.x,p.y))
	var hill := (0.9+0.9*sin(p.x*0.17)*cos(p.y*0.19))*smoothstep(25,32,r)*(1-smoothstep(35,42,r))
	return 1.4+hill-1.18*smoothstep(31,43,r)-2.0*smoothstep(edge-3,edge+1,r)
func island_point(a: float, t: float) -> Vector3:
	var p := Vector2(sin(a),cos(a))*(coast(a)+1)*t
	return Vector3(p.x,ground_height(p),p.y)
func island() -> void:
	var s := surface()
	for i in 128:
		var a := i*TAU/128;var b := (i+1)*TAU/128
		for j in 40:
			var p := island_point(a,j/40.0);var q := island_point(b,j/40.0)
			var r := island_point(a,(j+1)/40.0);var t := island_point(b,(j+1)/40.0)
			for v in [p,q,t,p,t,r]:
				var sand := smoothstep(33,40,Vector2(v.x,v.z).length())
				s.set_color(Color("78a47a").lerp(Color("b6a47f"),sand));s.add_vertex(v)
	var turf := ShaderMaterial.new();turf.shader=load("res://shaders/meadow.gdshader");turf.set_shader_parameter("meadow_dark",Vector3(0.20,0.38,0.22));turf.set_shader_parameter("meadow_light",Vector3(0.30,0.48,0.27))
	terrain=finish(s,turf,true);terrain.name="IslandGround"
	var plaza := CylinderMesh.new();plaza.top_radius=build_radius;plaza.bottom_radius=build_radius;plaza.height=0.08;plaza.radial_segments=128
	var tiles := ShaderMaterial.new();tiles.shader=load("res://shaders/personal_floor.gdshader")
	geometry(plaza,tiles,Vector3(0,1.42,0),true)
	ring(24.1,0.36,1.47,material("dbc7a6"));ring(23.45,0.07,1.47,material("998e75"))
	var water := PlaneMesh.new();water.size=Vector2(1800,1800)
	var sea := ShaderMaterial.new();sea.shader=load("res://shaders/personal_sea.gdshader")
	geometry(water,sea,Vector3(0,-0.25,0)).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rng := RandomNumberGenerator.new();rng.seed=76142
	# Clusters around the rim keep the entire central square empty and readable.
	var trunks := surface();var leaves := surface()
	for i in 18:
		var a := i*TAU/18+0.12*sin(i*2.5);var r := 34.0+3.1*sin(i*1.6)
		var p := Vector3(sin(a)*r,0,cos(a)*r);p.y=ground_height(Vector2(p.x,p.z))
		palm(trunks,leaves,p,5.2+rng.randf()*2.0,a)
	finish(trunks,material("97704b"));var leaf_mat:=material("438b70");leaf_mat.cull_mode=BaseMaterial3D.CULL_DISABLED;finish(leaves,leaf_mat)
	var rock := SphereMesh.new();rock.radial_segments=7;rock.rings=3
	for i in 16:
		var a := i*2.39996;var r := 40.0+float(i%3)*1.7;var p:=Vector3(sin(a)*r,0,cos(a)*r);p.y=ground_height(Vector2(p.x,p.z))+0.15
		var node := geometry(rock,material("aaa996"),p);node.scale=Vector3(1.6+(i%3)*0.5,0.55+(i%2)*0.4,1.2);node.rotation.y=a
	grass()
	var cloud_mesh := SphereMesh.new();cloud_mesh.radial_segments=12;cloud_mesh.rings=6
	for i in 7:
		var a := i*2.39996;var center:=Vector3(sin(a)*180,48+(i%3)*9,cos(a)*180)
		for j in 4:
			var node:=geometry(cloud_mesh,material("e6efeb"),center+Vector3((j-1.5)*10,sin(j*PI/3)*3,0))
			node.scale=Vector3(15,6.5+(j%2)*3,11);node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func palm(trunks: SurfaceTool,leaves: SurfaceTool,at: Vector3,h: float,a: float) -> void:
	var lean := Vector3(sin(a),0,cos(a))*0.8
	var points: Array[Vector3]=[]
	for i in 9:points.append(at+Vector3.UP*h*i/8+lean*pow(i/8.0,2))
	tube(trunks,points,0.17)
	var top: Vector3=points[-1]
	for i in 8:
		var direction := Vector3(sin(a+i*TAU/8),0,cos(a+i*TAU/8));var side := direction.cross(Vector3.UP)
		for j in 7:
			var t := j/7.0;var u := (j+1)/7.0
			var p := top+direction*t*3.4+Vector3.UP*(sin(t*PI)*0.8-t*t*0.8)
			var q := top+direction*u*3.4+Vector3.UP*(sin(u*PI)*0.8-u*u*0.8)
			var w := sin(t*PI)*0.45;var v := sin(u*PI)*0.45
			tri(leaves,p-side*w,q-side*v,q+side*v);tri(leaves,p-side*w,q+side*v,p+side*w)
func grass() -> void:
	var helper=load("res://scripts/landscape.gd").new();var mesh: ArrayMesh=helper.grass_mesh();helper.free()
	var mat := ShaderMaterial.new();mat.shader=load("res://shaders/meadow.gdshader");mat.set_shader_parameter("grass",true);mat.set_shader_parameter("meadow_dark",Vector3(0.20,0.38,0.22));mat.set_shader_parameter("meadow_light",Vector3(0.30,0.48,0.27))
	var rng := RandomNumberGenerator.new();rng.seed=765
	var cells: Dictionary={}
	for i in 6500:
		var a := rng.randf()*TAU;var r := sqrt(rng.randf_range(26.0*26.0,37.0*37.0));var p:=Vector3(sin(a)*r,0,cos(a)*r)
		p.y=ground_height(Vector2(p.x,p.z))-0.04
		var cell := Vector2i(floori(p.x/12),floori(p.z/12))
		if not cells.has(cell):cells[cell]=[]
		cells[cell].append(Transform3D(Basis(Vector3.UP,a).scaled(Vector3.ONE*rng.randf_range(1.0,1.8)),p))
	for cell in cells:
		var batch := MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D;batch.mesh=mesh;batch.instance_count=cells[cell].size()
		var origin := Vector3(cell.x*12,0,cell.y*12)
		for i in batch.instance_count:
			var t: Transform3D=cells[cell][i];t.origin-=origin;batch.set_instance_transform(i,t)
		var node:=MultiMeshInstance3D.new();node.multimesh=batch;node.material_override=mat;node.position=origin;node.visibility_range_end=48;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
func station() -> void:
	spawn=Vector3(0,0.3,23);build_radius=24
	var disk := CylinderMesh.new();disk.top_radius=34;disk.bottom_radius=33;disk.height=1.5;disk.radial_segments=128
	var deck := ShaderMaterial.new();deck.shader=load("res://shaders/personal_floor.gdshader");deck.set_shader_parameter("station",true)
	terrain=geometry(disk,deck,Vector3(0,-0.75,0),true);terrain.name="StationDeck"
	for r in [24.0,29.8,33.1]:ring(r,0.09,0.015,material("75cbd1",true))
	ring(32.9,1.35,0.012,material("c3cfca"));ring(24,0.38,0.012,material("aa9775"))
	var ribs:=surface();var trim:=surface()
	for i in 12:
		var a := i*TAU/12;var points: Array[Vector3]=[]
		for j in 33:
			var t := j*PI/2/32;points.append(Vector3(sin(a)*34.2*cos(t),0.35+23*sin(t),cos(a)*34.2*cos(t)))
		tube(ribs,points,0.18)
		# Low perimeter rail gives the player and spring arm a physical boundary.
		var foot := Vector3(sin(a)*33.4,0,cos(a)*33.4)
		var post := CylinderMesh.new();post.top_radius=0.12;post.bottom_radius=0.17;post.height=1.25;post.radial_segments=8
		geometry(post,material("344b63"),foot+Vector3.UP*0.62)
	for lat in [0.0,0.35,0.75,1.15]:
		var points: Array[Vector3]=[]
		for i in 129:points.append(Vector3(sin(i*TAU/128)*34.2*cos(lat),0.35+23*sin(lat),cos(i*TAU/128)*34.2*cos(lat)))
		tube(ribs,points,0.15)
	for y in [0.25,1.15]:
		var points: Array[Vector3]=[]
		for i in 129:points.append(Vector3(sin(i*TAU/128)*33.4,y,cos(i*TAU/128)*33.4))
		tube(trim,points,0.045)
	finish(ribs,material("7c9da9"));finish(trim,material("9ce5df",true))
	# Single transparent shell: no refraction, screen texture, SSR or layered glass.
	var dome:=surface()
	for i in 96:
		for j in 24:
			var a:=i*TAU/96;var b:=(i+1)*TAU/96;var t:=j*PI/2/24;var u:=(j+1)*PI/2/24
			var p:=Vector3(sin(a)*34.2*cos(t),0.35+23*sin(t),cos(a)*34.2*cos(t))
			var q:=Vector3(sin(b)*34.2*cos(t),0.35+23*sin(t),cos(b)*34.2*cos(t))
			var r:=Vector3(sin(a)*34.2*cos(u),0.35+23*sin(u),cos(a)*34.2*cos(u))
			var v:=Vector3(sin(b)*34.2*cos(u),0.35+23*sin(u),cos(b)*34.2*cos(u))
			tri(dome,p,q,v);tri(dome,p,v,r)
	var glass:=ShaderMaterial.new();glass.shader=load("res://shaders/dome.gdshader")
	finish(dome,glass).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Closed low wall uses one collision mesh instead of many overlapping boxes.
	var wall:=surface()
	for i in 96:
		var a:=i*TAU/96;var b:=(i+1)*TAU/96;var p:=Vector3(sin(a)*33.8,0,cos(a)*33.8);var q:=Vector3(sin(b)*33.8,0,cos(b)*33.8)
		tri(wall,p,q+Vector3.UP*2,q);tri(wall,p,p+Vector3.UP*2,q+Vector3.UP*2)
	var boundary:=finish(wall,material("344b63"),true);boundary.hide()
	var planet:=SphereMesh.new();planet.radius=83;planet.height=166;planet.radial_segments=64;planet.rings=32
	var pm:=ShaderMaterial.new();pm.shader=load("res://shaders/planet.gdshader")
	geometry(planet,pm,Vector3(-124,78,-235)).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Station rim and lower mechanical rings remain visible in an exterior overview.
	for y in [-1.7,-2.7]:
		var points: Array[Vector3]=[]
		for i in 129:points.append(Vector3(sin(i*TAU/128)*32.7,y,cos(i*TAU/128)*32.7))
		var strut:=surface();tube(strut,points,0.26);finish(strut,material("344b63"))
func _ready() -> void:
	var world:=WorldEnvironment.new();world.environment=Environment.new();add_child(world)
	var env:=world.environment;var sky:=Sky.new();env.sky=sky;env.background_mode=Environment.BG_SKY
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-42,-28,0);sun.shadow_enabled=true;sun.directional_shadow_max_distance=65;add_child(sun)
	if kind=="island":
		var atmosphere:=ProceduralSkyMaterial.new();atmosphere.sky_top_color=Color("519fcb");atmosphere.sky_horizon_color=Color("c7e8e6");atmosphere.ground_horizon_color=Color("c7e8e6");atmosphere.ground_bottom_color=Color("c7e8e6");sky.sky_material=atmosphere
		env.ambient_light_color=Color("c5e2e7");env.ambient_light_energy=0.32;sun.light_color=Color("fff1cf");sun.light_energy=0.55
		env.fog_enabled=true;env.fog_mode=Environment.FOG_MODE_DEPTH;env.fog_depth_begin=100;env.fog_depth_end=450;env.fog_density=0.25;env.fog_light_color=Color("c7e8e6");env.fog_sky_affect=0
		island()
	else:
		var cosmos:=ShaderMaterial.new();cosmos.shader=load("res://shaders/cosmos.gdshader");sky.sky_material=cosmos
		env.ambient_light_color=Color("9cb2dd");env.ambient_light_energy=0.65;sun.light_color=Color("e8dbff");sun.light_energy=0.8
		station()
