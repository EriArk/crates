# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
var device = -1
var mouse_aim = false
var neutral_required = true
var shift_up_held = false
var shift_down_held = false
var weapon_held=false

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
		steer=Vector2(Input.get_joy_axis(device,JOY_AXIS_LEFT_X),0)
		aiming=Vector2(Input.get_joy_axis(device,JOY_AXIS_RIGHT_X),Input.get_joy_axis(device,JOY_AXIS_RIGHT_Y))
		car.throttle=maxf(0,Input.get_joy_axis(device,JOY_AXIS_TRIGGER_RIGHT)); car.brake=maxf(0,Input.get_joy_axis(device,JOY_AXIS_TRIGGER_LEFT))
		car.boosting=Input.is_joy_button_pressed(device,JOY_BUTTON_LEFT_SHOULDER)
		car.firing=Input.is_joy_button_pressed(device,JOY_BUTTON_RIGHT_SHOULDER)
		car.handbrake=Input.is_joy_button_pressed(device,JOY_BUTTON_A)
		shielding=Input.is_joy_button_pressed(device,JOY_BUTTON_X)
	else:
		steer=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),0)
		car.throttle=1.0 if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W) else 0.0
		car.brake=1.0 if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S) else 0.0
		car.boosting=Input.is_physical_key_pressed(KEY_SHIFT); car.handbrake=Input.is_physical_key_pressed(KEY_SPACE)
		car.firing=Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and camera.get_viewport().gui_get_hovered_control()==null
		shielding=Input.is_physical_key_pressed(KEY_E)
	var shift_up=Input.is_joy_button_pressed(device,JOY_BUTTON_Y) if device>=0 else Input.is_physical_key_pressed(KEY_C)
	var shift_down=Input.is_joy_button_pressed(device,JOY_BUTTON_B) if device>=0 else Input.is_physical_key_pressed(KEY_Z)
	var weapon_button=(Input.is_joy_button_pressed(device,JOY_BUTTON_DPAD_LEFT) or Input.is_joy_button_pressed(device,JOY_BUTTON_DPAD_RIGHT)) if device>=0 else Input.is_physical_key_pressed(KEY_Q)
	if neutral_required:
		var released = steer.length()<0.18 and aiming.length()<0.22 and car.throttle<0.08 and car.brake<0.08 and not car.firing and not car.boosting and not car.handbrake and not shielding and not shift_up and not shift_down and not weapon_button
		shift_up_held=shift_up; shift_down_held=shift_down; weapon_held=weapon_button
		neutral(car)
		if released: neutral_required=false
		return
	if weapon_button and not weapon_held: car.weapon_selected=not car.weapon_selected and car.ammo>0
	weapon_held=weapon_button
	car.assist_level=car.get_parent().arena.assist_level if device>=0 else 0
	shift_buttons(car,shift_up,shift_down)
	if shielding: car.activate_shield()
	car.shield_pressed=shielding
	car.steer_input=steering_axis(steer.x)
	car.desired=Vector3.ZERO
	if aiming.length()>0.22: car.aim=Vector3(aiming.x,0,aiming.y).normalized()
	elif device<0 and mouse_aim:
		var pos = camera.get_viewport().get_mouse_position()
		var origin = camera.project_ray_origin(pos); var direction = camera.project_ray_normal(pos)
		if absf(direction.y)>0.01:
			var target = origin+direction*((car.position.y-origin.y)/direction.y)
			car.aim=(target-car.position).normalized()

func neutral(car: Node3D) -> void:
	car.shield_pressed=false; car.steer_input=0; car.shift_direction=0; car.transmission.pending=0
	car.throttle=0; car.brake=0; car.boosting=false; car.firing=false; car.handbrake=false; car.desired=Vector3.ZERO


func shift_buttons(car: Node3D, up: bool, down: bool) -> void:
	if up and not shift_up_held and not down: car.request_shift(1)
	elif down and not shift_down_held and not up: car.request_shift(-1)
	shift_up_held=up; shift_down_held=down

static func steering_axis(value: float) -> float:
	return signf(value)*clampf((absf(value)-0.18)/0.82,0,1)
