# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
## Authored local world. No directory, economy, owners or visitor counts here.
var festival = preload("festival_ground.gd").new()
var fitting_booth: Node3D
var counter_names := {}
const COUNTER_SIGN_LAYER := 2
var stands := {}
var price_board := BoxMesh.new()
var price_wood := StandardMaterial3D.new()
var display_rows := {}
var destinations: Array[Dictionary] = []
var models: Dictionary = {}
var prop_roots: Array[Node3D] = []
var block_mesh := BoxMesh.new()
var block_finishes: Dictionary = {}
var lantern_mesh := SphereMesh.new()
var lantern_paper: Dictionary = {}
var nature_meshes: Dictionary = {}
var landscape = preload("res://scripts/landscape.gd").new()
var shop_exits: Array[Dictionary] = []
var life = preload("res://scripts/island_life.gd").new()
var paving: ShaderMaterial
var dressing = preload("res://scripts/dressing.gd").new()
const MARKET := Vector3(0,0,0)
const TOWN := Vector3(46,0,-20)
const GARDEN := Vector3(-39,0,-25)
const HARBOR := Vector3(0,0,59)

func material(color: String) -> StandardMaterial3D:
	var value := StandardMaterial3D.new()
	value.albedo_color=Color(color);value.roughness=0.87
	return value

func block(at: Vector3, size: Vector3, color: String, solid := true) -> Node3D:
	var root := Node3D.new();add_child(root);root.position=at
	var mesh := MeshInstance3D.new()
	if not block_finishes.has(color):block_finishes[color]=material(color)
	mesh.mesh=block_mesh;mesh.scale=size;mesh.material_override=block_finishes[color]
	root.add_child(mesh);prop_roots.append(root)
	if solid: collider(root,Vector3.ZERO,size)
	return root

func collider(parent: Node3D, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new();body.position=at;parent.add_child(body)
	var shape := CollisionShape3D.new();var box := BoxShape3D.new();box.size=size
	shape.shape=box;body.add_child(shape)

func model(asset: String, at: Vector3, scale_value := Vector3.ONE, yaw := 0.0, parent: Node3D = self, leaf_dye := "639873") -> Node3D:
	if not models.has(asset):models[asset]=load("res://assets/"+(asset if asset.begins_with("nature/") else "town/"+asset)+".glb")
	var node: Node3D=models[asset].instantiate();parent.add_child(node)
	node.position=at;node.scale=scale_value;node.rotation.y=yaw;prop_roots.append(node)
	for part in node.find_children("*","MeshInstance3D",true,false):
		if asset.begins_with("nature/"):
			var id := "%d/%s"%[part.mesh.get_instance_id(),leaf_dye]
			if not nature_meshes.has(id):
				var copy: ArrayMesh=part.mesh.duplicate()
				var crown_surface := -1
				for i in copy.get_surface_count():
					var original=copy.surface_get_material(i)
					if original is StandardMaterial3D:
						var mat: StandardMaterial3D=original.duplicate();mat.roughness=0.95;mat.metallic=0
						var palette := {"leafsGreen":leaf_dye,"grass":"72976e","woodBark":"ac8365"}
						if original.resource_name=="leafsGreen" and asset.begins_with("nature/tree_"):crown_surface=i
						if palette.has(original.resource_name):mat.albedo_color=Color(palette[original.resource_name])
						copy.surface_set_material(i,mat)
				if crown_surface>=0:
					preload("res://scripts/tree_crown.gd").apply(copy,crown_surface,Color(leaf_dye),asset.ends_with("detailed"))
				nature_meshes[id]=copy
			part.mesh=nature_meshes[id]
		part.visibility_range_end=85.0
		if asset.begins_with("nature/flower") or asset.begins_with("nature/grass"):part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func house(at: Vector3, width: int, depth: int, floors: int, yaw: float, roof_color: String) -> Node3D:
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
	var roof := model("roof-gable",Vector3(0,floors,0),Vector3(width,2.0,depth),0,home)
	for part in roof.find_children("*","MeshInstance3D",true,false):
		var base: StandardMaterial3D=part.mesh.surface_get_material(0)
		var tiles:=ShaderMaterial.new()
		tiles.shader=preload("res://shaders/roof_tiles.gdshader")
		tiles.set_shader_parameter("atlas",base.albedo_texture)
		tiles.set_shader_parameter("glaze",Color(roof_color))
		part.material_override=tiles
	model("chimney",Vector3(width*0.27,floors+0.5,-depth*0.15),Vector3(0.7,1.1,0.7),0,home)
	# Color strips echo the original teal/coral catalogue palette.
	var sign := MeshInstance3D.new();var sign_mesh := BoxMesh.new();sign_mesh.size=Vector3(0.8,0.22,0.06)
	sign.mesh=sign_mesh;sign.material_override=material(roof_color);home.add_child(sign);sign.position=Vector3(0,1.06,depth*0.5+0.07)
	return home

func spot(title: String, detail: String, at: Vector3) -> void:
	destinations.append({"title":title,"detail":detail,"position":at,"attention":at+Vector3.UP*.96})
	var post := block(at+Vector3(0,0.48,0),Vector3(0.07,0.96,0.07),"695247",false)
	var sign := block(at+Vector3(0,0.96,0),Vector3(1.65,0.40,0.09),"355f59",false)
	post.name="SignPost";sign.name="SignBoard"
	text3d(title,at+Vector3(0,0.98,0.06),minf(0.005,1.42/ThemeDB.fallback_font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,44).x))

