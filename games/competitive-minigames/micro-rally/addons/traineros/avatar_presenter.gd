# SPDX-License-Identifier: GPL-3.0-or-later
class_name TrainerAvatarPresenter
extends Node3D
## Portable glTF consumer. The SDK descriptor comes from avatar.get/subscribe.
## No wardrobe, model, textures or permanent profile writes belong to the game.
var profile_id := ""
var appearance_revision := ""
var eye_height := 0.8
var actions: Dictionary = {}
var animation_player: AnimationPlayer
var facial_rig: Dictionary = {}
var _face_bindings: Dictionary = {}
var _face_values: Dictionary = {}
var _face_from: Dictionary = {}
var _face_to: Dictionary = {}
var _face_elapsed := 0.0
var _face_duration := 0.0
var _reaction_remaining := 0.0
var _base_expression := "neutral"
var _base_strength := 1.0
var _mouth_override: Dictionary = {}
var _cpu_faces: Dictionary = {}
var _cpu_correctives: Dictionary = {}

class CorrectiveWeights:
	extends Node
	var values := PackedFloat32Array()
	var dirty := true
	func _get_property_list() -> Array[Dictionary]:
		var properties: Array[Dictionary] = []
		for i in values.size():properties.append({"name":"morph_"+str(i),"type":TYPE_FLOAT,"usage":PROPERTY_USAGE_DEFAULT})
		return properties
	func _set(property: StringName, value: Variant) -> bool:
		var text := str(property)
		if not text.begins_with("morph_"):return false
		var i := text.trim_prefix("morph_").to_int()
		if i<0 or i>=values.size():return false
		if values[i]!=float(value):values[i]=float(value);dirty=true
		return true
	func _get(property: StringName) -> Variant:
		var text := str(property)
		if text.begins_with("morph_"):
			var i := text.trim_prefix("morph_").to_int()
			if i>=0 and i<values.size():return values[i]
		return null


static func from_descriptor(descriptor: Dictionary) -> TrainerAvatarPresenter:
	if descriptor.get("schema") != 1 or descriptor.get("rig") != "trainer-humanoid-54-v1": return null
	var path: String = descriptor.get("glb", "")
	if not path.is_absolute_path() or not path.ends_with(".glb"): return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 67108864: return null
	var bytes := file.get_buffer(file.get_length())
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(bytes)
	if hash_context.finish().hex_encode() != descriptor.get("sha256", ""): return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_buffer(bytes, "", state) != OK: return null
	var scene := document.generate_scene(state)
	if not scene is Node3D:
		if scene != null: scene.free()
		return null
	if not _prepare_vertex_colors(scene):
		scene.free()
		return null
	var presenter := TrainerAvatarPresenter.new()
	presenter.profile_id = descriptor.get("profile", "")
	presenter.appearance_revision = descriptor.get("revision", "")
	presenter.eye_height = float(descriptor.get("eyeHeight", 0.8))
	presenter.actions = descriptor.get("actions", {})
	presenter.add_child(scene)
	presenter.animation_player = scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var metadata: Dictionary = state.json.get("extras", {}).get("trainerFace", {})
	presenter._prepare_cpu_correctives(metadata.get("controls",[]))
	presenter._bind_face(metadata)
	return presenter

func _prepare_cpu_faces(controls: Array) -> void:
	if DisplayServer.get_name()=="headless" or RenderingServer.get_current_rendering_method()!="gl_compatibility": return
	# Compatibility GPU morphs corrupt small negative facial deltas on the
	# handheld renderer. Evaluate only these small face meshes on the CPU;
	# Skeleton skinning stays on GPU; body/garment correctives have their own
	# CPU evaluator below for the same Compatibility renderer failure class.
	for node in find_children("*","MeshInstance3D",true,false):
		var instance := node as MeshInstance3D
		var source := instance.mesh as ArrayMesh
		if source==null or source.get_blend_shape_count()==0: continue
		if not str(source.get_blend_shape_name(0)) in controls: continue
		var names: Array = []
		for i in source.get_blend_shape_count(): names.append(str(source.get_blend_shape_name(i)))
		var surfaces: Array = []
		for i in source.get_surface_count():
			var arrays := source.surface_get_arrays(i)
			var deltas: Array = []
			for shape in source.surface_get_blend_shape_arrays(i):
				var changes: Array = []
				for v in arrays[Mesh.ARRAY_VERTEX].size():
					var position: Vector3 = shape[Mesh.ARRAY_VERTEX][v]
					var normal: Vector3 = shape[Mesh.ARRAY_NORMAL][v]
					if source.blend_shape_mode==Mesh.BLEND_SHAPE_MODE_NORMALIZED:
						position-=arrays[Mesh.ARRAY_VERTEX][v];normal-=arrays[Mesh.ARRAY_NORMAL][v]
					if position.length_squared()>0 or normal.length_squared()>0: changes.append([v,position,normal])
				deltas.append(changes)
			surfaces.append({"arrays":arrays,"deltas":deltas,"material":source.surface_get_material(i),"primitive":source.surface_get_primitive_type(i)})
		_cpu_faces[instance.get_instance_id()]={"instance":instance,"names":names,"surfaces":surfaces,"mesh":ArrayMesh.new()}
		instance.mesh=_cpu_faces[instance.get_instance_id()].mesh
	_update_cpu_faces()

