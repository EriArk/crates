# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
# Original implementation; design references and numerical choices: docs/VEHICLE_PHYSICS.md.
const Tires = preload("tire_surface.gd")
const REST = 0.50
const TRAVEL = 0.64
const MIN_LENGTH = 0.12
const SPRING = 4200.0
const BUMP_DAMP = 290.0
const REBOUND_DAMP = 340.0
const ANTIROLL = 220.0
var wheels: Array = []
var steer = 0.0
var contacts = 0
var solve_usec = 0
var query_count = 0
var query_mode = "volume" # Diagnostic comparison only, not a player physics setting.

func add_wheel(anchor: Vector3, radius: float, width: float, front: bool) -> void:
	var sphere=SphereShape3D.new(); sphere.radius=minf(radius*0.6,width*0.5)
	var query=PhysicsShapeQueryParameters3D.new(); query.shape=sphere; query.collision_mask=1; query.margin=0.005
	var ray=PhysicsRayQueryParameters3D.new(); ray.collision_mask=1
	wheels.append({"anchor":anchor,"radius":radius,"probe":sphere.radius,"front":front,
		"query":query,"ray":ray,"length":REST,"load":0.0,"contact":false,"point":Vector3.ZERO,
		"normal":Vector3.UP,"ground_velocity":Vector3.ZERO,"rid":RID(),"spin":0.0,"omega":0.0,
		"slip":0.0,"long_slip":0.0,"slip_ratio":0.0,"surface":Tires.Kind.MUD,"grip_factor":1.0,"health":100.0,"missing":false,"force":Vector2.ZERO})

func reset() -> void:
	steer=0; contacts=0
	for w in wheels:
		w.length=REST; w.load=0.0; w.contact=false; w.omega=0.0; w.force=Vector2.ZERO; w.slip=0.0; w.long_slip=0.0; w.slip_ratio=0.0; w.grip_factor=1.0

func _probe(state: PhysicsDirectBodyState3D, w: Dictionary) -> Dictionary:
	var up=state.transform.basis.y
	var origin: Vector3=state.transform*w.anchor
	if query_mode=="ray":
		w.ray.from=origin; w.ray.to=origin-up*(TRAVEL+w.radius)
		query_count+=1
		var hit=state.get_space_state().intersect_ray(w.ray)
		if hit.is_empty(): return {}
		return {"point":hit.position,"normal":hit.normal,"rid":hit.rid,"linear_velocity":Vector3.ZERO,
			"length":origin.distance_to(hit.position)-w.radius}
	# A rounded, finite-width footprint. Offset preserves the actual tire radius.
	var start: Vector3=origin-up*(w.radius-w.probe)
	w.query.transform=Transform3D(Basis.IDENTITY,start); w.query.motion=Vector3.ZERO
	query_count+=1
	var hit=state.get_space_state().get_rest_info(w.query)
	if not hit.is_empty():
		hit.length=0.0; return hit
	w.query.motion=-up*TRAVEL
	query_count+=1
	var travel=state.get_space_state().cast_motion(w.query)
	if travel.size()!=2 or travel[0]>=1.0: return {}
	w.query.transform.origin=start-up*(travel[1]*TRAVEL+0.008)
	w.query.motion=Vector3.ZERO
	query_count+=1
	hit=state.get_space_state().get_rest_info(w.query)
	if hit.is_empty(): return {}
	hit.length=clampf(travel[0]*TRAVEL,0,TRAVEL)
	return hit