func text3d(text: String, at: Vector3, pixel := 0.013, parent: Node3D = self, yaw := 0.0) -> Label3D:
	var label := Label3D.new();label.text=text;label.font_size=44;label.pixel_size=pixel
	label.modulate=Color("fff1c9");label.outline_modulate=Color("243e3c");label.outline_size=3
	label.position=at;label.rotation.y=yaw;parent.add_child(label)
	return label

var paved_areas: Array[Rect2] = []

func foot_surface(at: Vector3) -> String:
	var point := Vector2(at.x, at.z)
	for area in paved_areas:
		if area.has_point(point):return "stone"
	return "sand" if point.length() > .94 * landscape.radius(atan2(at.x,at.z)) else "grass"

func path(at: Vector3, size: Vector3) -> void:
	var extent := Vector2(size.x, size.z)
	paved_areas.append(Rect2(Vector2(at.x, at.z) - extent * .5, extent))
	var node := block(at+Vector3(0,0.012,0),Vector3(size.x,0.024,size.z),"c5b79c",false)
	(node.get_child(0) as MeshInstance3D).material_override=paving

func flowerbed(at: Vector3, size := Vector2(4,2)) -> void:
	block(at+Vector3(0,0.13,0),Vector3(size.x,0.26,size.y),"b4ad91")
	block(at+Vector3(0,0.27,0),Vector3(size.x-0.18,0.04,size.y-0.18),"574c3b",false)
	# Loose drifts of one species grow through low mounds of foliage.
	var rng:=RandomNumberGenerator.new()
	rng.seed=int(at.x*137+at.z*619)
	for i in 5:
		var x: float=(i/4.0-0.5)*(size.x-0.92)
		model("nature/plant_bushLarge",at+Vector3(x,0.26,0),Vector3(1.12,0.67,1.05),i*1.91)
	for i in 27:
		var x:=rng.randf_range(-0.45,0.45)*size.x
		var z:=rng.randf_range(-0.39,0.39)*size.y
		var variety: String="purpleA" if x < -size.x*0.12 else "yellowA" if z>size.y*0.16 else "redA"
		model("nature/flower_"+variety,at+Vector3(x,0.29,z),Vector3.ONE*rng.randf_range(1.75,2.75),rng.randf()*TAU)

func tree(at: Vector3, size := 2.6, leaf_dye := "639873") -> void:
	at.y=landscape.surface_height(at)+0.05*size*2.4
	var angle:=fposmod(at.x*0.72+at.z*0.36,TAU)
	var asset := "nature/tree_detailed" if sin(angle)>0.0 else "nature/tree_oak"
	var node:=model(asset,at,Vector3(1.07,0.96,1.07)*size*2.4,angle,self,leaf_dye)
	collider(node,Vector3(0,0.7,0),Vector3(0.3,1.4,0.3))

