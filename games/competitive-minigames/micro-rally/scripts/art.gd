# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
static var models: Dictionary = {}
static var materials: Dictionary = {}

static func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var key = str(color)+str(glow)
	if materials.has(key): return materials[key]
	var m = StandardMaterial3D.new()
	m.albedo_color=color; m.roughness=0.85
	if color.a<1:
		m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode=BaseMaterial3D.CULL_DISABLED
	if glow>0: m.emission_enabled=true; m.emission=color; m.emission_energy_multiplier=glow
	materials[key]=m
	return m

static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var mesh = BoxMesh.new(); mesh.size=size
	node.mesh=mesh; node.material_override=material(color); node.position=pos
	parent.add_child(node)
	return node

static func model(kind: String, id: String) -> Node3D:
	var path = "res://assets/"+kind+"/"+id+".glb"
	if not models.has(path): models[path]=load(path)
	return models[path].instantiate()

static func mesh_parts(node: Node3D, transform: Transform3D = Transform3D.IDENTITY) -> Array:
	var parts: Array=[]
	var combined = transform*node.transform
	if node is MeshInstance3D: parts.append([node.mesh,combined])
	for child in node.get_children():
		if child is Node3D: parts.append_array(mesh_parts(child,combined))
	return parts

static func instances(parent: Node3D, kind: String, id: String, transforms: Array) -> void:
	if transforms.is_empty(): return
	var source = model(kind,id)
	for part in mesh_parts(source):
		var node = MultiMeshInstance3D.new()
		var multi = MultiMesh.new()
		var mesh = part[0].duplicate()
		for i in mesh.get_surface_count():
			var original = mesh.surface_get_material(i)
			if not original is StandardMaterial3D: continue
			var key = "nature/"+original.resource_name+id
			if not materials.has(key):
				var mat = ShaderMaterial.new(); mat.shader=preload("res://shaders/surface.gdshader")
				var tint = original.albedo_color; var surface_kind = 4
				if original.resource_name.to_lower().contains("leaf"): tint=Color("4e7143") if id.contains("Tall") else Color("62804a")
				elif original.resource_name.to_lower().contains("wood"): tint=Color("755037"); surface_kind=2
				elif id.contains("rock") or id.contains("stone"): tint=Color("7c8478"); surface_kind=3
				elif original.resource_name.to_lower().contains("grass"): tint=Color("5c812e")
				mat.set_shader_parameter("tint",tint); mat.set_shader_parameter("kind",surface_kind)
				mat.set_shader_parameter("grain_axis",Vector3.UP); materials[key]=mat
			mesh.surface_set_material(i,materials[key])
		multi.transform_format=MultiMesh.TRANSFORM_3D; multi.mesh=mesh
		multi.instance_count=transforms.size()
		for i in transforms.size(): multi.set_instance_transform(i,transforms[i]*part[1])
		node.multimesh=multi; node.visibility_range_end=100
		node.visibility_range_end_margin=12
		if id.contains("grass") or id.contains("flower"): node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; node.visibility_range_end=52
		parent.add_child(node)
	source.free()

static func collider(parent: Node3D, size: Vector3, pos: Vector3) -> StaticBody3D:
	var body = StaticBody3D.new(); body.position=pos
	var shape = CollisionShape3D.new(); var box_shape = BoxShape3D.new(); box_shape.size=size
	shape.shape=box_shape; body.add_child(shape); parent.add_child(body)
	return body
