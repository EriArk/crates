# SPDX-License-Identifier: GPL-3.0-or-later
extends CharacterBody3D
const Client = preload("res://addons/traineros/avatar_client.gd")
const Locomotion = preload("res://scripts/locomotion.gd")
var locomotion: Node
const Presenter = preload("res://addons/traineros/avatar_presenter.gd")
signal identity_changed(message: String)
var client = Client.new()
var visual: Node3D
var anchor := Node3D.new()
var fallback := Node3D.new()
var rig := Node3D.new()
var arm := SpringArm3D.new()
var camera := Camera3D.new()
var input_enabled := true
var touch_move := Vector2.ZERO
var yaw := 0.0
var pitch := -0.42
var travel_time := 0.0
var moving := false

func _ready() -> void:
	name="Visitor";floor_snap_length=0.18
	var shape := CollisionShape3D.new();var capsule := CapsuleShape3D.new();capsule.radius=0.18;capsule.height=0.95
	shape.shape=capsule;shape.position.y=0.48;add_child(shape);add_child(anchor);anchor.add_child(fallback)
	var anonymous := MeshInstance3D.new();var mesh := CapsuleMesh.new();mesh.radius=0.17;mesh.height=0.85
	anonymous.mesh=mesh;anonymous.position.y=0.43
	var color := StandardMaterial3D.new();color.albedo_color=Color("efc98a");color.roughness=0.9
	anonymous.material_override=color;fallback.add_child(anonymous)
	get_parent().add_child(rig);rig.add_child(arm);arm.add_child(camera)
	arm.spring_length=4.8;arm.margin=0.16;arm.add_excluded_object(get_rid())
	var camera_shape := SphereShape3D.new();camera_shape.radius=0.15;arm.shape=camera_shape
	camera.fov=62;camera.near=0.07;camera.far=420;camera.current=true
	client.app_id="org.traineros.bazaar"
	client.appearance_changed.connect(appearance)
	client.unavailable.connect(clear_identity)
	add_child(client);identity_changed.emit("Guest appearance · connecting to TrainerOS")
	client.connect_host()

func reconnect() -> void:
	clear_identity("reconnecting");client.connect_host()

func appearance(description: Dictionary) -> void:
	if is_instance_valid(visual) and visual.appearance_revision==description.get("revision",""):return
	var replacement = Presenter.from_descriptor(description)
	clear_identity("")
	if replacement==null:
		identity_changed.emit("Guest appearance · shared avatar unavailable");return
	visual=replacement;anchor.add_child(visual);fallback.hide()
	locomotion=Locomotion.new();add_child(locomotion)
	if not locomotion.bind(visual):locomotion.queue_free();locomotion=null
	identity_changed.emit("Your TrainerOS character")

func clear_identity(_reason: String) -> void:
	if is_instance_valid(locomotion):remove_child(locomotion);locomotion.queue_free()
	locomotion=null
	if is_instance_valid(visual):
		visual.clear_identity();anchor.remove_child(visual);visual.queue_free()
	visual=null;fallback.show();identity_changed.emit("Guest appearance · connect through the pause menu")

func set_controls(enabled: bool) -> void:
	input_enabled=enabled;touch_move=Vector2.ZERO
	if not enabled:velocity=Vector3.ZERO

func look(delta: Vector2) -> void:
	if not input_enabled:return
	yaw-=delta.x;pitch=clampf(pitch-delta.y,-1.05,-0.08)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):look(event.relative*0.004)

func _physics_process(delta: float) -> void:
	var axis := Vector2.ZERO
	var running := false
	if input_enabled:
		axis=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		var devices := Input.get_connected_joypads()
		if not devices.is_empty():
			var device: int=devices[0]
			var stick := Vector2(Input.get_joy_axis(device,JOY_AXIS_LEFT_X),Input.get_joy_axis(device,JOY_AXIS_LEFT_Y))
			if stick.length()>0.18:axis+=stick.limit_length()*inverse_lerp(0.18,1.0,stick.length())
			var right := Vector2(Input.get_joy_axis(device,JOY_AXIS_RIGHT_X),Input.get_joy_axis(device,JOY_AXIS_RIGHT_Y))
			if right.length()>0.2:look(right*delta*1.8)
			running=Input.is_joy_button_pressed(device,JOY_BUTTON_LEFT_SHOULDER)
		axis=(axis+touch_move).limit_length()
		running=running or Input.is_physical_key_pressed(KEY_SHIFT)
		var arrow := Vector2(float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_UP)))
		look(arrow*delta*1.6)
	var direction := Vector3(axis.x,0,axis.y).rotated(Vector3.UP,yaw)
	var speed := 5.5 if running else 2.8
	velocity.x=move_toward(velocity.x,direction.x*speed,delta*18)
	velocity.z=move_toward(velocity.z,direction.z*speed,delta*18)
	velocity.y=-0.1 if is_on_floor() else velocity.y-14*delta
	move_and_slide()
	if global_position.y < -3:global_position=Vector3(0,0.2,10);velocity=Vector3.ZERO
	moving=Vector2(velocity.x,velocity.z).length()>0.1
	if moving:
		anchor.rotation.y=lerp_angle(anchor.rotation.y,atan2(velocity.x,velocity.z),1.0-exp(-delta*14))
		travel_time+=delta*(1.4 if running else 1.0)
	fallback.position.y=absf(sin(travel_time*10))*0.035 if moving else 0.0
	if is_instance_valid(locomotion):
		locomotion.advance(delta,Vector2(velocity.x,velocity.z).length(),input_enabled)

	rig.global_position=global_position+Vector3(0,0.85,0);rig.rotation.y=yaw;arm.rotation.x=pitch

func _exit_tree() -> void:
	if is_instance_valid(rig):rig.queue_free()