func lantern(at: Vector3, color: String, parent: Node3D = self) -> void:
	if not lantern_paper.has(color):
		var mat:=ShaderMaterial.new();mat.shader=preload("res://shaders/paper_lantern.gdshader")
		mat.set_shader_parameter("paper",Color(color));lantern_paper[color]=mat
	var root:=Node3D.new();parent.add_child(root);root.position=at
	var lamp:=MeshInstance3D.new()
	lamp.mesh=lantern_mesh;lamp.material_override=lantern_paper[color]
	root.add_child(lamp);prop_roots.append(root)

func festival_line(z: float) -> void:
	for side in [-1,1]:block(Vector3(side*6.8,1.8,z),Vector3(0.13,3.6,0.13),"715444")
	# Strung paper lanterns with a low central sag, well above a visitor's head.
	var last:=Vector3(-6.8,3.55,z)
	for i in 11:
		var x := -6.8+i*1.36
		var hook:=Vector3(x,3.15+0.4*pow(x/6.8,2),z)
		if i>0:
			var chord:=hook-last
			var cord:=block((last+hook)*0.5,Vector3(chord.length(),0.022,0.022),"645845",false)
			cord.rotation.z=atan2(chord.y,chord.x)
		lantern(hook-Vector3.UP*0.29,"f1c88b" if i%2==0 else "d67e64")
		last=hook

func terrain() -> void:
	add_child(landscape);landscape.build(self)

func fountain() -> void:
	model("fountain-round-detail",Vector3.ZERO,Vector3.ONE*2.8)
	var body := StaticBody3D.new();add_child(body);var shape := CollisionShape3D.new();var basin := CylinderShape3D.new()
	basin.radius=2.8;basin.height=1.8;shape.shape=basin;shape.position.y=0.9;body.add_child(shape)
	var water := MeshInstance3D.new();var disk := CylinderMesh.new();disk.top_radius=2.35;disk.bottom_radius=2.35;disk.height=0.02
	water.mesh=disk;water.material_override=life.water_material();water.position.y=0.43;add_child(water);add_child(life)

# Slot IDs survive layout changes: props, interaction and sellers share one map.
# Kenney counter faces +X; SDK/NPC front is +Z. Their local yaws must differ.
func stall_layout(slot: int) -> Dictionary:
	assert(slot>=1 and slot<=12)
	var side := -1 if slot<=6 else 1
	var z: float=[-13.6,-10.55,-7.5,7.5,10.55,13.6][(slot-1)%6]
	return {"slot":slot,"side":side,"position":Vector3(side*5.7,0.025,z),
		"seller":Vector3(side*6.15,0,z),"approach":Vector3(side*4.15,0,z),"yaw":-side*PI/2,"model_yaw":0.0 if side<0 else PI}

func park_market() -> void:
	price_board.size=Vector3(.65,.54,.045)
	price_wood.albedo_color=Color("3c514a")
	price_wood.roughness=.9
	path(Vector3.ZERO,Vector3(14,0,44));path(Vector3(0,0,0),Vector3(28,0,17))
	fountain()
	# Closely spaced stalls face the promenade, with an open fountain court
	# separating two groups. Cross routes reach the park, town and rest pockets.
	for slot in range(1,13):
		var layout := stall_layout(slot)
		var side: int=layout.side;var at: Vector3=layout.position
		var stall := model("stall-red" if slot%3==0 else "stall-green",at,Vector3(1.8,1.8,2.8),layout.model_yaw)
		collider(stall,Vector3(0,0.48,0),Vector3(0.85,0.96,1.0))
		destinations.append({"title":"Stall %02d"%slot,"position":layout.approach,"attention":layout.seller+Vector3.UP*1.12,"service":"stall","slot":slot})
		# A fabric counter skirt and a readable front valance unify each row.
		var front := Vector3(side*4.79,0,at.z)
		var skirt := block(front+Vector3(0,0.52,0),Vector3(0.035,0.56,2.65),"a76e5d" if slot%3==0 else "507f73",false)
		var banner := block(front+Vector3(0,1.81,0),Vector3(0.035,0.26,2.65),"a76e5d" if slot%3==0 else "507f73",false)
		dressing.print_skirt(skirt,slot)
		skirt.name="CounterSkirt";banner.name="StallValance"
		counter_names[slot]=text3d("%02d  ·  MARKET"%slot,front+Vector3(-side*0.03,1.81,0),0.004,self,layout.yaw)
		counter_names[slot].layers=1 << (COUNTER_SIGN_LAYER-1)
		lantern(front+Vector3(0,2.22,1.06),"f1cc8d")
	for side in [-1,1]:
		for z in [-22.0,-10.0,10.0,22.0]:
			var blossom: bool=side*z<0 and absf(z)==10
			tree(Vector3(side*16,0,z),3.2,"e2aaa0" if blossom else "71966f")
			flowerbed(Vector3(side*12,0,z),Vector2(3,2))
		for z in [-17.0,-5.0,5.0,17.0]:
			model("nature/plant_bushLarge",Vector3(side*13.6,0,z),Vector3.ONE*2.0)
			model("nature/grass_large",Vector3(side*10.6,0,z+1),Vector3.ONE*1.4)
		for z in [-4.5,4.5]:
			model("stall-bench",Vector3(side*11,0,z),Vector3.ONE*1.7,side*PI/2)
			model("lantern",Vector3(side*12,0,z+2),Vector3.ONE*1.8)
	for z in [-17.0,17.0]:festival_line(z)
	spot("Festival stalls","Visit Vale in town to rent a stall and choose a keeper.",Vector3(-3.8,0,-4.8))
	spot("Island paths","East: shops. South: ring toss. Beyond the lanterns: Festival Arena.",Vector3(3.8,0,5.8))

