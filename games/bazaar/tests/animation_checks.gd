# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Presenter=preload("res://addons/traineros/avatar_presenter.gd")
const Motion=preload("res://scripts/locomotion.gd")
var failures: Array[String]=[]
func check(ok: bool, message: String) -> void:
	if not ok and not failures.has(message):failures.append(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var descriptor: Dictionary={};var output := "user://animation-checks.json";var legacy := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--descriptor="):descriptor=JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--descriptor=")))
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg=="--legacy":legacy=true
	if descriptor.is_empty():push_error("Synthetic descriptor required");quit(1);return
	var avatar=Presenter.from_descriptor(descriptor);root.add_child(avatar)
	var motion=(load("res://tests/legacy_locomotion.gd") if legacy else Motion).new();root.add_child(motion)
	check(motion.bind(avatar),"Bind SDK skeleton")
	if not motion.ready_to_animate:quit(1);return
	var sk: Skeleton3D=motion.target;var original: Array[Transform3D]=[]
	for i in sk.get_bone_count():original.append(sk.get_bone_rest(i))
	var results: Dictionary={}
	for state in [{"name":"Idle","speed":0.0},{"name":"Walk","speed":2.4},{"name":"Jog_Fwd","speed":4.8}]:
		var max_direction_error := 0.0;var min_hand_side := 100.0;var max_helper_error := 0.0
		# Settle transition, then sample several whole cycles at actual playback rate.
		for i in 90:motion.advance(1.0/60,state.speed,true)
		for frame in 360:
			motion.advance(1.0/60,state.speed,true);sk.force_update_all_bone_transforms()
			for i in sk.get_bone_count():
				check(sk.get_bone_rest(i).is_equal_approx(original[i]),"Bind transforms unchanged")
				check(sk.get_bone_pose_scale(i).is_equal_approx(original[i].basis.get_scale()),"Body scale unchanged")
				if sk.get_bone_name(i)!="pelvis":check(sk.get_bone_pose_position(i).is_equal_approx(original[i].origin),"Joint offsets unchanged")
				check(sk.get_bone_pose_rotation(i).is_finite(),"Finite joint rotations")
			var left: Vector3=sk.get_bone_global_pose(sk.find_bone("upper_arm.L")).origin
			var right: Vector3=sk.get_bone_global_pose(sk.find_bone("upper_arm.R")).origin
			var lateral := (left-right).normalized();var center := (left+right)*0.5
			for side in ["L","R"]:
				for part in ["upper_arm","forearm","hand"]:
					var id := sk.find_bone(part+"."+side)
					var from: int=motion.mapping[id]
					var expected: Vector3=motion.alignment*motion.source.get_bone_global_pose(from).basis.y.normalized()
					var actual := sk.get_bone_global_pose(id).basis.y.normalized()
					max_direction_error=maxf(max_direction_error,rad_to_deg(actual.angle_to(expected)))
				var hand := sk.get_bone_global_pose(sk.find_bone("hand."+side)).origin
				min_hand_side=minf(min_hand_side,(hand-center).dot(lateral)*(1 if side=="L" else -1))
				var upper := sk.find_bone("upper_arm."+side);var helper := sk.find_bone("shoulder_blend."+side)
				var upper_delta := original[upper].basis.get_rotation_quaternion().inverse()*sk.get_bone_pose_rotation(upper)
				var helper_delta := original[helper].basis.get_rotation_quaternion().inverse()*sk.get_bone_pose_rotation(helper)
				max_helper_error=maxf(max_helper_error,rad_to_deg(helper_delta.angle_to(Quaternion.IDENTITY.slerp(upper_delta,0.5))))
		check(max_direction_error<12.0,"Arm/hand motion follows donor direction: "+state.name)
		check(min_hand_side>0.025,"Wrists stay on their own side of torso: "+state.name)
		check(max_helper_error<0.1,"Shoulder helper uses SDK half rotation: "+state.name)
		results[state.name]={"max_arm_direction_error_degrees":max_direction_error,"minimum_wrist_lateral_metres":min_hand_side,"max_shoulder_helper_error_degrees":max_helper_error,"sampled_frames":360}
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file==null:push_error("Cannot write animation evidence");quit(1);return
	file.store_string(JSON.stringify({"legacy":legacy,"success":failures.is_empty(),"failures":failures,"clips":results},"  "));file.close()
	print("ANIMATION CHECKS: ","PASS" if failures.is_empty() else "FAIL", " ",results)
	for failure in failures:print("FAILED: ",failure)
	motion.queue_free();avatar.queue_free();for i in 3:await process_frame
	quit(0 if failures.is_empty() else 1)
