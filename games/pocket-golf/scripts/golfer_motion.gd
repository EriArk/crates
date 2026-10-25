# SPDX-License-Identifier: GPL-3.0-or-later
extends Node
## Golf presentation on the SDK rig: planted feet and three authored cup reactions.
## No appearance data, copied model or gameplay state belongs here.
const CELEBRATION_TIME := 2.8
const TITLES := ["Fist pump", "Little victory hop", "Happy shuffle"]
signal foot_landed(side: String)
var stroke: Node3D
var anchor: Node3D
var visual: Node3D
var skeleton: Skeleton3D
var ground: Callable
var foot_rest: Dictionary = {}
var feet: Dictionary = {}
var foot_rotations: Dictionary = {}
var base_positions: Dictionary = {}
var base_visual := Vector3.ZERO
var step_side := ""
var next_side := "L"
var step_time := 0.0
var step_duration := 0.19
var step_start := Vector3.ZERO
var step_end := Vector3.ZERO
var step_rotation := Quaternion.IDENTITY
var last_position := Vector3.ZERO
var initialized := false
var celebration := -1
var celebration_clock := -1.0

func bind(putter: Node3D, target: Node3D) -> bool:
	stroke=putter; anchor=putter.get_parent(); visual=target; skeleton=stroke.skeleton
	for side in ["L","R"]:
		for part in ["thigh.","shin.","foot.","toes."]:
			if skeleton.find_bone(part+side)<0: return false
	for i in skeleton.get_bone_count(): base_positions[i]=skeleton.get_bone_pose_position(i)
	base_visual=visual.position
	for side in ["L","R"]:
		var bone := skeleton.find_bone("foot."+side)
		foot_rest[side]=anchor.to_local(skeleton.to_global(skeleton.get_bone_global_pose(bone).origin))
	return true

func reset() -> void:
	if not is_instance_valid(skeleton): return
	for i in base_positions:
		skeleton.set_bone_pose_position(i,base_positions[i])
		skeleton.set_bone_pose_rotation(i,stroke.rest[i])
	visual.position=base_visual
	stroke.club.visible=true
	step_side=""; initialized=false; celebration=-1; celebration_clock=-1

func _target(side: String) -> Vector3:
	var target := anchor.to_global(foot_rest[side])
	if ground.is_valid(): target.y=ground.call(target)+foot_rest[side].y
	return target

func _foot_rotation(side: String) -> Quaternion:
	return (skeleton.global_basis*skeleton.get_bone_global_pose(skeleton.find_bone("foot."+side)).basis).orthonormalized().get_rotation_quaternion()

func turn(delta: float) -> void:
	if not is_instance_valid(skeleton) or celebration>=0: return
	# Reset leg rotations before deriving this frame's neutral foot orientation.
	for side in ["L","R"]:
		for part in ["thigh.","shin.","foot.","toes."]:
			var bone := skeleton.find_bone(part+side)
			skeleton.set_bone_pose_rotation(bone,stroke.rest[bone])
	if not initialized or last_position.distance_to(anchor.global_position)>0.35:
		for side in ["L","R"]:
			feet[side]=_target(side); foot_rotations[side]=_foot_rotation(side)
		initialized=true; step_side=""
	var speed := last_position.distance_to(anchor.global_position)/maxf(delta,0.001)
	last_position=anchor.global_position
	if step_side.is_empty():
		var other := "R" if next_side=="L" else "L"
		var candidate: String = next_side if feet[next_side].distance_to(_target(next_side))>0.018 else other
		if feet[candidate].distance_to(_target(candidate))>0.018:
			step_side=candidate; step_start=feet[candidate]; step_end=_target(candidate)
			step_rotation=_foot_rotation(candidate); step_time=0
			step_duration=clampf(0.19-speed*0.16,0.11,0.19)
	if not step_side.is_empty():
		step_time+=delta
		# The lifted foot tracks the new landing spot during a sustained turn.
		# The planted foot stays fixed until its own step starts.
		step_end=_target(step_side); step_rotation=_foot_rotation(step_side)
		var amount := clampf(step_time/step_duration,0,1)
		feet[step_side]=step_start.lerp(step_end,smoothstep(0,1,amount))+Vector3.UP*sin(amount*PI)*0.036
		foot_rotations[step_side]=foot_rotations[step_side].slerp(step_rotation,minf(delta*22,1))
		if amount>=1:
			foot_landed.emit(step_side)
			next_side="R" if step_side=="L" else "L"; step_side=""
	for side in ["L","R"]: _leg(side,feet[side],foot_rotations[side])