func shop(title: String, at: Vector3, yaw: float, index: int) -> void:
	var home := house(at,4,3,2,yaw,["468377","ad6152","586887","b38658"][index])
	var board := block(Vector3.ZERO,Vector3(3.1,0.45,0.12),"355449",false)
	board.reparent(home,false);board.position=Vector3(0.4,1.8,1.58)
	var door := at+Vector3(0.85,0,3.1).rotated(Vector3.UP,yaw)
	text3d(title,Vector3(0.4,1.8,1.66),0.008,home)
	# Mark the door clearly; interaction moves into a furnished local room.
	var mat_node := block(door+Vector3(0,0.04,0),Vector3(2,0.08,1.5),"b58b62",false);mat_node.rotation.y=yaw
	dressing.storefront(at,yaw,index)
	var center := Vector3(210+index*20,0,0)
	path(center,Vector3(10,0,10));block(center+Vector3(0,-0.25,0),Vector3(10,0.5,10),"77604a")
	block(center+Vector3(0,4.15,0),Vector3(10,0.3,10),"bdab8b")
	if index!=1:
		var light := OmniLight3D.new();light.position=center+Vector3(0,3.3,0);light.omni_range=10;light.light_color=Color("ffe3b7");light.light_energy=1.1;add_child(light)
	for x in [-5,5]:block(center+Vector3(x,2,0),Vector3(0.25,4,10),"e6d4ae")
	for z in [-5,5]:block(center+Vector3(0,2,z),Vector3(10,4,0.25),"c7b18d")
	text3d(title,center+Vector3(0,2.7,-4.7),0.013)
	text3d("RENTALS · NPC SELLERS" if index==3 else "CLOTHING  /  FITTING ROOM" if index==1 else "INTERIOR PREVIEW · NO PURCHASES",center+Vector3(0,2.25,-4.7),0.006)
	block(center+Vector3(0,0.38,-2.5),Vector3(6,0.76,0.9),"896343")
	for side in [-1,1]:
		lantern(center+Vector3(side*3.8,2.8,-3.9),"edc178")
		for shelf in [0.9,1.6]:
			block(center+Vector3(side*3.8,shelf,-3.8),Vector3(1.4,0.12,1),"866341",false)
	dressing.room(center,index)
	if index==1:
		fitting_booth=preload("res://scripts/fitting_booth.gd").new()
		fitting_booth.position=center+Vector3(-2.6,0,1.25)
		add_child(fitting_booth)
		text3d("FITTING ROOM",fitting_booth.position+Vector3(0,2.47,.63),.005)
		destinations.append({"title":"Try on outfits","position":fitting_booth.position+Vector3(0,0,.95),"attention":fitting_booth.position+Vector3.UP*1.55,"service":"tailor"})
	var exit_position := center+Vector3(0,0,4.0)
	text3d("TO TOWN",center+Vector3(0,1.8,4.71),0.005,self,PI)
	destinations.append({"title":"Enter "+title,"position":door,"arrival":center+Vector3(0,0.15,1.3),"yaw":0.0})
	destinations.append({"title":"Return to town","position":exit_position,"arrival":door+Vector3(0,0.15,1).rotated(Vector3.UP,yaw),"yaw":yaw+PI})
	shop_exits.append({"title":title,"door":door,"room":center})
	destinations.append({"title":["Moss","Wisp","Rook","Vale"][index],"position":center+Vector3(0,0,-1.65),"attention":center+Vector3(0,1.18,-3.45),"service":["tea","tailor","curios","office"][index]})