func _update_cpu_faces() -> void:
	for face in _cpu_faces.values():
		var mesh: ArrayMesh = face.mesh
		mesh.clear_surfaces()
		for surface in face.surfaces:
			var arrays: Array = surface.arrays.duplicate()
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL].duplicate()
			for i in face.names.size():
				var weight: float = _face_values.get(face.names[i],0)
				if weight==0: continue
				for change in surface.deltas[i]:
					positions[change[0]]+=change[1]*weight;normals[change[0]]+=change[2]*weight
			for i in normals.size(): normals[i]=normals[i].normalized()
			arrays[Mesh.ARRAY_VERTEX]=positions;arrays[Mesh.ARRAY_NORMAL]=normals
			mesh.add_surface_from_arrays(surface.primitive,arrays,[],{},Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
			mesh.surface_set_material(mesh.get_surface_count()-1,surface.material)

func _bind_face(metadata: Dictionary) -> void:
	if metadata.get("schema") != 1: return
	var controls = metadata.get("controls", [])
	if not controls is Array or controls.size() > 32: return
	_prepare_cpu_faces(controls)
	for control in controls:
		if not control is String: return
		var bindings: Array = []
		for node in find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			var index: int = _cpu_faces[mesh.get_instance_id()].names.find(control) if _cpu_faces.has(mesh.get_instance_id()) else mesh.find_blend_shape_by_name(control)
			if index >= 0: bindings.append([mesh, index])
		if bindings.is_empty():
			_face_bindings.clear(); return
		_face_bindings[control] = bindings
		_face_values[control] = 0.0
	facial_rig = metadata.duplicate(true)

func supports_expression(name: String) -> bool:
	return facial_rig.get("expressions", {}).has(name)

func set_expression(name: String, strength := 1.0, fade := 0.18) -> bool:
	if not supports_expression(name) or not is_finite(strength) or not is_finite(fade): return false
	_base_expression = name; _base_strength = clampf(strength, 0, 1)
	_reaction_remaining = 0; _mouth_override.clear()
	_blend_face(_base_face(), fade)
	return true

func set_mouth(name: String, strength := 1.0, fade := 0.12) -> bool:
	if not name in facial_rig.get("mouths", []) or not is_finite(strength) or not is_finite(fade): return false
	_mouth_override = {"name":name, "strength":clampf(strength, 0, 1)}
	_reaction_remaining = 0
	_blend_face(_base_face(), fade)
	return true

func clear_mouth_override(fade := 0.12) -> void:
	_mouth_override.clear(); _reaction_remaining = 0
	_blend_face(_base_face(), fade)

func react(name: String, strength := 1.0, hold := -1.0, fade := 0.12) -> bool:
	var reaction: Dictionary = facial_rig.get("reactions", {}).get(name, {})
	if reaction.is_empty() or not is_finite(strength) or not is_finite(hold) or not is_finite(fade): return false
	var expression: String = reaction.get("expression", "")
	if not supports_expression(expression): return false
	var seconds := float(reaction.get("hold", 1.0)) if hold < 0 else hold
	_reaction_remaining = clampf(seconds, 0.01, 10.0) + clampf(fade, 0, 2)
	_blend_face(_expression_face(expression, clampf(strength, 0, 1)), fade)
	return true

func reset_face(fade := 0.18) -> void:
	_base_expression = "neutral"; _base_strength = 1.0
	_mouth_override.clear(); _reaction_remaining = 0
	_blend_face({}, fade)

func _expression_face(name: String, strength: float) -> Dictionary:
	var values: Dictionary = {}
	for control in facial_rig.get("expressions", {}).get(name, {}):
		if _face_bindings.has(control): values[control] = clampf(float(facial_rig.expressions[name][control]), 0, 1) * strength
	return values

func _base_face() -> Dictionary:
	var values := _expression_face(_base_expression, _base_strength)
	if not _mouth_override.is_empty():
		for control in _face_bindings:
			if control.begins_with("mouth_"): values[control] = 0.0
		if _mouth_override.name != "rest": values["mouth_"+_mouth_override.name] = _mouth_override.strength
	return values

func _blend_face(values: Dictionary, fade: float) -> void:
	_face_from = _face_values.duplicate()
	_face_to = values
	_face_elapsed = 0; _face_duration = clampf(fade, 0, 2) if is_finite(fade) else 0
	_apply_face(1.0 if _face_duration == 0 else 0.0)
	set_process(not _face_bindings.is_empty())

func _apply_face(t: float) -> void:
	for control in _face_bindings:
		var weight := lerpf(float(_face_from.get(control, 0)), float(_face_to.get(control, 0)), t)
		_face_values[control] = weight
		for binding in _face_bindings[control]:
			if is_instance_valid(binding[0]) and not _cpu_faces.has(binding[0].get_instance_id()): binding[0].set_blend_shape_value(binding[1], weight)
	_update_cpu_faces()

func _process(delta: float) -> void:
	if _reaction_remaining > 0:
		_reaction_remaining -= delta
		if _reaction_remaining <= 0:
			_blend_face(_base_face(), 0.2)
	_face_elapsed += delta
	var t := clampf(_face_elapsed / _face_duration, 0, 1) if _face_duration > 0 else 1.0
	_apply_face(t*t*(3-2*t))
	if t == 1 and _reaction_remaining <= 0: set_process(false)

static func _prepare_vertex_colors(scene: Node3D) -> bool:
	# glTF COLOR_0 is linear. Compatibility multiplies vertex colors in sRGB
	# space and ignores BaseMaterial3D.vertex_color_is_srgb. Convert only the
	# imported GPU color attribute; retain geometry, UVs, skin and morph buffers.
	var compatibility := DisplayServer.get_name()!="headless" and RenderingServer.get_current_rendering_method()=="gl_compatibility"
	var visited: Dictionary = {}
	for node in scene.find_children("*","MeshInstance3D",true,false):
		var mesh := (node as MeshInstance3D).mesh as ArrayMesh
		if mesh==null or visited.has(mesh.get_instance_id()): continue
		visited[mesh.get_instance_id()]=true
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface) as BaseMaterial3D
			if material==null: continue
			var format := mesh.surface_get_format(surface)
			if not (format & Mesh.ARRAY_FORMAT_COLOR): continue
			# glTF COLOR_0 multiplies the material. Godot can leave the flag off
			# for a material that previously had no colored primitives (brows).
			material.vertex_color_use_as_albedo=true
			if not compatibility or material.vertex_color_is_srgb: continue
			var count := mesh.surface_get_array_len(surface)
			var stride := RenderingServer.mesh_surface_get_format_attribute_stride(format,count)
			var offset := RenderingServer.mesh_surface_get_format_offset(format,count,Mesh.ARRAY_COLOR)
			var data: PackedByteArray = RenderingServer.mesh_get_surface(mesh.get_rid(),surface).get("attribute_data",PackedByteArray())
			if count<1 or stride<4 or offset<0 or offset+(count-1)*stride+4>data.size(): return false
			for i in count:
				var start := offset+i*stride
				var color := Color(data[start]/255.0,data[start+1]/255.0,data[start+2]/255.0).linear_to_srgb()
				data[start]=roundi(color.r*255);data[start+1]=roundi(color.g*255);data[start+2]=roundi(color.b*255)
			mesh.surface_update_attribute_region(surface,0,data)
	return true

