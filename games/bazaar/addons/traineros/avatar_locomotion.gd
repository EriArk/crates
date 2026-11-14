# SPDX-License-Identifier: GPL-3.0-or-later
class_name TrainerAvatarLocomotion
extends Node
## Retarget CC0 locomotion onto the existing SDK skeleton, never its identity.
## Match arm/hand reference silhouettes before transferring world-space motion.
## Keep the SDK bind pose, skin weights, body shape and joint lengths unchanged.
const PACK = preload("animations/UAL1_Standard.glb")
const LOOP_CLIPS := ["Idle", "Walk", "Jog_Fwd", "Sprint", "Crouch_Idle", "Crouch_Fwd", "Jump"]
var stride_speed: Dictionary = {}
var grounded := true
var sole_height := 0.0
var donor: Node3D
var source: Skeleton3D
var target: Skeleton3D
var player: AnimationPlayer
var mapping: Dictionary = {}
var order: Array[int] = []
var rest: Dictionary = {}
var reference: Dictionary = {}
var alignment := Quaternion.IDENTITY
var height_ratio := 1.0
var current := ""
var ready_to_animate := false

func skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:return node
	for child in node.get_children():
		var found := skeleton(child)
		if found!=null:return found
	return null

func bind(presenter: Node3D) -> bool:
	if presenter==null:return false
	target=skeleton(presenter)
	if target==null:return false
	donor=PACK.instantiate();add_child(donor);donor.hide()
	source=skeleton(donor);player=donor.find_child("AnimationPlayer",true,false)
	if source==null or player==null:return false
	var pairs := {"pelvis":"pelvis","spine":"spine_01","chest":"spine_03","neck":"neck_01","head":"Head"}
	var limbs := {"clavicle":"clavicle","upper_arm":"upperarm","forearm":"lowerarm","hand":"hand","thigh":"thigh","shin":"calf","foot":"foot","toes":"ball"}
	for side in ["L","R"]:
		for part in limbs:pairs[part+"."+side]=limbs[part]+"_"+side.to_lower()
	for name in pairs:
		var to := target.find_bone(name);var from := source.find_bone(pairs[name])
		if to<0 or from<0:return false
		mapping[to]=from
	# Fingers must follow the hand's calibrated reference, not remain frozen
	# in the SDK rest pose while the donor closes its palm.
	for side in ["L","R"]:
		for finger in ["thumb","index","middle","ring","pinky"]:
			for joint in range(1,4):
				var to := target.find_bone("%s.%02d.%s"%[finger,joint,side])
				var from := source.find_bone("%s_%02d_%s"%[finger,joint,side.to_lower()])
				if to>=0 and from>=0:mapping[to]=from
	var sleft := source.get_bone_global_rest(source.find_bone("thigh_l")).origin
	var sright := source.get_bone_global_rest(source.find_bone("thigh_r")).origin
	var tleft := target.get_bone_global_rest(target.find_bone("thigh.L")).origin
	var tright := target.get_bone_global_rest(target.find_bone("thigh.R")).origin
	var a := sleft-sright;var b := tleft-tright
	alignment=Quaternion(Vector3.UP,atan2(b.x,b.z)-atan2(a.x,a.z))
	height_ratio=absf(target.get_bone_global_rest(target.find_bone("pelvis")).origin.y/source.get_bone_global_rest(source.find_bone("pelvis")).origin.y)
	for root in target.get_parentless_bones():visit(root)
	for bone in order:
		rest[bone]=target.get_bone_global_rest(bone).basis.get_rotation_quaternion()
		reference[bone]=rest[bone]
		if mapping.has(bone):
			var name: String=target.get_bone_name(bone)
			if name.begins_with("upper_arm.") or name.begins_with("forearm.") or name.begins_with("hand.") or name.get_slice(".",0) in ["thumb","index","middle","ring","pinky"]:
				# SDK arms rest down; UAL is a T-pose. Match their reference
				# silhouettes before applying motion, without editing bind/skin.
				var from: Vector3=target.get_bone_global_rest(bone).basis.y.normalized()
				var to: Vector3=alignment*source.get_bone_global_rest(mapping[bone]).basis.y.normalized()
				reference[bone]=Quaternion(from,to)*rest[bone]
	if presenter.animation_player!=null:presenter.animation_player.stop()
	target.reset_bone_poses()
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip in LOOP_CLIPS:
		if not player.has_animation(clip):return false
		player.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
	sole_height=minf(target.get_bone_global_rest(target.find_bone("foot.L")).origin.y,target.get_bone_global_rest(target.find_bone("toes.L")).origin.y)
	ready_to_animate=true
	_calibrate_stride()
	current=""
	return true

func visit(bone: int) -> void:
	order.append(bone)
	for child in target.get_bone_children(bone):visit(child)

