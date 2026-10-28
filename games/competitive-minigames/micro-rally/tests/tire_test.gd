# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Tires=preload("res://scripts/tire_surface.gd")
const Wire=preload("res://scripts/race_wire.gd")
class Patch extends Node3D:
	var kind=0
	var mixed=false
	func tire_surface_at(p: Vector3) -> int: return 4 if mixed and p.x>0 else kind
var failures=0
var game: Node3D
var car: Node3D
var patch=Patch.new()
func check(ok: bool, label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func reset(kind: int, wet: float=0.0, height: float=40.8) -> void:
	patch.kind=kind; patch.mixed=false; car.surface_grip=1-wet*0.2
	car.throttle=0; car.brake=0; car.handbrake=false; car.boosting=false; car.steer_input=0
	car.reset_at(Transform3D(Basis.IDENTITY,Vector3(0,height,0)))
	for i in (90 if height<42 else 2): await physics_frame
func launch(kind: int, pedal: float) -> Dictionary:
	await reset(kind)
	var slide=0.0
	for i in 90:
		car.throttle=pedal
		await physics_frame
		for w in car.physics.wheels: slide+=absf(w.long_slip)
	return {"slip":slide/360,"speed":-car.linear_velocity.z,"distance":-car.position.z}
func braking(kind: int, wet: float) -> float:
	await reset(kind,wet); car.linear_velocity=Vector3(0,0,-12)
	for w in car.physics.wheels: w.omega=12/w.radius
	car.brake=1
	for i in 150:
		await physics_frame
		if absf(car.linear_velocity.z)<0.6: break
	check(absf(car.linear_velocity.z)<0.6,"Braking stops on material %s" % kind)
	return -car.position.z
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	game.state="test"; game.set_physics_process(false); game.set_process(false)
	for c in game.cars: c.freeze=true; c.collision_layer=0
	root.add_child(patch)
	car=preload("res://scripts/car.gd").new(); car.track=patch; game.add_child(car)
	var floor_body=StaticBody3D.new(); var shape=CollisionShape3D.new(); var box=BoxShape3D.new()
	box.size=Vector3(200,1,300); shape.shape=box; floor_body.add_child(shape); floor_body.position.y=39.5; root.add_child(floor_body)
	var soft=await launch(Tires.Kind.GRASS,0.4); var hard=await launch(Tires.Kind.GRASS,1.0)
	check(hard.slip>soft.slip+0.2 and hard.speed>soft.speed,"Excess gas spins tires while still accelerating")
	var asphalt=await launch(Tires.Kind.ASPHALT,1.0)
	check(asphalt.speed>hard.speed and asphalt.slip<hard.slip,"Hard road accelerates better with less wheelspin than grass")
	print("LAUNCH soft=",soft," hard=",hard," asphalt=",asphalt)
	var distances=[]
	for kind in 5: distances.append(await braking(kind,0))
	var wet=await braking(Tires.Kind.ASPHALT,0.8)
	check(wet>distances[0]*1.1 and distances[4]>distances[0]*1.15,"Wet asphalt and grass extend measured braking distance")
	print("BRAKE asphalt/concrete/gravel/mud/grass=",distances," wet_asphalt=",wet)
	var offroad_speeds=[]
	for flag in [false,true]:
		await reset(Tires.Kind.ASPHALT); car.offroad=flag
		car.linear_velocity=Vector3(0,0,-14); car.transmission.gear=4; car.throttle=1
		for w in car.physics.wheels: w.omega=14/w.radius
		for i in 30: await physics_frame
		offroad_speeds.append(-car.linear_velocity.z)
	check(absf(offroad_speeds[0]-offroad_speeds[1])<0.02 and offroad_speeds[1]>14,"Center offroad flag cannot cut all-wheel drive above 12 m/s")
	var corner_forces=[]
	for pedal in [0.2,1.0]:
		await reset(Tires.Kind.MUD); car.linear_velocity=Vector3(4,0,-6); car.throttle=pedal; car.steer_input=0.5
		for w in car.physics.wheels: w.omega=6/w.radius
		for i in 3: await physics_frame
		var lateral=0.0
		for w in car.physics.wheels: lateral+=absf(w.force.y)
		corner_forces.append(lateral)
	check(corner_forces[1]<corner_forces[0],"Hard throttle consumes lateral tire-force reserve in a corner")
	print("OFFROAD_FLAG speeds=",offroad_speeds," CORNER lateral_forces=",corner_forces)
	await reset(Tires.Kind.ASPHALT); patch.mixed=true
	car.throttle=1
	for i in 30: await physics_frame
	var road=0; var grass=0; var road_slip=0.0; var grass_slip=0.0
	for w in car.physics.wheels:
		if w.surface==Tires.Kind.GRASS: grass+=1; grass_slip+=absf(w.long_slip)
		else: road+=1; road_slip+=absf(w.long_slip)
	check(road==2 and grass==2 and grass_slip>road_slip,"Two tires on each surface have independent traction")
	await reset(Tires.Kind.ASPHALT)
	car.linear_velocity=Vector3(0,0,-12)
	for w in car.physics.wheels: w.omega=12/w.radius
	car.handbrake=true
	for i in 5: await physics_frame
	check(car.physics.wheels[0].long_slip< -1 and absf(car.physics.wheels[2].long_slip)<1,"Rear lockup is distinct from freely rolling front wheels")
	await reset(Tires.Kind.ASPHALT,0,55)
	car.throttle=1
	for i in 15: await physics_frame
	var omega: float=car.physics.wheels[0].omega
	check(omega>5 and Vector2(car.linear_velocity.x,car.linear_velocity.z).length()<0.1,"Air throttle spins tires without propelling chassis")
	car.throttle=0; car.brake=1
	for i in 8: await physics_frame
	check(not car.transmission.reverse and absf(car.physics.wheels[0].omega)<omega*0.2,"Brake slows unsupported tires")
	for i in 180: await physics_frame
	check(car.grounded and car.linear_velocity.is_finite(),"Spinning tire landing remains stable")
	# Frozen authoritative burnout fixture exercises real presentation at zero chassis speed.
	car.freeze=true; car.grounded=true; car.linear_velocity=Vector3.ZERO; car.ghost_time=0
	for w in car.physics.wheels: w.contact=true; w.missing=false; w.surface=Tires.Kind.ASPHALT; w.long_slip=8; w.slip=0
	check(Tires.feedback(car).x>0.9,"Stationary longitudinal slip reaches feedback")
	game.effects.clear(); game.effects.dust(car,0)
	check(game.effects.particles.size()==2 and game.effects.particles[0].node.material_override==game.effects.tire_smoke,"Dry asphalt burnout emits bounded tire smoke")
	game.effects.clear()
	for w in car.physics.wheels: w.long_slip=0
	car.linear_velocity=Vector3(0,0,-12); game.effects.dust(car,0)
	check(game.effects.particles.is_empty(),"Free rolling dry asphalt emits no dirt")
	game.effects.dust(car,0.8)
	check(game.effects.particles.size()==2 and game.effects.particles[0].node.material_override==game.effects.spray_material,"Wet asphalt emits water spray")
	for w in car.physics.wheels: w.surface=Tires.Kind.MUD; w.long_slip=8
	var packed=Wire.car_state(car)
	check(packed.size()==56 and packed[44]==800 and packed[46]==Tires.Kind.MUD,"Wire retains signed per-wheel slip and material")
	var nord=preload("res://scripts/nordschleife_track.gd").new()
	var at=roundi((nord.data.banks[0][0]+nord.data.banks[0][1])*0.5/20832*nord.COUNT)
	check(nord.tire_surface_at(nord.points[at])==Tires.Kind.CONCRETE,"Karussell concrete matches authored inside lane")
	check(nord.tire_surface_at(nord.points[0])==Tires.Kind.ASPHALT,"Nord straight is asphalt")
	nord.free(); patch.queue_free(); floor_body.queue_free()
	print("TIRE TEST failures=",failures)
	await preload("audio_drain.gd").dispose(game,self); quit(1 if failures else 0)
