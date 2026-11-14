# SPDX-License-Identifier: GPL-3.0-or-later
extends CharacterBody3D
const Client = preload("res://addons/traineros/avatar_client.gd")
const Locomotion = preload("res://addons/traineros/avatar_locomotion.gd")
const Motor = preload("res://addons/traineros/character_motor.gd")
var motor = Motor.new()
var crouch_toggle := false
var jump_requested := false
var touch_sprint := false
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
var pitch := -0.18
var field_of_view := 90.0
var camera_scale := 1.8
var camera_target_height := 1.53
var indoor := false
var spawn_point := Vector3(0,0.2,10)
var fall_height := -3.0
var world_radius := 0.0
var travel_time := 0.0
var moving := false

func _ready() -> void:
	name="Visitor";add_child(motor);motor.bind(self)
	add_child(anchor);anchor.add_child(fallback)
	anchor.scale=Vector3.ONE*1.8
	var anonymous := MeshInstance3D.new();var mesh := CapsuleMesh.new();mesh.radius=0.17;mesh.height=1.0
	anonymous.mesh=mesh;anonymous.position.y=0.5
	var color := StandardMaterial3D.new();color.albedo_color=Color("efc98a");color.roughness=0.9
	anonymous.material_override=color;fallback.add_child(anonymous)
	get_parent().add_child(rig);rig.add_child(arm);arm.add_child(camera)
	update_camera_size();arm.margin=0.16;arm.add_excluded_object(get_rid())
	var camera_shape := SphereShape3D.new();camera_shape.radius=0.15;arm.shape=camera_shape
	camera.keep_aspect=Camera3D.KEEP_HEIGHT;set_field_of_view(90);camera.near=0.07;camera.far=420;camera.current=true
	client.app_id="org.traineros.bazaar"
	client.appearance_changed.connect(appearance)
	client.unavailable.connect(clear_identity)
	add_child(client);identity_changed.emit("Guest · connecting to TrainerOS")
	client.connect_host()

func reconnect() -> void:
	clear_identity("reconnecting");client.connect_host()

func appearance(description: Dictionary) -> void:
	if is_instance_valid(visual) and visual.appearance_revision==description.get("revision",""):return
	var replacement = Presenter.from_descriptor(description)
	clear_identity("")
	if replacement==null:
		identity_changed.emit("Guest · character unavailable");return
	visual=replacement;anchor.add_child(visual);fallback.hide()
	locomotion=Locomotion.new();add_child(locomotion)
	if not locomotion.bind(visual):locomotion.queue_free();locomotion=null
	camera_scale=1.8*clampf(visual.eye_height/0.8,0.85,1.15);update_camera_size()
	identity_changed.emit("Your TrainerOS character")

func clear_identity(_reason: String) -> void:
	if is_instance_valid(locomotion):remove_child(locomotion);locomotion.queue_free()
	locomotion=null
	if is_instance_valid(visual):
		visual.clear_identity();anchor.remove_child(visual);visual.queue_free()
	visual=null;fallback.show();camera_scale=1.8;update_camera_size();identity_changed.emit("Guest · connect in Menu")

func set_controls(enabled: bool) -> void:
	input_enabled=enabled;touch_move=Vector2.ZERO
	if not enabled:motor.reset();jump_requested=false;touch_sprint=false

func set_field_of_view(horizontal_at_16_9: float) -> void:
	field_of_view=clampf(horizontal_at_16_9,75.0,105.0)
	camera.fov=rad_to_deg(2.0*atan(tan(deg_to_rad(field_of_view*0.5))*9.0/16.0))

func update_camera_size() -> void:
	camera_target_height=(0.58 if motor.crouched else 0.85)*camera_scale
	arm.spring_length=(2.4 if indoor else 3.0)*camera_scale

func enter_space(at: Vector3, heading: float) -> void:
	position=at;motor.reset();touch_move=Vector2.ZERO;jump_requested=false;yaw=heading
	anchor.rotation.y=heading+PI;indoor=at.x>180;update_camera_size()
	pitch=-0.12 if indoor else -0.18
	rig.global_position=global_position+Vector3(0,camera_target_height,0);rig.rotation.y=yaw;arm.rotation.x=pitch


func look(delta: Vector2) -> void:
	if not input_enabled:return
	yaw-=delta.x;pitch=clampf(pitch-delta.y,-1.05,0.35)

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_C:crouch_toggle=not crouch_toggle
		if event.physical_keycode==KEY_SPACE:jump_requested=true
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index==JOY_BUTTON_RIGHT_STICK:crouch_toggle=not crouch_toggle
		if event.button_index==JOY_BUTTON_X:jump_requested=true
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):look(event.screen_relative*0.004)

func _physics_process(delta: float) -> void:
	var axis := Vector2.ZERO
	var running := touch_sprint
	var walking := false
	if input_enabled:
		axis=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		var devices := Input.get_connected_joypads()
		if not devices.is_empty():
			var device: int=devices[0]
			var stick := Vector2(Input.get_joy_axis(device,JOY_AXIS_LEFT_X),Input.get_joy_axis(device,JOY_AXIS_LEFT_Y))
			axis+=Motor.stick_direction(stick)
			var right := Vector2(Input.get_joy_axis(device,JOY_AXIS_RIGHT_X),Input.get_joy_axis(device,JOY_AXIS_RIGHT_Y))
			if right.length()>0.2:look(right.normalized()*inverse_lerp(0.2,1.0,minf(right.length(),1.0))*delta*1.8)
			running=running or Input.is_joy_button_pressed(device,JOY_BUTTON_LEFT_SHOULDER) or Input.is_joy_button_pressed(device,JOY_BUTTON_LEFT_STICK)
		axis=(axis+touch_move).limit_length()
		running=running or Input.is_physical_key_pressed(KEY_SHIFT)
		walking=Input.is_physical_key_pressed(KEY_ALT)
		var arrow := Vector2(float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_UP)))
		look(arrow*delta*1.6)
	var direction := Vector3(axis.x,0,axis.y).rotated(Vector3.UP,yaw)
	motor.step(delta,direction,running,crouch_toggle or Input.is_physical_key_pressed(KEY_CTRL),jump_requested,input_enabled,walking)
	jump_requested=false
	if global_position.y < fall_height or (world_radius>0 and Vector2(position.x,position.z).length()>world_radius):enter_space(spawn_point,0)
	moving=motor.actual_speed>0.08
	if moving:
		var travel := get_real_velocity()
		anchor.rotation.y=lerp_angle(anchor.rotation.y,atan2(travel.x,travel.z),1.0-exp(-delta*20))
		travel_time+=delta*motor.actual_speed
	fallback.position.y=absf(sin(travel_time*5))*0.025 if moving else 0.0
	if is_instance_valid(locomotion):
		locomotion.advance(delta,motor.actual_speed,input_enabled,motor.crouched,is_on_floor(),motor.gait)
	update_camera_size()

	# Keep the collision probe centered on the body in X/Z. Only the height and
	# orbit angles ease, avoiding a lagging pivot on the far side of a thin wall.
	var target_y := global_position.y+camera_target_height
	rig.global_position=Vector3(global_position.x,lerpf(rig.global_position.y,target_y,1-exp(-delta*16)),global_position.z)
	rig.rotation.y=lerp_angle(rig.rotation.y,yaw,1-exp(-delta*20))
	arm.rotation.x=lerp_angle(arm.rotation.x,pitch,1-exp(-delta*20))
	anchor.visible=arm.get_hit_length()>0.35*camera_scale

func _exit_tree() -> void:
	if is_instance_valid(rig):rig.queue_free()
