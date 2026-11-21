# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
const KINDS=["rocket","pulse","boost","shield","cool","mystery","repair"]
const NAMES=["ROCKETS","SHOCKWAVE","NITRO","PIT SHIELD","COOLANT","WILD CRATE","REPAIR"]
const TINT=[Color("ff7148"),Color("46e8ff"),Color("ffc738"),Color("69dd90"),Color("84bfff"),Color("d996ff"),Color("7beeb8")]
const ROUTE=["rocket","shield","boost","pulse","cool","boost"]
static var signs: Dictionary={}
static var cases: Dictionary={}

static func tint(kind: String) -> Color: return TINT[KINDS.find(kind)]
static func title(kind: String) -> String: return NAMES[KINDS.find(kind)]

static func useful(car: Node3D, kind: String) -> bool:
	match kind:
		"rocket","pulse","mystery": return car.ammo==0
		"shield": return not car.shield_item or car.health<100 or car.missing_wheels!=0
		"cool": return car.weapon_heat>5
		"boost": return car.boost<98
	return false

static func collect(car: Node3D, kind: String) -> bool:
	if not useful(car,kind): return false
	var award:=kind
	if kind=="mystery": award="rocket" if randi_range(0,1)==0 else "pulse"
	match award:
		"rocket","pulse":
			car.weapon=award
			car.ammo=2 if award=="rocket" else 1
			car.weapon_selected=true
		"boost": car.boost=minf(100,car.boost+65)
		"shield":
			car.shield_item=true
			car.health=minf(100,car.health+20)
			car.repair_wheels()
		"cool": car.cool_weapon()
	car.pickup_serial+=1
	car.last_award=KINDS.find(award)
	return true

# One cached, two-sided enamel badge per type. The large silhouettes read from the chase and overhead cameras.
static func badge(kind: String) -> Node3D:
	if not signs.has(kind):
		var paint:=SurfaceTool.new()
		paint.begin(Mesh.PRIMITIVE_TRIANGLES)
		var accent:=tint(kind)
		var rim:=PackedVector2Array([Vector2(-1,-0.52),Vector2(-0.66,-0.9),Vector2(0.66,-0.9),Vector2(1,-0.52),Vector2(1,0.52),Vector2(0.66,0.9),Vector2(-0.66,0.9),Vector2(-1,0.52)])
		polygon(paint,rim,accent,0)
		polygon(paint,Transform2D(0,Vector2(0.90,0.89),0,Vector2.ZERO)*rim,Color("212735"),0.01)
		var strokes: Array=[]
		match kind:
			"rocket":
				strokes=[[[-3,-3],[-3,1],[1,5],[4,5],[4,2],[0,-2]], [[-4,-2],[-5,-5],[-2,-4]], [[0,-2],[2,0],[2,-3],[-1,-4]]]
			"pulse":
				strokes=[[[-6,0],[-3,0],[-1,5],[1,-2],[2,1],[6,1],[6,-1],[3,-1],[1,-5],[-1,1],[-2,-2],[-6,-2]]]
			"boost":
				for x in [-3,2]: strokes.append([[x-2,4],[x,4],[x+3,0],[x,-4],[x-2,-4],[x+1,0]])
			"shield": strokes=[[[-4,4],[4,4],[4,-1],[0,-5],[-4,-1]]]
			"cool":
				for angle in [0,PI/3,2*PI/3]:
					var bar=PackedVector2Array([Vector2(-5,-0.75),Vector2(5,-0.75),Vector2(5,0.75),Vector2(-5,0.75)])
					polygon(paint,Transform2D(angle,Vector2(0.13,0.13),0,Vector2.ZERO)*bar,Color.WHITE,0.03)
			"repair": strokes=[[[-4,1],[-1,1],[-1,4],[1,4],[1,1],[4,1],[4,-1],[1,-1],[1,-4],[-1,-4],[-1,-1],[-4,-1]]]
			"mystery": strokes=[[[-4,2],[-4,4],[-2,5],[2,5],[4,3],[4,1],[1,-1],[1,-2],[-1,-2],[-1,0],[2,2],[2,3],[-2,3],[-2,2]], [[-1,-3],[1,-3],[1,-5],[-1,-5]]]
		for stroke in strokes:
			var points:=PackedVector2Array()
			for pt in stroke: points.append(Vector2(pt[0],pt[1])*0.13)
			polygon(paint,points,Color("fff6dd"),0.03)
		var mat:=StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo=true; mat.vertex_color_is_srgb=true
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode=BaseMaterial3D.CULL_DISABLED; mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
		paint.set_material(mat)
		signs[kind]=paint.commit()
		var casework:=SurfaceTool.new()
		casework.begin(Mesh.PRIMITIVE_TRIANGLES)
		panel(casework,Vector3(1.48,0.57,1.02),Vector3(0,-0.46,0),Color("49535b"))
		for y in [-0.75,-0.17]:
			panel(casework,Vector3(1.6,0.14,1.1),Vector3(0,y,0),Color("292f34"))
		for x in [-0.48,0.48]:
			panel(casework,Vector3(0.14,0.77,1.14),Vector3(x,-0.46,0),accent)
		var metal:=StandardMaterial3D.new()
		metal.vertex_color_use_as_albedo=true; metal.vertex_color_is_srgb=true; metal.roughness=0.68
		casework.set_material(metal)
		cases[kind]=casework.commit()
	var root:=Node3D.new()
	var case_mesh:=MeshInstance3D.new()
	case_mesh.mesh=cases[kind]; case_mesh.visibility_range_end=85
	root.add_child(case_mesh)
	var node:=MeshInstance3D.new()
	node.mesh=signs[kind]; node.visibility_range_end=110
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position.y=0.48
	node.scale=Vector3.ONE*0.84
	root.add_child(node)
	return root

static func panel(surface: SurfaceTool,size: Vector3,center: Vector3,color: Color) -> void:
	var box:=BoxMesh.new()
	box.size=size
	var data:=box.get_mesh_arrays()
	for index in data[Mesh.ARRAY_INDEX]:
		surface.set_color(color)
		surface.set_normal(data[Mesh.ARRAY_NORMAL][index])
		surface.add_vertex(center+data[Mesh.ARRAY_VERTEX][index])

static func polygon(surface: SurfaceTool, points: PackedVector2Array, color: Color, depth: float) -> void:
	for index in Geometry2D.triangulate_polygon(points):
		surface.set_color(color)
		surface.add_vertex(Vector3(points[index].x,points[index].y,depth))