func solve(car: RigidBody3D, state: PhysicsDirectBodyState3D) -> void:
	var started=Time.get_ticks_usec()
	var dt=state.step; var up=state.transform.basis.y; var forward=-state.transform.basis.z
	var flat=Vector3(forward.x,0,forward.z).normalized()
	if flat.length_squared()>0.1: car.last_forward=flat
	var speed=state.linear_velocity.dot(forward)
	var target=-car.steer_input*0.62 if car.disabled_time<=0 else 0.0
	steer=move_toward(steer,target,dt*2.8)
	contacts=0; query_count=0; car.slip=0.0
	for w in wheels:
		w.load=0.0; w.contact=false; w.force=Vector2.ZERO; w.slip=0.0; w.long_slip=0.0; w.slip_ratio=0.0
		if w.missing: continue
		var hit=_probe(state,w)
		if hit.is_empty() or hit.normal.dot(Vector3.UP)<0.25 or hit.normal.dot(up)<0.25:
			w.length=move_toward(w.length,TRAVEL,dt*2.5); continue
		w.length=clampf(hit.length,0,TRAVEL)
		if w.length>=REST+0.08: continue
		w.contact=true; contacts+=1; w.point=hit.point; w.normal=hit.normal
		w.ground_velocity=hit.linear_velocity; w.rid=hit.rid
	car.grounded=contacts>0
	var active_boost=car.boosting and car.boost>0 and car.throttle>0 and car.disabled_time<=0 and contacts>0
	car.boost=clampf(car.boost+dt*(-23.0 if active_boost else 10.0),0,100)
	var max_speed=26.0+(9.0 if active_boost else 0.0)
	var wheel_speed=0.0; var driven=0
	for w in wheels:
		if not w.missing and (w.contact or contacts==0): wheel_speed+=w.omega*w.radius; driven+=1
	wheel_speed=wheel_speed/driven if driven>0 else speed
	car.transmission.step(dt,speed,wheel_speed,car.throttle if car.disabled_time<=0 else 0.0,car.brake,contacts>0,car.manual_gears)
	for i in wheels.size():
		var w: Dictionary=wheels[i]
		if w.missing: continue
		if not w.contact:
			# Free wheel inertia receives motor/brake torque, never a chassis force.
			var inertia: float=0.5*3.0*w.radius*w.radius
			var drive: float=car.throttle*car.mass*car.transmission.drive_acceleration(false)/4.0
			if car.disabled_time>0 or car.transmission.reverse: drive=0.0
			if car.transmission.reverse and car.disabled_time<=0: drive=-car.brake*car.mass*7/4
			drive*=1.0-smoothstep(car.transmission.REDLINE*0.94,car.transmission.REDLINE,car.transmission.road_rpm(w.omega*w.radius,car.transmission.gear))
			w.omega+=drive*w.radius/inertia*dt
			var brake: float=(car.throttle if car.transmission.reverse else car.brake)*car.mass*22/4*w.radius
			if car.handbrake and not w.front: brake+=car.mass*30/4*w.radius
			w.omega=clampf(move_toward(w.omega,0,dt*(2+brake/inertia)),-180,180)
			w.spin=wrapf(w.spin+w.omega*dt,-PI,PI); continue
		var offset: Vector3=w.point-state.transform.origin
		var arm: Vector3=offset-state.center_of_mass
		var relative=state.linear_velocity+state.angular_velocity.cross(arm)-w.ground_velocity
		var normal: Vector3=w.normal
		var twist=arm.cross(normal)
		var inv_mass=state.inverse_mass+twist.dot(state.inverse_inertia_tensor*twist)
		var spring=SPRING
		if w.length<MIN_LENGTH: spring+=12000.0*(MIN_LENGTH-w.length)/MIN_LENGTH
		var vn=relative.dot(normal)
		var damp=BUMP_DAMP if vn<0 else REBOUND_DAMP
		var other: Dictionary=wheels[i^1]
		var anti=ANTIROLL*(other.length-w.length) if other.contact and not other.missing else 0.0
		# Implicit spring/damper impulse: stable at 60 Hz, unilateral (no ground suction).
		var load=clampf((spring*(REST-w.length)-damp*vn+anti)/(1+dt*(damp+spring*dt)*inv_mass),0,car.mass*14*1.7)
		w.load=load
		state.apply_force(normal*load,offset)
		var tire_forward=forward.rotated(up,steer if w.front else 0.0).slide(normal).normalized()
		var tire_right=tire_forward.cross(normal).normalized()
		var longitudinal=relative.dot(tire_forward); var lateral=relative.dot(tire_right)
		w.surface=car.track.tire_surface_at(w.point) if is_instance_valid(car.track) and car.track.has_method("tire_surface_at") else Tires.Kind.MUD
		var profile=Tires.profile(w.surface,Tires.wetness(car.surface_grip))
		var turn_slip=absf(atan2(lateral,maxf(absf(longitudinal),2.0)))
		var grip_drop=lerpf(1.0,Tires.SLIDING[w.surface],smoothstep(0.12,0.8,turn_slip))
		w.grip_factor=lerpf(w.grip_factor,grip_drop,1-exp(-dt*12))
		var mu=profile.x*w.grip_factor
		var effective_load=minf(load,car.mass*14*0.6)
		var budget=mu*effective_load
		var drive=car.throttle*car.mass*car.transmission.drive_acceleration(active_boost)/4.0
		if car.disabled_time>0 or speed>max_speed or car.transmission.reverse: drive=0
		var wheel_inertia: float=0.5*3.0*w.radius*w.radius
		# Motor/brake torque first, then the contact impulse couples spin to the body.
		var rolling=longitudinal*profile.z*car.mass/4.0
		var torque=(drive-rolling)*w.radius
		var brake_torque=0.0
		if car.brake>0:
			if longitudinal>0.4: brake_torque=car.brake*car.mass*22/4*w.radius
			elif car.transmission.reverse and car.disabled_time<=0 and speed> -5: torque-=car.brake*car.mass*7/4*w.radius
		if car.transmission.reverse and car.throttle>0.05: brake_torque+=car.throttle*car.mass*22/4*w.radius
		if car.handbrake and not w.front: brake_torque+=car.mass*30/4*w.radius
		if car.throttle<0.05 and car.brake<0.05: torque-=longitudinal*car.mass*0.8/4*w.radius
		w.omega+=torque/wheel_inertia*dt
		w.omega=move_toward(w.omega,0,brake_torque/wheel_inertia*dt)
		var longitudinal_slip: float=(w.omega*w.radius-longitudinal)/maxf(2.0,absf(longitudinal))
		var longitudinal_twist=arm.cross(tire_forward)
		var inv_long=state.inverse_mass+longitudinal_twist.dot(state.inverse_inertia_tensor*longitudinal_twist)
		var fx: float=(w.omega*w.radius-longitudinal)/(inv_long+w.radius*w.radius/wheel_inertia)/dt
		var fy=-lateral*car.mass*(5.3 if w.front else 5.8)/4.0
		if car.handbrake and not w.front:
			fy*=0.3
		budget*=lerpf(1.0,Tires.SLIDING[w.surface],smoothstep(0.16,0.8,absf(longitudinal_slip)))
		# Combined traction ellipse: acceleration/braking consume cornering reserve.
		var force=Vector2(fx,fy/maxf(0.1,profile.y))
		if force.length()>budget: force=force.normalized()*budget
		fx=force.x; fy=force.y*profile.y
		w.omega-=fx*dt*w.radius/wheel_inertia
		w.omega=clampf(w.omega,-180,180)
		var impulse=(tire_forward*fx+tire_right*fy)*dt
		state.apply_force(impulse/dt,offset)
		# Dynamic platforms receive the equal opposite force. Static terrain needs no update.
		if w.rid.is_valid():
			var ground_state=PhysicsServer3D.body_get_direct_state(w.rid)
			if ground_state!=null and ground_state.inverse_mass>0:
				ground_state.apply_force(-impulse/dt-normal*load,w.point-ground_state.transform.origin)
		# Residual AFTER contact impulse; free rolling must not look like burnout.
		w.long_slip=clampf(w.omega*w.radius-(longitudinal+fx*dt*inv_long),-60,60)
		w.slip_ratio=w.long_slip/maxf(2,absf(longitudinal))
		w.force=Vector2(fx,fy); w.slip=minf(60,absf(lateral))
		car.slip=maxf(car.slip,Vector2(w.long_slip,w.slip).length())
		w.spin=wrapf(w.spin+w.omega*dt,-PI,PI)
	# Mild yaw damping assists countersteer without fixing pitch, roll or lateral velocity.
	if contacts>=2:
		state.apply_torque(-up*state.angular_velocity.dot(up)*car.mass*0.45)
	solve_usec=Time.get_ticks_usec()-started