func _leg(side: String, world_target: Vector3, world_rotation: Quaternion) -> void:
	var upper := skeleton.find_bone("thigh."+side)
	var lower := skeleton.find_bone("shin."+side)
	var foot := skeleton.find_bone("foot."+side)
	var hip := skeleton.get_bone_global_pose(upper).origin
	var knee := skeleton.get_bone_global_pose(lower).origin
	var ankle := skeleton.get_bone_global_pose(foot).origin
	var target := skeleton.to_local(world_target)
	var a := hip.distance_to(knee); var b := knee.distance_to(ankle)
	var distance := clampf(hip.distance_to(target),absf(a-b)+0.001,a+b-0.0001)
	var axis := (target-hip).normalized()
	var pole := skeleton.global_basis.inverse()*(anchor.global_basis*Vector3.RIGHT)
	pole=(pole-axis*pole.dot(axis)).normalized()
	var along := (a*a-b*b+distance*distance)/(2*distance)
	stroke._aim(upper,lower,hip+axis*along+pole*sqrt(maxf(a*a-along*along,0)))
	stroke._aim(lower,foot,target)
	var parent := skeleton.get_bone_global_pose(lower).basis
	var desired := skeleton.global_basis.inverse()*Basis(world_rotation)
	skeleton.set_bone_pose_rotation(foot,(parent.inverse()*desired).orthonormalized().get_rotation_quaternion())

func celebrate(time: float, variant: int) -> void:
	if not is_instance_valid(skeleton): return
	reset()
	celebration=posmod(variant,3); celebration_clock=time
	stroke.club.visible=false
	var fade := smoothstep(0,0.30,time)*(1-smoothstep(2.30,CELEBRATION_TIME,time))
	var pulse := sin(clampf(time-0.3,0,1.7)*TAU*1.7)
	var left := Vector3(0.10,0.45,-0.19)
	var right := Vector3(0.10,0.45,0.19)
	if celebration==0:
		# Compact fist pump: right elbow stays outside the body, left hand relaxed.
		right=right.lerp(Vector3(0.20,0.79+0.035*pulse,0.22),fade)
		_rotate("chest",Vector3.UP,-0.10*fade)
	elif celebration==1:
		# Both hands up and a small, soft landing. Root motion is visual only.
		left=left.lerp(Vector3(0.10,0.87,-0.23),fade)
		right=right.lerp(Vector3(0.10,0.87,0.23),fade)
		var hop := sin(clampf((time-0.4)/0.65,0,1)*PI)*0.09
		visual.position.y=base_visual.y+hop
		_rotate("thigh.L",Vector3.RIGHT,-0.13*fade)
		_rotate("thigh.R",Vector3.RIGHT,-0.13*fade)
		_rotate("shin.L",Vector3.RIGHT,0.24*fade)
		_rotate("shin.R",Vector3.RIGHT,0.24*fade)
	else:
		# A short alternating heel-lift dance, with elbows comfortably bent.
		left=left.lerp(Vector3(0.20,0.64+0.045*pulse,-0.25),fade)
		right=right.lerp(Vector3(0.20,0.64-0.045*pulse,0.25),fade)
		_rotate("spine",Vector3.FORWARD,0.07*pulse*fade)
		for side in ["L","R"]:
			var lift := maxf(0,pulse*(1 if side=="L" else -1))*fade
			_rotate("thigh."+side,Vector3.RIGHT,-0.17*lift)
			_rotate("shin."+side,Vector3.RIGHT,0.38*lift)
	for side in ["L","R"]:
		var hand: Vector3 = left if side=="L" else right
		# Blend out of and back into the original two-handed address pose.
		hand=Vector3(0.16,0.49,-0.025 if side=="L" else 0.025).lerp(hand,fade)
		var elbow := Vector3(0.08,0.58,-0.25 if side=="L" else 0.25)
		stroke._pose_arm(side,skeleton.to_local(anchor.to_global(hand)),skeleton.to_local(anchor.to_global(elbow)))
	# Open fingers for the hop/dance; the fist pump retains the grip curl.
	if celebration!=0:
		for i in stroke.rest:
			if ".0" in skeleton.get_bone_name(i): skeleton.set_bone_pose_rotation(i,stroke.rest[i])

func _rotate(name: String, axis: Vector3, angle: float) -> void:
	var bone := skeleton.find_bone(name)
	if bone>=0: skeleton.set_bone_pose_rotation(bone,stroke.rest[bone]*Quaternion(axis,angle))
