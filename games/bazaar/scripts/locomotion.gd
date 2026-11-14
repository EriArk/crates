# SPDX-License-Identifier: GPL-3.0-or-later
extends Node
## Retarget CC0 locomotion onto the existing SDK skeleton, never its identity.
## World-space rest deltas account for different bone axes and body proportions.
const PACK = preload("res://assets/animations/UAL1_Standard.glb")
var donor: Node3D
var source: Skeleton3D
var target: Skeleton3D
var player: AnimationPlayer
var mapping: Dictionary = {}
var order: Array[int] = []
var rest: Dictionary = {}
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
	target=skeleton(presenter)
	if target==null:return false
	donor=PACK.instantiate();add_child(donor);donor.hide()
	source=skeleton(donor);player=donor.find_child("AnimationPlayer",true,false)
	if source==null or player==null:return false
	var pairs := {"pelvis":"pelvis","spine":"spine_01","chest":"spine_03","neck":"neck_01","head":"Head"}
	for side in ["L","R"]:
		var suffix: String="_"+side.to_lower()
		for part in {"clavicle":"clavicle","upper_arm":"upperarm","forearm":"lowerarm","hand":"hand","thigh":"thigh","shin":"calf","foot":"foot","toes":"ball","shoulder_blend":"upperarm"}:
			var source_part: String={"clavicle":"clavicle","upper_arm":"upperarm","forearm":"lowerarm","hand":"hand","thigh":"thigh","shin":"calf","foot":"foot","toes":"ball","shoulder_blend":"upperarm"}[part]
			pairs[part+"."+side]=source_part+suffix
	for name in pairs:
		var to := target.find_bone(name);var from := source.find_bone(pairs[name])
		if to>=0 and from>=0:mapping[to]=from
	if mapping.size()<21:return false
	var sleft := source.get_bone_global_rest(source.find_bone("thigh_l")).origin
	var sright := source.get_bone_global_rest(source.find_bone("thigh_r")).origin
	var tleft := target.get_bone_global_rest(target.find_bone("thigh.L")).origin
	var tright := target.get_bone_global_rest(target.find_bone("thigh.R")).origin
	var a := sleft-sright;var b := tleft-tright
	alignment=Quaternion(Vector3.UP,atan2(b.x,b.z)-atan2(a.x,a.z))
	height_ratio=absf(target.get_bone_global_rest(target.find_bone("head")).origin.y/source.get_bone_global_rest(source.find_bone("Head")).origin.y)
	for root in target.get_parentless_bones():visit(root)
	for bone in order:rest[bone]=target.get_bone_global_rest(bone).basis.get_rotation_quaternion()
	if presenter.animation_player!=null:presenter.animation_player.stop()
	target.reset_bone_poses()
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip in ["Idle","Walk","Jog_Fwd"]:
		if not player.has_animation(clip):return false
		player.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
	ready_to_animate=true
	return true

func visit(bone: int) -> void:
	order.append(bone)
	for child in target.get_bone_children(bone):visit(child)

func advance(delta: float, speed: float, enabled: bool) -> void:
	if not ready_to_animate or not is_instance_valid(target):return
	var clip := "Idle" if speed<0.1 or not enabled else "Jog_Fwd" if speed>3.2 else "Walk"
	if clip!=current:player.play(clip,0.20);current=clip
	player.speed_scale=1.0 if clip=="Idle" else clampf(speed/(4.8 if clip=="Jog_Fwd" else 2.4),0.65,1.35)
	player.advance(delta)
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
			local=parent_rotation.inverse()*change*rest[bone]
		local=target.get_bone_pose_rotation(bone).slerp(local,1.0-exp(-delta*24.0)).normalized()
		target.set_bone_pose_rotation(bone,local);globals[bone]=parent_rotation*local
	var hips := target.find_bone("pelvis");var source_hips := source.find_bone("pelvis")
	var bob := (source.get_bone_global_pose(source_hips).origin.y-source.get_bone_global_rest(source_hips).origin.y)*height_ratio
	var position := target.get_bone_rest(hips).origin
	# Local parent orientation may be reversed, so convert the vertical offset.
	var parent := target.get_bone_parent(hips)
	var parent_rotation: Quaternion=globals.get(parent,Quaternion.IDENTITY)
	position+=parent_rotation.inverse()*Vector3(0,clampf(bob,-0.10,0.10),0)
	target.set_bone_pose_position(hips,position)