func town_square() -> void:
	path(TOWN,Vector3(26,0,27))
	shop("MOSS & TEA",TOWN+Vector3(-8,0,-14),0,0)
	shop("THREAD",TOWN+Vector3(8,0,-14),0,1)
	shop("CURIOS",TOWN+Vector3(15,0,1),-PI/2,2)
	shop("STALL OFFICE",TOWN+Vector3(-8,0,15),PI,3)
	house(TOWN+Vector3(6,0,15),4,3,2,PI,"d0ad63")
	flowerbed(TOWN+Vector3(0,0,1),Vector2(6,3))
	for x in [-7,7]:
		model("stall-bench",TOWN+Vector3(x,0,2),Vector3.ONE*1.8,PI/2)
		model("lantern",TOWN+Vector3(x,0,-6),Vector3.ONE*2)
	spot("Town shops","Stall Office: rentals and sellers. THREAD: avatar clothing. Walk through the signed doors to meet the clerks.",TOWN+Vector3(-5,0,7))

func gardens_and_harbor() -> void:
	path(GARDEN,Vector3(20,0,20))
	for side in [-1,1]:
		for z in [-7,7]:flowerbed(GARDEN+Vector3(side*6,0,z),Vector2(5,2.5))
		model("stall-bench",GARDEN+Vector3(side*6,0,0),Vector3.ONE*1.8,side*PI/2)
		for z in [-12,0,12]:tree(GARDEN+Vector3(side*13,0,z),3.0,"d3a2a2" if z==0 else "669779")
	spot("Garden court","A quieter meeting district. Benches and gardens are open; social activities are still being built.",GARDEN+Vector3(0,0,6))
	path(HARBOR,Vector3(24,0,15))
	for side in [-1,1]:
		model("cart",HARBOR+Vector3(side*7,0,0),Vector3.ONE*2)
		model("lantern",HARBOR+Vector3(side*10,0,4),Vector3.ONE*2)
	spot("Harbor terrace","Arrival and travel will live here. This island is local for now; no multiplayer destination is opened.",HARBOR+Vector3(0,0,3))
	# Clear paths reserve a fourth district without pretending it has services.
	path(Vector3(-36,0,35),Vector3(22,0,18))
	spot("Workshop court","Space reserved for future crafting and community functions. Nothing is purchased or produced in this build.",Vector3(-36,0,36))

func district(at: Vector3) -> String:
	if at.x>180:
		for item in shop_exits:
			if absf(at.x-item.room.x)<10:return item.title
	if at.distance_to(festival.ARENA)<8:return "Festival Arena"
	if at.distance_to(TOWN)<24:return "Town Square"
	if at.distance_to(GARDEN)<20:return "Garden Court"
	if at.z>48:return "Harbor Terrace"
	if at.x < -23 and at.z>23:return "Workshop Court"
	if absf(at.x)<22 and absf(at.z)<27:return "Festival Park"
	return "Island Walk"

