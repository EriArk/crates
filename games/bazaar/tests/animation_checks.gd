# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Presenter=preload("res://addons/traineros/avatar_presenter.gd")
const Motion=preload("res://addons/traineros/avatar_locomotion.gd")
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
	var avatar=Presenter.from_descriptor(descriptor);root.add_child(avatar);avatar.scale=Vector3.ONE*1.8
	var motion=(load("res://tests/legacy_locomotion.gd") if legacy else Motion).new();root.add_child(motion)
	check(motion.bind(avatar),"Bind SDK skeleton")
	if not motion.ready_to_animate:quit(1);return
	var sk: Skeleton3D=motion.target;var original: Array[Transform3D]=[]
	for i in sk.get_bone_count():original.append(sk.get_bone_rest(i))
	var results: Dictionary={}
	var standing_hips := 0.0
	for state in [{"name":"Idle","speed":0.0},{"name":"Walk","speed":1.5},{"name":"Jog_Fwd","speed":4.4,"gait":"run"},{"name":"Sprint","speed":6.2,"gait":"sprint"},{"name":"Crouch_Idle","speed":0.0,"crouch":true},{"name":"Crouch_Fwd","speed":1.05,"crouch":true},{"name":"Jump","speed":0.0,"floor":false}]:
		var min_hips := INF;var max_hips := -INF;var max_floor_error := 0.0
		var max_direction_error := 0.0;var min_hand_side := 100.0;var max_helper_error := 0.0
		# Settle transition, then sample several whole cycles at actual playback rate.
		for i in 90:motion.advance(1.0/60,state.speed,true,state.get("crouch",false),state.get("floor",true),state.get("gait",""))
		for frame in 360:
			motion.advance(1.0/60,state.speed,true,state.get("crouch",false),state.get("floor",true),state.get("gait",""));sk.force_update_all_bone_transforms()
			var hips := sk.get_bone_global_pose(sk.find_bone("pelvis")).origin.y
			min_hips=minf(min_hips,hips);max_hips=maxf(max_hips,hips)
			var low := INF
			for foot in ["foot.L","foot.R","toes.L","toes.R"]:low=minf(low,sk.get_bone_global_pose(sk.find_bone(foot)).origin.y)
			max_floor_error=maxf(max_floor_error,absf(low-motion.sole_height))
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
		if state.name=="Idle":standing_hips=min_hips
		if state.get("crouch",false):check(max_hips<standing_hips-0.05,"Crouch lowers pelvis with knees, not floating legs: "+state.name)
		if state.get("floor",true):check(max_floor_error<0.001,"A support foot remains grounded: "+state.name)
		check(motion.current==state.name,"Requested clip selected: "+state.name)
		check(max_direction_error<12.0,"Arm/hand motion follows donor direction: "+state.name)
		check(min_hand_side>0.025,"Wrists stay on their own side of torso: "+state.name)
		check(max_helper_error<0.1,"Shoulder helper uses SDK half rotation: "+state.name)
		results[state.name]={"max_arm_direction_error_degrees":max_direction_error,"minimum_wrist_lateral_metres":min_hand_side,"max_shoulder_helper_error_degrees":max_helper_error,"sampled_frames":360,"pelvis_height_range":[min_hips,max_hips],"max_support_foot_error":max_floor_error,"playback_rate":motion.player.speed_scale}
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file==null:push_error("Cannot write animation evidence");quit(1);return
	file.store_string(JSON.stringify({"legacy":legacy,"success":failures.is_empty(),"failures":failures,"clips":results},"  "));file.close()
	print("ANIMATION CHECKS: ","PASS" if failures.is_empty() else "FAIL", " ",results)
	for failure in failures:print("FAILED: ",failure)
	motion.queue_free();avatar.queue_free();for i in 3:await process_frame
	quit(0 if failures.is_empty() else 1)