## State comes from the game's motor/simulation, never global input or a profile.
## speed is actual ground travel in metres/sec, after collision, not requested input.
func advance(delta: float, speed: float, enabled: bool, crouched := false, on_ground := true, gait := "") -> void:
	if not ready_to_animate or not is_instance_valid(target):return
	grounded=on_ground
	var clip := "Idle"
	if not on_ground:clip="Jump"
	elif crouched:clip="Crouch_Fwd" if speed>0.08 and enabled else "Crouch_Idle"
	elif speed>0.08 and enabled:
		clip="Sprint" if gait=="sprint" else "Jog_Fwd" if gait=="run" or (gait.is_empty() and speed>3.2) else "Walk"
	if clip!=current:player.play(clip,0.0 if current.is_empty() else 0.12);current=clip
	# The stride is measured on this retargeted skeleton. Uniform scene scaling
	# changes stride length, not the shared rig or the user's saved appearance.
	var scale_factor := target.global_basis.get_scale().y
	player.speed_scale=speed/maxf(0.01,float(stride_speed[clip])*scale_factor) if stride_speed.has(clip) else 1.0
	player.advance(delta)
	apply_pose(delta)

func _calibrate_stride() -> void:
	# In-place clips: measure the backwards foot sweep during the low stance
	# phase. The upper stance plateau excludes near-zero lift/plant frames,
	# especially in running clips. Do this once per binding, never per frame.
	for clip in ["Walk","Jog_Fwd","Sprint","Crouch_Fwd"]:
		player.play(clip,0)
		var duration := player.get_animation(clip).length
		var tracks: Array = [[],[]]
		for frame in 61:
			player.seek(duration*frame/60.0,true);player.advance(0);apply_pose(1.0)
			target.force_update_all_bone_transforms()
			for side in 2:tracks[side].append(target.get_bone_global_pose(target.find_bone("foot."+["L","R"][side])).origin)
		var rates: Array[float]=[]
		for points in tracks:
			var low := INF;var high := -INF
			for p in points:low=minf(low,p.y);high=maxf(high,p.y)
			for i in 60:
				var rate: float=(points[i].z-points[i+1].z)/(duration/60.0)
				if rate>0.02 and points[i].y<low+(high-low)*0.45:rates.append(rate)
		if not rates.is_empty():
			rates.sort();stride_speed[clip]=rates[mini(rates.size()-1,int(rates.size()*0.8))]
		else:stride_speed[clip]=1.0
	player.stop();target.reset_bone_poses()

func apply_pose(delta: float) -> void:
	source.force_update_all_bone_transforms()
	var globals: Dictionary = {}
	for bone in order:
		var parent := target.get_bone_parent(bone)
		var parent_rotation: Quaternion=globals.get(parent,Quaternion.IDENTITY)
		var local := target.get_bone_rest(bone).basis.get_rotation_quaternion()
		if mapping.has(bone):
			var from: int=mapping[bone]
			var src_rest := source.get_bone_global_rest(from).basis.get_rotation_quaternion()
			var src_pose := source.get_bone_global_pose(from).basis.get_rotation_quaternion()
			var change := alignment*src_pose*src_rest.inverse()*alignment.inverse()
			local=parent_rotation.inverse()*change*reference[bone]
		local=local.normalized() # AnimationPlayer already blends; a second lag causes skating.
		target.set_bone_pose_rotation(bone,local);globals[bone]=parent_rotation*local
	# SDK shoulder cap is a sibling helper, not another upper-arm joint.
	# Native SDK clips give it half the upper arm's LOCAL rest-relative rotation.
	for side in ["L","R"]:
		var upper := target.find_bone("upper_arm."+side)
		var helper := target.find_bone("shoulder_blend."+side)
		if helper>=0:
			var upper_rest := target.get_bone_rest(upper).basis.get_rotation_quaternion()
			var helper_rest := target.get_bone_rest(helper).basis.get_rotation_quaternion()
			var delta_rotation := upper_rest.inverse()*target.get_bone_pose_rotation(upper)
			target.set_bone_pose_rotation(helper,helper_rest*Quaternion.IDENTITY.slerp(delta_rotation,0.5))
	var hips := target.find_bone("pelvis");var source_hips := source.find_bone("pelvis")
	var bob := (source.get_bone_global_pose(source_hips).origin.y-source.get_bone_global_rest(source_hips).origin.y)*height_ratio
	var position := target.get_bone_rest(hips).origin
	# Local parent orientation may be reversed, so convert the vertical offset.
	var parent := target.get_bone_parent(hips)
	var parent_rotation: Quaternion=globals.get(parent,Quaternion.IDENTITY)
	position+=parent_rotation.inverse()*Vector3(0,bob,0)
	target.set_bone_pose_position(hips,position)

	# Preserve anatomical offsets while lowering the pelvis with a crouch. The
	# previous +/-10 cm clamp kept bent legs suspended above the ground.
	if grounded:
		target.force_update_all_bone_transforms()
		var low := INF
		for name in ["foot.L","foot.R","toes.L","toes.R"]:
			low=minf(low,target.get_bone_global_pose(target.find_bone(name)).origin.y)
		position+=parent_rotation.inverse()*Vector3(0,sole_height-low,0)
		target.set_bone_pose_position(hips,position)
