# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
## Authored local world. No directory, economy, owners or visitor counts here.
var destinations: Array[Dictionary] = []
var models: Dictionary = {}

func material(color: String) -> StandardMaterial3D:
	var value := StandardMaterial3D.new()
	value.albedo_color=Color(color);value.roughness=0.87
	return value

func block(at: Vector3, size: Vector3, color: String, solid := true) -> Node3D:
	var root := Node3D.new();add_child(root);root.position=at
	var mesh := MeshInstance3D.new();var cube := BoxMesh.new();cube.size=size
	mesh.mesh=cube;mesh.material_override=material(color);root.add_child(mesh)
	if solid: collider(root,Vector3.ZERO,size)
	return root

func collider(parent: Node3D, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new();body.position=at;parent.add_child(body)
	var shape := CollisionShape3D.new();var box := BoxShape3D.new();box.size=size
	shape.shape=box;body.add_child(shape)

func model(asset: String, at: Vector3, scale_value := Vector3.ONE, yaw := 0.0, parent: Node3D = self) -> Node3D:
	if not models.has(asset):models[asset]=load("res://assets/town/"+asset+".glb")
	var node: Node3D=models[asset].instantiate();parent.add_child(node)
	node.position=at;node.scale=scale_value;node.rotation.y=yaw
	return node

func house(at: Vector3, width: int, depth: int, floors: int, yaw: float, roof_color: String) -> void:
	var home := Node3D.new();add_child(home);home.position=at;home.rotation.y=yaw;home.scale=Vector3.ONE*1.7
	collider(home,Vector3(0,floors*0.5,0),Vector3(width,floors,depth))
	for floor_index in floors:
		for x in width:
			var px := x-(width-1)*0.5
			var front := "wall-door" if floor_index==0 and x==width/2 else "wall-window-glass" if floor_index==0 else "wall-wood-window-shutters"
			model(front,Vector3(px,floor_index,depth*0.5-0.5),Vector3.ONE,-PI/2,home)
			model("wall" if floor_index==0 else "wall-wood",Vector3(px,floor_index,-depth*0.5+0.5),Vector3.ONE,PI/2,home)
		for z in depth:
			var pz := z-(depth-1)*0.5
			model("wall-window-glass" if floor_index==0 else "wall-wood-window-round",Vector3(width*0.5-0.5,floor_index,pz),Vector3.ONE,0,home)
			model("wall" if floor_index==0 else "wall-wood",Vector3(-width*0.5+0.5,floor_index,pz),Vector3.ONE,PI,home)
	# One complete roof profile, with matching end faces and overhang.
	model("roof-gable",Vector3(0,floors,0),Vector3(width,2.0,depth),0,home)
	model("chimney",Vector3(width*0.27,floors+0.5,-depth*0.15),Vector3(0.7,1.1,0.7),0,home)
	# Color strips echo the original teal/coral catalogue palette.
	var sign := MeshInstance3D.new();var sign_mesh := BoxMesh.new();sign_mesh.size=Vector3(0.8,0.22,0.06)
	sign.mesh=sign_mesh;sign.material_override=material(roof_color);home.add_child(sign);sign.position=Vector3(0,1.06,depth*0.5+0.07)

func spot(title: String, detail: String, at: Vector3) -> void:
	destinations.append({"title":title,"detail":detail,"position":at})
	var post := block(at+Vector3(0,0.48,0),Vector3(0.07,0.96,0.07),"695247",false)
	var sign := block(at+Vector3(0,0.96,0),Vector3(0.85,0.32,0.06),"355f59",false)
	post.name="SignPost";sign.name="SignBoard"

func _ready() -> void:
	var env := WorldEnvironment.new();env.environment=Environment.new();add_child(env)
	var sky := Sky.new();var atmosphere := ProceduralSkyMaterial.new()
	atmosphere.sky_top_color=Color("669fb6");atmosphere.sky_horizon_color=Color("f6dfad")
	atmosphere.ground_bottom_color=Color("718a69");atmosphere.ground_horizon_color=Color("f6dfad")
	sky.sky_material=atmosphere;env.environment.sky=sky;env.environment.background_mode=Environment.BG_SKY
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("cedfda");env.environment.ambient_light_energy=0.35
	env.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	var sun := DirectionalLight3D.new();sun.rotation_degrees=Vector3(-46,-32,0);sun.light_color=Color("fff0d0")
	sun.light_energy=0.8;sun.shadow_enabled=true;sun.directional_shadow_max_distance=55;add_child(sun)
	block(Vector3(0,-0.25,0),Vector3(75,0.5,75),"8eaa83")
	var plaza := block(Vector3(0,0.012,0),Vector3(30,0.024,32),"c5b79c",false)
	var shader := Shader.new();shader.code="""shader_type spatial;
	varying vec3 position_world;
	void vertex(){ position_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
	void fragment(){
	 vec2 p=position_world.xz*1.7;
	 p.x+=mod(floor(p.y),2.0)*0.5;
	 vec2 uv=fract(p);float edge=min(min(uv.x,1.0-uv.x),min(uv.y,1.0-uv.y));
	 float shade=fract(sin(dot(floor(p),vec2(12.9898,78.233)))*43758.5453);
	 ALBEDO=mix(vec3(0.40,0.43,0.37),vec3(0.65,0.61,0.51)*(0.94+shade*0.12),smoothstep(0.012,0.035,edge));ROUGHNESS=0.95;
	}"""
	var paving := ShaderMaterial.new();paving.shader=shader
	(plaza.get_child(0) as MeshInstance3D).material_override=paving
	# A continuous walking loop around the fountain; no invisible room portals.
	model("fountain-round-detail",Vector3.ZERO,Vector3.ONE*2.1)
	var fountain := StaticBody3D.new();add_child(fountain)
	var basin := CollisionShape3D.new();var basin_shape := CylinderShape3D.new();basin_shape.radius=2.1;basin_shape.height=1.8
	basin.shape=basin_shape;basin.position.y=0.9;fountain.add_child(basin)
	var water := MeshInstance3D.new();var disk := CylinderMesh.new();disk.top_radius=1.75;disk.bottom_radius=1.75;disk.height=0.02
	water.mesh=disk;water.material_override=material("60bac0");water.position.y=0.31;add_child(water)
	for side in [-1,1]:
		house(Vector3(side*10.5,0,-8),3,3,2,-side*PI/2,"ce7960")
		house(Vector3(side*10.5,0,0),3,2,2,-side*PI/2,"50897a")
		house(Vector3(side*10.5,0,8),3,3,1,-side*PI/2,"cd9b57")
		house(Vector3(side*6.5,0,-14),3,2,2,0,"50897a")
		for z in [-5.0,4.5]:
			var stall := model("stall-red" if z<0 else "stall-green",Vector3(side*5.3,0.025,z),Vector3.ONE*1.65,-side*PI/2)
			collider(stall,Vector3(0,0.48,0),Vector3(1.0,0.96,0.85))
			model("stall-bench",Vector3(side*3.8,0.025,z+1.4),Vector3.ONE*1.3,-side*PI/2)
		for z in [-10.5,-2.8,9.5]:
			model("lantern",Vector3(side*7.0,0.025,z),Vector3.ONE*1.55)
		for z in [-14.0,-5.0,5.0,13.0]:
			var tree := model("tree-crooked" if z==5.0 else "tree",Vector3(side*14,0,z),Vector3.ONE*1.7)
			collider(tree,Vector3(0,0.6,0),Vector3(0.32,1.2,0.32))
		for x in range(4,14,2):
			model("hedge",Vector3(side*x,0,14.5),Vector3(1.8,1.4,1.5))
		model("cart",Vector3(side*8.0,0,11.4),Vector3.ONE*1.4,side*0.35)
	# Gate to a future district, visibly closed until it exists.
	for side in [-1,1]:
		block(Vector3(side*2.35,1.6,-14),Vector3(1.1,3.2,1.1),"a6a392")
		model("banner-green",Vector3(side*2.35,2.35,-13.35),Vector3.ONE*1.8,-PI/2)
	block(Vector3(0,3.3,-14),Vector3(5.8,0.65,1.25),"bcb6a2")
	for x in [-1.6,-0.8,0.0,0.8,1.6]:model("fence",Vector3(x,0,-14),Vector3.ONE*1.6)
	collider(self,Vector3(0,1,-14),Vector3(4,2,0.5))
	# Outward world limits sit behind buildings / hedges, not across the square.
	for x in [-15.2,15.2]:collider(self,Vector3(x,2,0),Vector3(0.4,4,33))
	for z in [-16.2,15.2]:collider(self,Vector3(0,2,z),Vector3(31,4,0.4))
	for i in 22:
		var angle := i*TAU/22
		model("tree-high-round",Vector3(sin(angle)*22,0,cos(angle)*22),Vector3.ONE*(1.3+(i%3)*0.5))
	spot("Market stalls","Player trading will live here. Stalls are scenery in this build; no items or Sparks change.",Vector3(-3.8,0,-4.8))
	spot("Garden court","A future square for meeting other players. This passage is still being built.",Vector3(0,0,-11.8))
	spot("Your own Bazaar","Personal spaces and rentable stalls come later. Purchases remain unavailable.",Vector3(3.8,0,5.8))
