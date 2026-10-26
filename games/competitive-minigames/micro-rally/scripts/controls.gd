# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
var device = -1
var mouse_aim = false
var neutral_required = true

func _init() -> void:
	# Do not depend on engine/editor defaults for controller menu navigation.
	var bindings = {"ui_accept":JOY_BUTTON_A,"ui_cancel":JOY_BUTTON_B,"ui_up":JOY_BUTTON_DPAD_UP,"ui_down":JOY_BUTTON_DPAD_DOWN,"ui_left":JOY_BUTTON_DPAD_LEFT,"ui_right":JOY_BUTTON_DPAD_RIGHT}
	for action in bindings:
		var event = InputEventJoypadButton.new(); event.device=-1; event.button_index=bindings[action]
		if not InputMap.action_has_event(action,event): InputMap.action_add_event(action,event)
	for item in [["ui_left",JOY_AXIS_LEFT_X,-1.0],["ui_right",JOY_AXIS_LEFT_X,1.0],["ui_up",JOY_AXIS_LEFT_Y,-1.0],["ui_down",JOY_AXIS_LEFT_Y,1.0]]:
		var event = InputEventJoypadMotion.new(); event.device=-1; event.axis=item[1]; event.axis_value=item[2]
		if not InputMap.action_has_event(item[0],event): InputMap.action_add_event(item[0],event)

func detect() -> void:
	var devices = Input.get_connected_joypads()
	var next = -1 if devices.is_empty() else devices[0]
	if next!=device: neutral_required=true
	device=next

func read(car: Node3D, camera: Camera3D) -> void:
	detect()
	var steer = Vector2.ZERO; var aiming = Vector2.ZERO
	var shielding = false
	if device>=0:
		steer=Vector2(Input.get_joy_axis(device,JOY_AXIS_LEFT_X),Input.get_joy_axis(device,JOY_AXIS_LEFT_Y))
		aiming=Vector2(Input.get_joy_axis(device,JOY_AXIS_RIGHT_X),Input.get_joy_axis(device,JOY_AXIS_RIGHT_Y))
		car.throttle=maxf(0,Input.get_joy_axis(device,JOY_AXIS_TRIGGER_RIGHT)); car.brake=maxf(0,Input.get_joy_axis(device,JOY_AXIS_TRIGGER_LEFT))
		car.boosting=Input.is_joy_button_pressed(device,JOY_BUTTON_LEFT_SHOULDER)
		car.firing=Input.is_joy_button_pressed(device,JOY_BUTTON_RIGHT_SHOULDER)
		car.handbrake=Input.is_joy_button_pressed(device,JOY_BUTTON_A)
		shielding=Input.is_joy_button_pressed(device,JOY_BUTTON_X)
	else:
		steer=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		car.throttle=1.0 if Input.is_physical_key_pressed(KEY_UP) else 0.0
		car.brake=1.0 if Input.is_physical_key_pressed(KEY_DOWN) else 0.0
		car.boosting=Input.is_physical_key_pressed(KEY_SHIFT); car.handbrake=Input.is_physical_key_pressed(KEY_SPACE)
		car.firing=Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		shielding=Input.is_physical_key_pressed(KEY_E)
	if neutral_required:
		var released = steer.length()<0.18 and aiming.length()<0.22 and car.throttle<0.08 and car.brake<0.08 and not car.firing and not car.boosting and not car.handbrake and not shielding
		neutral(car)
		if released: neutral_required=false
		return
	if shielding: car.activate_shield()
	car.shield_pressed=shielding
	if steer.length()>0.18: car.desired=Vector3(steer.x,0,steer.y).normalized()
	else: car.desired=Vector3.ZERO
	if aiming.length()>0.22: car.aim=Vector3(aiming.x,0,aiming.y).normalized()
	elif device<0 and mouse_aim:
		var pos = camera.get_viewport().get_mouse_position()
		var origin = camera.project_ray_origin(pos); var direction = camera.project_ray_normal(pos)
		if absf(direction.y)>0.01:
			var target = origin+direction*((car.position.y-origin.y)/direction.y)
			car.aim=(target-car.position).normalized()

func neutral(car: Node3D) -> void:
	car.shield_pressed=false
	car.throttle=0; car.brake=0; car.boosting=false; car.firing=false; car.handbrake=false; car.desired=Vector3.ZERO
