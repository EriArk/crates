# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Population=preload("res://scripts/population.gd")
var failures: Array[String]=[]
var report: Dictionary={}
func check(ok: bool, message: String) -> void:
	if not ok and not failures.has(message):failures.append(message)
func _initialize() -> void:call_deferred("run")

func samples(visual: Node3D, sk: Skeleton3D) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for part in visual.find_children("*","MeshInstance3D",true,false):
		if not part.visible or part.skin==null:continue
		var binds: Array[Transform3D]=[];var ids: Array[int]=[]
		for i in part.skin.get_bind_count():
			binds.append(part.skin.get_bind_pose(i))
			var bone: int=part.skin.get_bind_bone(i)
			if bone<0:bone=sk.find_bone(part.skin.get_bind_name(i))
			check(bone>=0,"Skin bind resolves: "+str(part.name));ids.append(bone)
		for surface in part.mesh.get_surface_count():
			var arrays: Array=part.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
			var influences := bones.size()/vertices.size()
			for v in range(0,vertices.size(),maxi(1,vertices.size()/80)):
				var entries: Array[Dictionary]=[]
				for j in influences:
					var weight: float=weights[v*influences+j]
					if weight>0:
						var bind: int=bones[v*influences+j]
						entries.append({"bone":ids[bind],"bind":binds[bind],"weight":weight})
				result.append({"vertex":vertices[v],"entries":entries})
	return result

func run() -> void:
	var pop=Population.new();root.add_child(pop)
	for species in pop.SPECIES:
		var actor: Dictionary=pop.figure(species,Vector3.ZERO,1.0,0)
		var player: AnimationPlayer=actor.player
		player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var sk: Skeleton3D=actor.visual.find_child("Skeleton3D",true,false)
		check(sk!=null,"Native skeleton: "+species)
		var rests: Array[Transform3D]=[]
		for i in sk.get_bone_count():rests.append(sk.get_bone_rest(i))
		var vertices := samples(actor.visual,sk)
		var previous: Array[Vector3]=[];var maximum_step := 0.0;var maximum_radius := 0.0;var worst := {};var scales := {}
		var clips: Array=["Idle","Walk","Idle"] if species!="Pigeon" else ["Flying_Idle","Fast_Flying","Flying_Idle"]
		if player.has_animation("Wave"):clips.append_array(["Wave","Idle"])
		for clip in clips:
			pop.play(actor,clip)
			for frame in maxi(180,ceili(player.get_animation(clip).length/player.speed_scale*120)+12):
				player.advance(1.0/60);sk.force_update_all_bone_transforms()
				for bone in sk.get_bone_count():
					check(sk.get_bone_rest(bone).is_equal_approx(rests[bone]),"Unchanged bind: "+species)
					check(sk.get_bone_pose_rotation(bone).is_finite(),"Finite bone rotation: "+species)
					if sk.get_bone_pose_scale(bone).distance_to(rests[bone].basis.get_scale())>0.0001:scales[sk.get_bone_name(bone)]={"rest":str(rests[bone].basis.get_scale()),"pose":str(sk.get_bone_pose_scale(bone)),"clip":clip,"frame":frame}
					check(sk.get_bone_pose_scale(bone).distance_to(rests[bone].basis.get_scale())<0.0001,"No bone rescaling: "+species)
				var current: Array[Vector3]=[]
				for sample in vertices:
					var point := Vector3.ZERO
					for entry in sample.entries:point+=(sk.get_bone_global_pose(entry.bone)*entry.bind*sample.vertex)*entry.weight
					check(point.is_finite(),"Finite skinned vertex: "+species)
					maximum_radius=maxf(maximum_radius,point.length())
					if not previous.is_empty():
						var distance := point.distance_to(previous[current.size()])
						if distance>maximum_step:
							maximum_step=distance;worst={"clip":clip,"frame":frame,"from":str(previous[current.size()]),"to":str(point)}
					current.append(point)
				previous=current
		check(maximum_radius<7.0,"Bounded skinned mesh: "+species)
		check(maximum_step<0.5,"No abrupt vertex jumps at 60 Hz including transitions: "+species)
		report[species]={"sampled_vertices":vertices.size(),"max_radius_native_units":maximum_radius,"max_frame_step_native_units":maximum_step,"clips":clips,"worst":worst,"scale_changes":scales}
		actor.node.free()
	# Every human model uses all tones independently; skin includes hands, Face
	# contains the original eyes/mouth. Clothes, hair, meshes and skins stay shared.
	for species in pop.HUMAN_SPECIES:
		var figures: Array[Dictionary]=[]
		for tone in pop.SKIN_TONES.size():figures.append(pop.figure(species,Vector3.ZERO,1.0,tone))
		for tone in figures.size():
			var skin_surfaces := 0;var face_surfaces := 0
			for part in figures[tone].visual.find_children("*","MeshInstance3D",true,false):
				for surface in part.mesh.get_surface_count():
					var original=part.mesh.surface_get_material(surface)
					var active=part.get_active_material(surface)
					if original.resource_name=="Skin":
						skin_surfaces+=1
						check(active!=original and active.albedo_color.is_equal_approx(pop.SKIN_TONES[tone]),"Independent skin tone: "+species)
						check(original.albedo_color.r<0.2,"Original vendor skin material unchanged")
					elif original.resource_name=="Face":
						face_surfaces+=1;check(active.albedo_color.is_equal_approx(Color("29201e")),"Readable face: "+species)
					else:check(active==original,"Clothing/hair not recolored: "+species)
			check(skin_surfaces>0 and face_surfaces>0,"Named skin/face surfaces: "+species)
		for actor in figures:actor.node.free()
	var result := {"pass":failures.is_empty(),"failures":failures,"animation_samples":report,"skin_variants_checked":35}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			var file := FileAccess.open(arg.trim_prefix("--output="),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "))
	print(JSON.stringify(result));pop.free();await process_frame;quit(0 if failures.is_empty() else 1)