func play_action(action: String) -> bool:
	# Unsupported game actions are explicit; wave is not a fabricated golf stroke.
	if animation_player == null or not actions.has(action): return false
	var clip: String = actions[action]
	if not animation_player.has_animation(clip): return false
	animation_player.play(clip, 0.15)
	return true

func clear_identity() -> void:
	set_process(false)
	facial_rig.clear(); _face_bindings.clear(); _face_values.clear()
	_face_from.clear(); _face_to.clear(); _mouth_override.clear(); _reaction_remaining = 0
	_cpu_faces.clear(); _cpu_correctives.clear()
	if RenderingServer.frame_pre_draw.is_connected(_update_cpu_correctives):RenderingServer.frame_pre_draw.disconnect(_update_cpu_correctives)
	_base_expression = "neutral"; _base_strength = 1.0
	profile_id = ""
	for node in get_children():
		remove_child(node)
		node.queue_free()
	animation_player = null

# Compatibility also corrupts zero-delta head vertices when body corrective
# weights play. Preserve the imported clips and skin, but route their scalar
# tracks to per-instance weights and update only dirty corrective surfaces.
# The GLB and its authenticated hash stay unchanged; other renderers keep GPU morphs.
func _prepare_cpu_correctives(controls: Array, force := false) -> void:
	if not force and (DisplayServer.get_name()=="headless" or RenderingServer.get_current_rendering_method()!="gl_compatibility"):return
	if animation_player==null:return
	var animation_root := animation_player.get_node(animation_player.root_node)
	var paths: Dictionary = {}
	for node in find_children("*","MeshInstance3D",true,false):
		var instance := node as MeshInstance3D
		var source := instance.mesh as ArrayMesh
		if source==null or source.get_blend_shape_count()==0 or str(source.get_blend_shape_name(0)) in controls:continue
		var names: Array = []
		for i in source.get_blend_shape_count():names.append(str(source.get_blend_shape_name(i)))
		var proxy := CorrectiveWeights.new()
		proxy.name="CpuCorrectiveWeights";proxy.values.resize(names.size());instance.add_child(proxy)
		var surfaces: Array = []
		for i in source.get_surface_count():
			var arrays := source.surface_get_arrays(i)
			var deltas: Array = []
			for shape in source.surface_get_blend_shape_arrays(i):
				var changes: Array = []
				if source.blend_shape_mode==Mesh.BLEND_SHAPE_MODE_NORMALIZED and shape[Mesh.ARRAY_VERTEX]==arrays[Mesh.ARRAY_VERTEX] and shape[Mesh.ARRAY_NORMAL]==arrays[Mesh.ARRAY_NORMAL]:
					deltas.append(changes);continue
				for v in arrays[Mesh.ARRAY_VERTEX].size():
					var position: Vector3 = shape[Mesh.ARRAY_VERTEX][v]
					var normal: Vector3 = shape[Mesh.ARRAY_NORMAL][v]
					if source.blend_shape_mode==Mesh.BLEND_SHAPE_MODE_NORMALIZED:
						position-=arrays[Mesh.ARRAY_VERTEX][v];normal-=arrays[Mesh.ARRAY_NORMAL][v]
					if position.length_squared()>0 or normal.length_squared()>0:changes.append([v,position,normal])
				deltas.append(changes)
			surfaces.append({"arrays":arrays,"deltas":deltas,"material":source.surface_get_material(i),"primitive":source.surface_get_primitive_type(i)})
		var mesh := ArrayMesh.new()
		_cpu_correctives[instance.get_instance_id()]={"instance":instance,"names":names,"surfaces":surfaces,"mesh":mesh,"proxy":proxy}
		paths[str(animation_root.get_path_to(instance))]={"path":str(animation_root.get_path_to(proxy)),"names":names}
		instance.mesh=mesh
	for clip_name in animation_player.get_animation_list():
		var clip := animation_player.get_animation(clip_name)
		for i in clip.get_track_count():
			if clip.track_get_type(i)!=Animation.TYPE_BLEND_SHAPE:continue
			var path := clip.track_get_path(i)
			var key := str(path.get_concatenated_names())
			if not paths.has(key) or path.get_subname_count()!=1:continue
			var index: int = paths[key].names.find(str(path.get_subname(0)))
			if index<0:continue
			var interpolation := clip.track_get_interpolation_type(i)
			var loop_wrap := clip.track_get_interpolation_loop_wrap(i)
			var enabled := clip.track_is_enabled(i)
			var keys: Array = []
			for k in clip.track_get_key_count(i):keys.append([clip.track_get_key_time(i,k),clip.track_get_key_value(i,k),clip.track_get_key_transition(i,k)])
			clip.remove_track(i);clip.add_track(Animation.TYPE_VALUE,i)
			clip.track_set_path(i,NodePath(paths[key].path+":morph_"+str(index)))
			clip.track_set_interpolation_type(i,interpolation)
			clip.track_set_interpolation_loop_wrap(i,loop_wrap)
			clip.track_set_enabled(i,enabled)
			clip.value_track_set_update_mode(i,Animation.UPDATE_CONTINUOUS)
			for keyframe in keys:clip.track_insert_key(i,keyframe[0],keyframe[1],keyframe[2])
	_update_cpu_correctives()
	if not _cpu_correctives.is_empty():RenderingServer.frame_pre_draw.connect(_update_cpu_correctives)

func _update_cpu_correctives() -> void:
	for body in _cpu_correctives.values():
		var proxy: CorrectiveWeights = body.proxy
		if not proxy.dirty:continue
		proxy.dirty=false
		var mesh: ArrayMesh = body.mesh
		mesh.clear_surfaces()
		for surface in body.surfaces:
			var arrays: Array = surface.arrays.duplicate()
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL].duplicate()
			var touched: Dictionary = {}
			for i in proxy.values.size():
				var weight := proxy.values[i]
				if weight==0:continue
				for change in surface.deltas[i]:
					positions[change[0]]+=change[1]*weight;normals[change[0]]+=change[2]*weight;touched[change[0]]=true
			for i in touched:normals[i]=normals[i].normalized()
			arrays[Mesh.ARRAY_VERTEX]=positions;arrays[Mesh.ARRAY_NORMAL]=normals
			mesh.add_surface_from_arrays(surface.primitive,arrays,[],{},Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
			mesh.surface_set_material(mesh.get_surface_count()-1,surface.material)
