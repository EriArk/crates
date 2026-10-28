# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
enum Mode { CLOSE, CLASSIC, WIDE, CHASE, HOOD }
const TITLES=["Overhead · close","Overhead · classic","Overhead · wide","Chase","Windshield"]
# Eye points at the windshield, measured against the four rendered Kenney bodies.
# The open race car uses its cockpit rim instead of a nonexistent windscreen.
const EYE_POINTS={"hatchback-sports":Vector3(0,0.70,-0.62),"sedan-sports":Vector3(0,0.72,-0.54),"suv":Vector3(0,0.95,-0.69),"race":Vector3(0,0.49,-0.06)}
const BUTTONS=[JOY_BUTTON_RIGHT_STICK,JOY_BUTTON_LEFT_STICK,JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN]
const BUTTON_TITLES=["Right stick click (R3)","Left stick click (L3)","D-pad up","D-pad down"]
var mode=Mode.CLASSIC
var followed_id=0
var followed_reset=-1
var last_heading=Vector3.FORWARD
var notice_time=0.0
var probe=SphereShape3D.new()
var tilt_disabled=false
var last_mode=-1
var hidden_turret: Node3D

func _init() -> void: probe.radius=0.30

static func pressed(event: InputEvent,binding: int) -> bool:
	if event is InputEventKey: return event.pressed and not event.echo and event.physical_keycode==KEY_V
	return event is InputEventJoypadButton and event.pressed and event.button_index==BUTTONS[clampi(binding,0,BUTTONS.size()-1)]

func select(value: int) -> void:
	mode=posmod(value,TITLES.size()); last_mode=-1; notice_time=2.0

func protected_position(camera: Camera3D,car: Node3D,pivot: Vector3,desired: Vector3) -> Vector3:
	var query=PhysicsShapeQueryParameters3D.new(); query.shape=probe; query.collision_mask=1
	query.transform=Transform3D(Basis.IDENTITY,pivot); query.motion=desired-pivot
	query.exclude=[car.get_rid()]
	var fractions=camera.get_world_3d().direct_space_state.cast_motion(query)
	return pivot+query.motion*maxf(0.0,fractions[0]-0.02) if fractions[0]<1.0 else desired

func update(camera: Camera3D,car: Node3D,tilt: ShaderMaterial,delta: float,snap: bool=false) -> void:
	notice_time=maxf(0,notice_time-delta)
	snap=snap or followed_id!=car.get_instance_id() or followed_reset!=car.reset_serial or last_mode!=mode
	followed_id=car.get_instance_id(); followed_reset=car.reset_serial; last_mode=mode
	var forward: Vector3=-car.global_basis.z
	var horizontal=Vector3(forward.x,0,forward.z)
	if horizontal.length_squared()>0.1: last_heading=horizontal.normalized()
	var yaw=Basis.looking_at(last_heading,Vector3.UP)
	var target: Vector3=car.global_position
	var hood_active=mode==Mode.HOOD and car.global_basis.y.dot(Vector3.UP)>0.35
	# The roof-mounted muzzle intersects this local driver's eye. Only this client's
	# followed turret is hidden; shot simulation and other cars remain unchanged.
	if is_instance_valid(hidden_turret) and (hidden_turret!=car.turret or not hood_active): hidden_turret.show(); hidden_turret=null
	if hood_active: hidden_turret=car.turret; hidden_turret.hide()
	if mode<=Mode.WIDE:
		var lookahead: Vector3=car.linear_velocity.limit_length(12)*0.20; lookahead.y=0; target+=lookahead
		var offset: Vector3=[Vector3(0,22,17.5),Vector3(0,29,23),Vector3(0,39,31)][mode]
		camera.position=target+offset if snap else camera.position.lerp(target+offset,1-exp(-delta*5))
		camera.rotation_degrees=Vector3(-51.6,0,0); camera.fov=48; camera.near=0.15; camera.far=220
		tilt.set_shader_parameter("strength",0.0 if tilt_disabled else 3.8)
		var focus: Vector2=camera.unproject_position(car.global_position)
		tilt.set_shader_parameter("focus_y",clampf(focus.y/camera.get_viewport().get_visible_rect().size.y,0.4,0.65))
		return
	# No diorama blur in a driver's view. Depth fog keeps the distant horizon soft.
	tilt.set_shader_parameter("strength",0.0); camera.far=260; camera.near=0.07
	# An overturned hood would put the camera inside the terrain. Temporarily follow
	# from behind until the car is upright; the player's selected mode is retained.
	if hood_active:
		camera.fov=70
		camera.position=car.global_transform*EYE_POINTS.get(car.model_id,EYE_POINTS["hatchback-sports"])
		var pitch=clampf(asin(clampf(forward.y,-1,1)),deg_to_rad(-25),deg_to_rad(25))-deg_to_rad(4)
		var sight=last_heading*cos(pitch)+Vector3.UP*sin(pitch)
		camera.look_at(camera.position+sight*15,Vector3.UP)
	else:
		camera.fov=66
		var pivot=target+Vector3.UP*0.9
		var desired=target+yaw*Vector3(0,3.4,7.8)
		var smoothed=desired if snap else camera.position.lerp(desired,1-exp(-delta*9))
		camera.position=protected_position(camera,car,pivot,smoothed)
		var focus=target+Vector3.UP*0.8+last_heading*4
		if camera.position.distance_squared_to(focus)>0.01: camera.look_at(focus,Vector3.UP)
