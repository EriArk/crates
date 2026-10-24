# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
## Game-owned putting pose for trainer-humanoid-54-v1. No avatar mesh is bundled.
## Both hands and the club follow the same authored pendulum, including contact.
const CONTACT := 0.55
const DURATION := 1.25
const CLUB = preload("res://assets/kenney/golf/club-green.glb")
const Size = preload("res://scripts/dimensions.gd")
var skeleton: Skeleton3D
var club: Node3D
var clock := -1.0
var rest: Dictionary = {}

func bind(presenter: Node3D) -> bool:
	var found := presenter.find_children("*","Skeleton3D",true,false)
	if found.is_empty(): return false
	skeleton=found[0]
	for side in ["L","R"]:
		for part in ["upper_arm.","forearm.","hand.","shoulder_blend."]:
			var bone := skeleton.find_bone(part+side)
			if bone<0: return false
	for i in skeleton.get_bone_count(): rest[i]=skeleton.get_bone_pose_rotation(i)
	if presenter.animation_player!=null: presenter.animation_player.stop()
	club=CLUB.instantiate()
	add_child(club)
	seek(-1.0)
	return true

func strike() -> void:
	clock=0.0
	seek(clock)

func seek(time: float) -> void:
	if not is_instance_valid(skeleton): return
	clock=time
	# Address, compact backswing, contact, follow-through, then address again.
	var travel := 0.0
	if time>=0 and time<0.35: travel=lerpf(0.0,0.12,smoothstep(0,0.35,time))
	elif time<CONTACT and time>=0.35: travel=lerpf(0.12,0.0,smoothstep(0.35,CONTACT,time))
	elif time<0.82 and time>=CONTACT: travel=lerpf(0.0,-0.16,smoothstep(CONTACT,0.82,time))
	elif time<DURATION and time>=0.82: travel=lerpf(-0.16,0.0,smoothstep(0.82,DURATION,time))
	# Anchor coordinates: body faces +X; its left side is -Z.
	var grip := Vector3(0.18,0.49,travel*0.38)
	var head := Vector3(Size.STANCE,0.012+absf(travel)*0.2,Size.BALL+0.02+travel)
	var shaft := (grip-head).normalized()
	# Kenney club runs along Y, from -.769 at the sole to +.282 at the grip.
	var length := grip.distance_to(head)
	club.basis=Basis(Quaternion(Vector3.UP,shaft))*Basis(Vector3.UP,PI/2)
	club.scale=Vector3.ONE*(length/1.05)
	club.position=head+shaft*(0.769*length/1.05)
	for side in ["L","R"]:
		var sign_side := 1.0 if side=="L" else -1.0
		# Adjacent hands on the grip; wrists sit just outside it, not through it.
		var hand := grip+shaft*(0.018*sign_side)+Vector3(-0.025,0,-sign_side*0.025)
		var elbow := Vector3(0.08,0.53,-sign_side*0.16)
		_pose_arm(side,skeleton.to_local(to_global(hand)),skeleton.to_local(to_global(elbow)))

func _aim(bone: int, child: int, target: Vector3) -> void:
	var pose := skeleton.get_bone_global_pose(bone)
	var direction := skeleton.get_bone_global_pose(child).origin-pose.origin
	var delta := Quaternion(direction.normalized(),(target-pose.origin).normalized())
	var desired := Basis(delta)*pose.basis
	var parent := skeleton.get_bone_parent(bone)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent>=0 else Basis.IDENTITY
	skeleton.set_bone_pose_rotation(bone,(parent_basis.inverse()*desired).orthonormalized().get_rotation_quaternion())

func _pose_arm(side: String, target: Vector3, elbow_target: Vector3) -> void:
	var upper := skeleton.find_bone("upper_arm."+side)
	var fore := skeleton.find_bone("forearm."+side)
	var hand := skeleton.find_bone("hand."+side)
	for b in [upper,fore,hand]: skeleton.set_bone_pose_rotation(b,rest[b])
	var shoulder := skeleton.get_bone_global_pose(upper).origin
	var elbow := skeleton.get_bone_global_pose(fore).origin
	var wrist := skeleton.get_bone_global_pose(hand).origin
	var a := shoulder.distance_to(elbow)
	var b := elbow.distance_to(wrist)
	var distance := clampf(shoulder.distance_to(target),absf(a-b)+0.001,a+b-0.001)
	var axis := (target-shoulder).normalized()
	# Elbows remain outside the torso with a stable, softly bent two-bone chain.
	# Convert the pole with the same anchor/skeleton transform as the grip.
	# Raw skeleton X has the opposite handedness on this imported bind pose.
	var pole := elbow_target-shoulder
	pole=(pole-axis*pole.dot(axis)).normalized()
	var along := (a*a-b*b+distance*distance)/(2*distance)
	var bend := sqrt(maxf(a*a-along*along,0))
	_aim(upper,fore,shoulder+axis*along+pole*bend)
	_aim(fore,hand,target)
	# The blend shoulder shares half the upper-arm change to preserve the armpit.
	var blend := skeleton.find_bone("shoulder_blend."+side)
	skeleton.set_bone_pose_rotation(blend,rest[blend].slerp(skeleton.get_bone_pose_rotation(upper),0.5))
	for finger in ["index","middle","ring","pinky"]:
		for segment in ["01","02","03"]:
			var bone := skeleton.find_bone(finger+"."+segment+"."+side)
			if bone>=0:
				skeleton.set_bone_pose_rotation(bone,rest[bone]*Quaternion(Vector3.RIGHT,0.75))