func _ready() -> void:
	lantern_mesh.radius=0.22;lantern_mesh.height=0.60;lantern_mesh.radial_segments=12;lantern_mesh.rings=6
	var env := WorldEnvironment.new();env.environment=Environment.new();add_child(env)
	var sky := Sky.new();var atmosphere := ShaderMaterial.new()
	atmosphere.shader=preload("res://shaders/coastal_sky.gdshader")
	atmosphere.set_shader_parameter("coast",preload("res://assets/sky/archipelago.jpg"))
	sky.sky_material=atmosphere;env.environment.sky=sky;env.environment.background_mode=Environment.BG_SKY
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("d1dce7");env.environment.ambient_light_energy=0.52
	env.environment.fog_enabled=true;env.environment.fog_mode=Environment.FOG_MODE_DEPTH
	env.environment.fog_depth_begin=65;env.environment.fog_depth_end=230
	env.environment.fog_density=0.35;env.environment.fog_light_color=Color("b8dbdc");env.environment.fog_sky_affect=0.0
	var sun := DirectionalLight3D.new();sun.rotation_degrees=Vector3(-38,-54,0);sun.light_color=Color("ffe2b7")
	sun.light_energy=0.72;sun.shadow_enabled=true;sun.directional_shadow_max_distance=70;add_child(sun)
	paving=ShaderMaterial.new();paving.shader=preload("res://shaders/festival_paving.gdshader")
	add_child(dressing);dressing.setup(self)
	terrain();park_market();dressing.park()
	path(Vector3(25,0,0),Vector3(30,0,6));path(Vector3(38,0,-9),Vector3(6,0,22))
	path(Vector3(-25,0,0),Vector3(30,0,6));path(Vector3(-39,0,-11),Vector3(6,0,25))
	path(Vector3(0,0,38),Vector3(7,0,37));path(Vector3(-20,0,35),Vector3(34,0,6))
	town_square();gardens_and_harbor()
	add_child(festival);festival.build(self)
	for i in 44:
		var a := TAU*i/44.0;var r := 67.0+5*sin(i*2.3)
		tree(Vector3(sin(a)*r,0,cos(a)*r),2.5+(i%3)*0.5)
	for at in [Vector3(-23,0,-14),Vector3(24,0,15),Vector3(-22,0,20),Vector3(21,0,-21),Vector3(-22,0,-38)]:tree(at,3.4)

	batch_static_props()

func batch_static_props() -> void:
	# Repeated imported meshes share draw calls within small spatial cells.
	# Physics remains on the authored roots. Animated cloth is not batched.
	var groups: Dictionary = {}
	for root in prop_roots:
		for part in root.find_children("*","MeshInstance3D",true,false):
			var cell := Vector2i(floori(part.global_position.x/24),floori(part.global_position.z/24))
			var key := str(part.mesh.get_instance_id())+":"+str(cell)+":"+str(part.cast_shadow)+":"+str(part.material_override.get_instance_id() if part.material_override!=null else 0)
			if not groups.has(key):groups[key]={"mesh":part.mesh,"shadow":part.cast_shadow,"material":part.material_override,"cell":cell,"transforms":[]}
			groups[key].transforms.append(part.global_transform)
			part.hide()
	for group in groups.values():
		var node := MultiMeshInstance3D.new();add_child(node)
		node.position=Vector3(group.cell.x*24+12,0,group.cell.y*24+12)
		node.cast_shadow=group.shadow;node.material_override=group.material;node.visibility_range_end=110
		var batch := MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D;batch.mesh=group.mesh;batch.instance_count=group.transforms.size()
		for i in group.transforms.size():batch.set_instance_transform(i,node.global_transform.affine_inverse()*group.transforms[i])
		node.multimesh=batch

func update_showcases(places: Array) -> void:
	var next := {}
	for row in places:
		var slot := int(row.get("slot",0))
		if not counter_names.has(slot) or row.get("tenant_id")==null:continue
		next[slot]={"tenant":str(row.get("tenant_name") if row.get("tenant_name") else "Market keeper"),"items":row.get("showcase",[])}
	for slot in counter_names:
		if next.get(slot)==display_rows.get(slot):continue
		if stands.has(slot):
			stands[slot].queue_free()
			stands.erase(slot)
		var label: Label3D=counter_names[slot]
		label.text="%02d  ·  %s"%[slot,next[slot].tenant if next.has(slot) else "MARKET"]
		var width := ThemeDB.fallback_font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.font_size).x
		label.pixel_size=minf(.004,2.5/maxf(1,width))
		if not next.has(slot):continue
		var layout := stall_layout(slot)
		var display := Node3D.new()
		add_child(display);stands[slot]=display
		display.position=Vector3(layout.side*4.98,1.05,layout.position.z)
		display.rotation.y=layout.yaw
		preload("counter_display.gd").fill(display,next[slot].items)
	display_rows=next
