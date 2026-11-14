# SPDX-License-Identifier: GPL-3.0-or-later
class_name TrainerCharacterMotor
extends Node
## Optional third-person simulation. Caller owns input, camera, identity and spawn.
## Call step once from the CharacterBody3D's _physics_process. +Y up, metres.
@export var walk_speed := 1.5
@export var run_speed := 4.4
@export var sprint_speed := 6.2
@export var crouch_speed := 1.05
@export var acceleration := 24.0
@export var braking := 32.0
@export var gravity := 20.0
@export var jump_speed := 6.0
@export var standing_height := 1.8
@export var crouch_height := 1.4
@export var radius := 0.27
var body: CharacterBody3D
var collider: CollisionShape3D
var crouched := false
var actual_speed := 0.0
var gait := "idle"
var coyote := 0.0
var jump_buffer := 0.0
var landed := false

func bind(character: CharacterBody3D) -> void:
	body=character
	collider=CollisionShape3D.new()
	var capsule := CapsuleShape3D.new();capsule.radius=radius;capsule.height=standing_height
	collider.shape=capsule;collider.position.y=standing_height*0.5
	body.add_child(collider)
	body.floor_snap_length=0.32;body.floor_constant_speed=true
	body.floor_stop_on_slope=true;body.floor_max_angle=deg_to_rad(46)

func can_stand() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := CapsuleShape3D.new();shape.radius=radius;shape.height=standing_height-0.04
	query.shape=shape;query.transform=body.global_transform
	query.transform.origin+=Vector3.UP*(standing_height*0.5+0.02)
	query.collision_mask=body.collision_mask;query.exclude=[body.get_rid()]
	return body.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func reset() -> void:
	body.velocity=Vector3.ZERO;actual_speed=0.0;gait="idle";coyote=0.0;jump_buffer=0.0

func step(delta: float, direction: Vector3, wants_sprint := false, wants_crouch := false, jump_pressed := false, enabled := true, wants_walk := false) -> void:
	if not is_instance_valid(body) or delta<=0:return
	var on_floor := body.is_on_floor()
	landed=false
	if not enabled:
		direction=Vector3.ZERO;jump_pressed=false;wants_sprint=false
		jump_buffer=0.0
	if wants_crouch:crouched=true
	elif crouched and can_stand():crouched=false
	var height := crouch_height if crouched else standing_height
	(collider.shape as CapsuleShape3D).height=height;collider.position.y=height*0.5
	direction.y=0;direction=direction.limit_length()
	gait="crouch" if crouched else "sprint" if wants_sprint else "walk" if wants_walk or direction.length()*run_speed<=walk_speed else "run"
	var speed := crouch_speed if crouched else sprint_speed if wants_sprint else walk_speed if wants_walk else run_speed
	# Gentle stick travel is a walk; full stick is the usual game jog.
	var target := direction*speed
	var horizontal := Vector2(body.velocity.x,body.velocity.z)
	horizontal=horizontal.move_toward(Vector2(target.x,target.z),(braking if direction.is_zero_approx() else acceleration)*delta)
	body.velocity.x=horizontal.x;body.velocity.z=horizontal.y
	coyote=0.10 if on_floor else maxf(0,coyote-delta)
	jump_buffer=0.12 if jump_pressed and enabled else maxf(0,jump_buffer-delta)
	if jump_buffer>0 and coyote>0 and not crouched:
		body.velocity.y=jump_speed;coyote=0;jump_buffer=0
	elif on_floor:body.velocity.y=-0.1
	else:body.velocity.y-=gravity*delta
	body.move_and_slide()
	landed=not on_floor and body.is_on_floor()
	# Collision-resolved velocity prevents running in place against a wall.
	var real := body.get_real_velocity()-body.get_platform_velocity()
	actual_speed=Vector2(real.x,real.z).length()
	if actual_speed<0.08:gait="idle"
