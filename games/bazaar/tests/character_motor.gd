# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Motor=preload("res://addons/traineros/character_motor.gd")
var failures: Array[String]=[]
var body := CharacterBody3D.new()
var motor=Motor.new()
var direction := Vector3.ZERO
var sprint := false
var crouch := false
var jump := false
var enabled := true
var walk := false
func check(ok: bool, message: String) -> void:
	if not ok:failures.append(message)
func solid(at: Vector3, size: Vector3) -> StaticBody3D:
	var block := StaticBody3D.new();root.add_child(block);block.position=at
	var shape := CollisionShape3D.new();var box := BoxShape3D.new();box.size=size
	shape.shape=box;block.add_child(shape);return block
func frames(n: int) -> void:
	for i in n:await physics_frame
func _initialize() -> void:call_deferred("run")
func _physics_process(delta: float) -> bool:
	if is_instance_valid(motor.body):motor.step(delta,direction,sprint,crouch,jump,enabled,walk);jump=false
	return false
func run() -> void:
	solid(Vector3(0,-0.5,0),Vector3(100,1,100));root.add_child(body);body.add_child(motor);motor.bind(body)
	body.position=Vector3(0,0.1,0);await frames(30)
	check(body.is_on_floor(),"Settles on floor")
	direction=Vector3.FORWARD;await frames(45)
	check(absf(motor.actual_speed-motor.run_speed)<0.03,"Default full input runs at real collision-resolved speed")
	walk=true;await frames(30);check(absf(motor.actual_speed-motor.walk_speed)<0.03,"Explicit walking")
	walk=false;direction=Vector3.FORWARD*0.30;await frames(30)
	check(absf(motor.actual_speed-motor.run_speed*0.30)<0.03 and motor.gait=="walk","Light analog walk retains proportional speed")
	direction=Vector3.FORWARD*0.40;await frames(30)
	check(absf(motor.actual_speed-motor.run_speed*0.40)<0.03,"Analog gait change does not jump requested speed")
	direction=Vector3.FORWARD;sprint=true;await frames(30);check(absf(motor.actual_speed-motor.sprint_speed)<0.03,"Sprint")
	sprint=false;direction=Vector3.ZERO;await frames(30);check(motor.actual_speed<0.01,"Brakes without drifting")
	crouch=true;await frames(3);check(motor.crouched and is_equal_approx(motor.collider.shape.height,motor.crouch_height),"Crouch changes collision height")
	var ceiling := solid(body.position+Vector3(0,1.5,0),Vector3(3,0.1,3));await frames(3)
	crouch=false;await frames(5);check(motor.crouched,"Cannot stand through a low ceiling")
	ceiling.queue_free();await frames(5);check(not motor.crouched,"Stands after clearing ceiling")
	var start_y := body.position.y;jump=true;await frames(12)
	check(body.position.y>start_y+0.4 and not body.is_on_floor(),"Jump leaves ground")
	await frames(90);check(body.is_on_floor() and absf(body.position.y-start_y)<0.03,"Lands on the same floor")
	var wall := solid(body.position+Vector3(0,1,-1),Vector3(3,2,0.2));direction=Vector3.FORWARD;await frames(60)
	check(motor.actual_speed<0.01,"Blocked body does not feed moving animation")
	wall.queue_free();direction=Vector3.ZERO;await frames(5)
	enabled=false;jump=true;direction=Vector3.FORWARD;await frames(20)
	check(motor.actual_speed<0.01 and body.is_on_floor(),"Disabled control prevents movement and jump")
	print(JSON.stringify({"success":failures.is_empty(),"failures":failures,"checks":14}))
	quit(0 if failures.is_empty() else 1)
