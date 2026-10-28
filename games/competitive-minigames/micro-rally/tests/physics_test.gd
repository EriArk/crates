# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
class ContactCar extends "res://scripts/car.gd":
	var recorded_hit=Vector3.INF
	func take_damage(amount: float, impulse: Vector3 = Vector3.ZERO, hit_point: Vector3 = Vector3.INF) -> bool:
		recorded_hit=hit_point
		return super.take_damage(amount,impulse,hit_point)
var failures=0
var game: Node3D
var car: RigidBody3D
var samples: Array[int]=[]
func check(ok: bool, label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func box(size: Vector3, pos: Vector3, tilt: float = 0.0) -> StaticBody3D:
	var body=StaticBody3D.new(); var shape=BoxShape3D.new(); shape.size=size
	var collider=CollisionShape3D.new(); collider.shape=shape; body.add_child(collider)
	game.add_child(body); body.position=pos; body.rotation.x=tilt
	return body
func settle(pos: Vector3, orientation: Basis = Basis.IDENTITY, frames: int = 150) -> void:
	car.reset_at(Transform3D(orientation,pos)); car.health=100; car.disabled_time=0; car.immune=100
	car.throttle=0; car.brake=0; car.handbrake=false; car.boosting=false; car.steer_input=0
	for i in frames:
		await physics_frame; car.update_visuals()
func step_frames(frames: int) -> void:
	for i in frames:
		await physics_frame; car.update_visuals(); samples.append(car.physics.solve_usec)
		check(car.position.is_finite() and car.linear_velocity.is_finite(),"Finite state throughout terrain exercise")
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	game.state="test"; game.set_physics_process(false)
	for other in game.cars: other.freeze=true; other.collision_layer=0
	car=ContactCar.new(); car.track=game.track; game.add_child(car); car.collision_layer=2
	var floor=box(Vector3(160,0.4,160),Vector3(0,39.8,0))
	await settle(Vector3(0,40.8,0))
	check(car.physics.contacts==4 and car.grounded,"Four independent supports at rest")
	check(car.linear_velocity.length()<0.15 and absf(car.position.y-40.6)<0.2,"Stable ride height and stationary chassis")
	print("REST ",car.position," velocity=",car.linear_velocity," angular=",car.angular_velocity," wheels=",car.physics.wheels.map(func(w): return [w.length,w.load,w.normal]))
	var static_height=car.position.y
	var total_load=0.0
	for w in car.physics.wheels: total_load+=w.load
	check(absf(total_load-car.mass*14)<car.mass*14*0.1,"Springs support chassis weight")
	# One raised wheel: measured compression/roll, not a visual-only body animation.
	var bump=box(Vector3(0.65,0.18,0.7),Vector3(-0.6,40.09,-1.13))
	await settle(Vector3(0,40.9,0))
	var lengths=car.physics.wheels.map(func(w): return w.length)
	check(float(lengths.max())-float(lengths.min())>0.02,"Diagonal ground produces unequal suspension travel")
	check(absf(car.basis.y.x)+absf(car.basis.y.z)>0.025,"Unequal support rotates the physical chassis")
	bump.queue_free(); await physics_frame
	# Traditional steering has the same meaning at every world heading.
	for heading in [0.0,PI*0.5,PI,-PI*0.5]:
		for direction in [-1.0,1.0]:
			await settle(Vector3(0,40.8,0),Basis(Vector3.UP,heading))
			var initial=-car.basis.z
			car.throttle=0.65; car.steer_input=direction*0.55
			await step_frames(70)
			var yaw=initial.signed_angle_to(-car.basis.z,Vector3.UP)
			check(yaw*direction< -0.04,"Left/right steering is car-relative at heading %.2f: %.3f" % [heading,yaw])
	# Airborne tires cannot propel or pin the chassis to an invisible road.
	await settle(Vector3(0,47,0),Basis.IDENTITY,2)
	car.throttle=1; car.boosting=true
	var start=car.position; var airborne=0; var max_down=0.0
	for i in 45:
		await physics_frame
		if not car.grounded: airborne+=1
		max_down=maxf(max_down,-car.linear_velocity.y)
	check(airborne>20 and max_down>4,"Free flight with gravity and no phantom suspension")
	check(Vector2(car.position.x-start.x,car.position.z-start.z).length()<0.2,"Throttle/boost cannot accelerate unsupported chassis")
	car.throttle=0; car.boosting=false
	await step_frames(120)
	print("LAND ",car.position," velocity=",car.linear_velocity," angular=",car.angular_velocity," contacts=",car.physics.contacts)
	check(car.grounded and absf(car.position.y-static_height)<0.2 and car.linear_velocity.length()<0.4,"Landing damps out and restores four-wheel support")
	# An actual ramp, driven onto without teleporting or scripted launch impulses.
	var ramp=box(Vector3(6,0.3,12),Vector3(0,40.9,-14),0.18)
	await settle(Vector3(0,40.8,-2))
	car.throttle=1; car.steer_input=0
	var flew=false; var landed=false; var maximum_height=car.position.y
	for i in 230:
		await physics_frame; car.update_visuals()
		maximum_height=maxf(maximum_height,car.position.y)
		if car.position.z< -20 and not car.grounded: flew=true
		if flew and car.grounded: landed=true
	check(flew and landed and maximum_height>42,"Geometry and speed create ramp jump and landing")
	ramp.queue_free(); await physics_frame
	# Roll is genuinely free and roof contact works. No forced horizon correction.
	await settle(Vector3(0,44,0),Basis(Vector3.FORWARD,PI*0.8),2)
	var rolled=false
	for i in 180:
		await physics_frame
		if car.basis.y.y<0: rolled=true
	check(rolled and car.position.y>40.1,"Car can overturn and land on chassis without falling through")
	# Real third-wheel support and one durable damage event.
	await settle(Vector3(0,40.8,0))
	car.immune=0; car.ghost_time=0; car.health=30
	var point=car.wheel_pivots[0].global_position
	car.shield=100; car.take_damage(15,Vector3.ZERO,point)
	check(car.missing_wheels==0,"Shield protects wheel damage")
	car.shield=0; car.take_damage(15,Vector3.ZERO,point); car.update_visuals()
	check(car.missing_wheels==1,"Critical local hit detaches the struck wheel")
	var count=game.effects.loose_wheels.size()
	car.update_visuals(); car.update_visuals()
	check(game.effects.loose_wheels.size()==count,"Repeated state does not spawn duplicate wheels")
	car.throttle=0.6; var before=car.position
	await step_frames(100)
	check(car.physics.contacts<=3 and car.position.distance_to(before)>2,"Three-wheel car loses support and can limp onward")
	check(game.effects.loose_wheels.all(func(w): return w.node.collision_layer==0 and w.node.collision_mask==1),"Loose wheels are bounded world-only cosmetics")
	car.damage_wheel(1,100)
	check(car.health==0 and car.disabled_time>0,"Second wheel loss schedules normal recovery")
	await settle(Vector3(0,40.8,0))
	check(car.missing_wheels==0 and car.physics.contacts==4,"Recovery repairs wheels and clears compression history")
	# Engine contact callback away from the origin, with a rotated chassis. The
	# reported "local" contact position is already world-space in Godot/Jolt.
	await settle(Vector3(24,40.8,12),Basis(Vector3.UP,PI*0.5))
	var barrier=box(Vector3(0.4,1.5,0.6),Vector3(21.3,40.75,car.wheel_pivots[2].global_position.z))
	car.immune=0; car.ghost_time=0; car.health=35; car.shield=0
	car.physics.wheels[2].health=80 # Existing local wear, then a full-boost impact.
	car.recorded_hit=Vector3.INF; car.linear_velocity=Vector3(-27,0,0)
	await step_frames(35)
	print("IMPACT health=",car.health," point=",car.recorded_hit," missing=",car.missing_wheels," wheels=",car.physics.wheels.map(func(w): return [w.health,car.global_transform*(w.anchor-Vector3.UP*w.length)]))
	check(car.health<35 and car.recorded_hit.is_finite(),"Real chassis collision delivers impact damage")
	check(car.recorded_hit.distance_to(Vector3(21.5,40.75,12))<3,"Rotated offset collision retains world-space impact point")
	check(car.missing_wheels!=0,"Critical physical collision can detach the nearby wheel")
	barrier.queue_free(); await physics_frame
	# Compare the cheap reference ray and volume footprint on the same small obstacle.
	var step=box(Vector3(6,0.16,1.0),Vector3(0,40.08,-5))
	for mode in ["ray","volume"]:
		car.physics.query_mode=mode
		await settle(Vector3(0,40.8,0)); car.throttle=0.8
		await step_frames(120)
		check(car.position.z< -8,"Wheel query crosses small step: "+mode)
		print("CONTACT COMPARISON ",mode," z=",car.position.z," height=",car.position.y)
	car.physics.query_mode="volume"; step.queue_free()
	# Deadzone, analog strength and neutral safety are independent of orientation.
	check(game.controls.steering_axis(0.1)==0 and game.controls.steering_axis(-1)==-1 and game.controls.steering_axis(1)==1,"Steering deadzone and full analog range")
	samples.sort()
	print("PHYSICS TEST failures=",failures," ride_height=",static_height-40," load=",total_load," samples=",samples.size()," solve_us_p95=",samples[int(samples.size()*0.95)]," solve_us_p99=",samples[int(samples.size()*0.99)])
	floor.queue_free()
	await preload("audio_drain.gd").dispose(game,self); quit(1 if failures else 0)
