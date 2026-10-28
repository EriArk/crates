# SPDX-License-Identifier: GPL-3.0-or-later
extends RigidBody3D
const Art = preload("art.gd")
const BotDriver = preload("bot_driver.gd")
const VehiclePhysics = preload("vehicle_physics.gd")
const COLORS = [Color("ff8a28"),Color("27bec0"),Color("db4472"),Color("ad75ed"),Color("8dc84e"),Color("e7c13e"),Color("4c89d9"),Color("eeeece")]
var index = 0
var local_player = false
var human = false
var replica = false
var shield_pressed = false
var model_id = "hatchback-sports"
var track: Node3D
var checkpoint = 0
var passed = 0
var laps = 0
var finish_time = -1.0
var health = 100.0
var shield = 0.0
var shield_item = true
const HEAT_PER_SHOT = 8.5
const COOLING_PER_SECOND = 24.0
const RESUME_HEAT = 30.0
var weapon_heat = 0.0
var overheated = false
var cooling_delay = 0.0
var boost = 100.0
var immune = 2.0
var disabled_time = 0.0
var fire_cooldown = 0.0
var desired = Vector3.ZERO # Route target for bots only.
var steer_input = 0.0 # -1 left, +1 right; independent of camera/world heading.
var aim = Vector3.FORWARD
var throttle = 0.0
var brake = 0.0
var handbrake = false
var boosting = false
var firing = false
var grounded = false
var offroad = false
var slip = 0.0
var stuck_time = 0.0
var reset_pose = Transform3D.IDENTITY
var reset_pending = false
var visual: Node3D
var turret: Node3D
var shield_mesh: MeshInstance3D
var dirt_mesh: MeshInstance3D
var damage_material: StandardMaterial3D
var paint_materials: Array[ShaderMaterial] = []
var last_forward = Vector3.FORWARD
var surface_grip = 1.0
var lamp_material: StandardMaterial3D
var body_shape: Shape3D
var bot = BotDriver.new()
var ghost_time = 0.0
var recovery_lock = 0.0
var recovery_count = 0
var fall_count = 0
var did_not_finish = false
var physics = VehiclePhysics.new()
var transmission = preload("transmission.gd").new()
var manual_gears = false
var shift_serial = 0
var shift_direction = 0
var received_shift = 0

func request_shift(direction: int) -> void:
	if not manual_gears or disabled_time>0 or finish_time>=0: return
	shift_serial+=1; shift_direction=clampi(direction,-1,1)
	if not replica: transmission.request(shift_direction)

var wheel_pivots: Array[Node3D] = []
var wheel_colliders: Array[CollisionShape3D] = []
var missing_wheels = 0
var displayed_missing = 0
var reset_serial = 0
var overturned_time = 0.0
var impact_cooldown = 0.0
var impact_speed = 0.0

func _ready() -> void:
	mass=65; linear_damp=0.10; angular_damp=0.45; can_sleep=false
	center_of_mass_mode=RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM; center_of_mass=Vector3(0,-0.23,0)
	inertia=Vector3(72,88,28)
	continuous_cd=true
	contact_monitor=true; max_contacts_reported=8
	collision_layer=2; collision_mask=3
	var collider = CollisionShape3D.new(); var shape = ConvexPolygonShape3D.new()
	var corners=PackedVector3Array()
	for y in [-0.28,0.48]:
		for xz in [Vector2(-0.68,-1.8),Vector2(0.68,-1.8),Vector2(0.86,-1.55),Vector2(0.86,1.55),Vector2(0.68,1.8),Vector2(-0.68,1.8),Vector2(-0.86,1.55),Vector2(-0.86,-1.55)]:
			corners.append(Vector3(xz.x,y,xz.y))
	shape.points=corners; shape.margin=0.06
	body_shape=shape
	collider.shape=shape; add_child(collider)
	physics_material_override=PhysicsMaterial.new(); physics_material_override.friction=0.15; physics_material_override.bounce=0.08
	visual=Node3D.new(); visual.scale=Vector3.ONE*1.4; visual.position.y=0.252; add_child(visual)
	var model = Art.model("cars",model_id); model.rotation.y=PI; model.position.y=-0.63; visual.add_child(model)
	for part in model.find_children("*","MeshInstance3D",true,false):
		for surface in part.mesh.get_surface_count():
			var original = part.mesh.surface_get_material(surface)
			if original is StandardMaterial3D and original.albedo_texture!=null:
				var paint = ShaderMaterial.new(); paint.shader=preload("res://shaders/paint.gdshader")
				paint.set_shader_parameter("palette",original.albedo_texture); paint.set_shader_parameter("paint",COLORS[index%8])
				part.set_surface_override_material(surface,paint); paint_materials.append(paint)
	dirt_mesh=Art.box(visual,Vector3(1.28,0.16,1.9),Vector3(0,-0.2,0.05),Color(0.23,0.14,0.065,0.1))
	damage_material=Art.material(Color(0.23,0.14,0.065,0.1)).duplicate(); dirt_mesh.material_override=damage_material
	turret=Node3D.new(); turret.position=Vector3(0,0.63,0); visual.add_child(turret)
	Art.box(turret,Vector3(0.38,0.28,0.45),Vector3.ZERO,Color("303a41"))
	Art.box(turret,Vector3(0.12,0.12,0.85),Vector3(0,0.04,-0.48),Color("8a979c"))
	shield_mesh=MeshInstance3D.new(); var sphere = SphereMesh.new(); sphere.radius=2.0; sphere.height=3.0
	shield_mesh.mesh=sphere; shield_mesh.material_override=Art.material(Color(0.1,0.58,1.0,0.16),0.7)
	shield_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(shield_mesh)
	_setup_wheels(model)
	lamp_material=Art.material(Color("e2dec6")).duplicate(); lamp_material.emission_enabled=true
	lamp_material.emission=Color("ffe4b6"); lamp_material.emission_energy_multiplier=0
	for side in [-1,1]:
		var lamp = Art.box(self,Vector3(0.18,0.14,0.08),Vector3(side*0.55,0.0,-1.58),Color("e2dec6"))
		lamp.material_override=lamp_material; lamp.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func reset_at(pose: Transform3D) -> void:
	reset_pose=pose; reset_pending=true; immune=2.0; reset_serial+=1
	repair_wheels(); overturned_time=0
	ghost_time=2.0; collision_layer=4; collision_mask=1
	bot.reversing=0; stuck_time=0; recovery_lock=2.0

func _setup_wheels(model: Node3D) -> void:
	for wheel_name in ["wheel-back-left","wheel-back-right","wheel-front-left","wheel-front-right"]:
		var part: MeshInstance3D=model.find_child(wheel_name,true,false)
		assert(part!=null,"Car asset must contain four named wheels")
		var bounds=part.get_aabb()
		var center=to_local(part.to_global(bounds.get_center()))
		var radius=bounds.size.y*1.4*0.5
		var width=bounds.size.x*1.4
		var anchor=center+Vector3.UP*(VehiclePhysics.REST-0.07)
		physics.add_wheel(anchor,radius,width,wheel_name.contains("front"))
		var pivot=Node3D.new(); add_child(pivot); pivot.position=center
		part.reparent(pivot,true); wheel_pivots.append(pivot)
		# Small inner collision volume catches lateral impacts/bottoming. The outer tire
		# footprint belongs to suspension queries, so it does not double support the car.
		var collider=CollisionShape3D.new(); var shape=SphereShape3D.new(); shape.radius=radius*0.55
		collider.shape=shape; collider.position=center; add_child(collider); wheel_colliders.append(collider)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if replica: return
	if reset_pending:
		state.transform=reset_pose; state.linear_velocity=Vector3.ZERO; state.angular_velocity=Vector3.ZERO; reset_pending=false
		physics.reset(); transmission.reset(); shift_direction=0; reset_physics_interpolation()
		return
	impact_cooldown=maxf(0,impact_cooldown-state.step)
	impact_speed=0
	var strongest_contact=-1
	for c in state.get_contact_count():
		var impulse=state.get_contact_impulse(c).length()
		if impulse/mass>impact_speed:
			impact_speed=impulse/mass; strongest_contact=c
	if impact_speed>5.5 and impact_cooldown<=0:
		impact_cooldown=0.35
		# Select the strongest contact before applying the shared cooldown. A small
		# first contact must not mask the main impact in the same solver step.
		# Despite "local" in its name, Godot returns this point in world coordinates.
		take_damage(minf(24,(impact_speed-5.5)*2.0),Vector3.ZERO,state.get_contact_local_position(strongest_contact))
	physics.solve(self,state)

func repair_wheels() -> void:
	missing_wheels=0
	for w in physics.wheels: w.missing=false; w.health=100.0

func damage_wheel(index_value: int, amount: float) -> void:
	if replica or index_value<0 or index_value>=4: return
	var wheel: Dictionary=physics.wheels[index_value]
	if wheel.missing: return
	wheel.health=maxf(0,wheel.health-amount)
	if wheel.health>0: return
	if missing_wheels!=0:
		health=0; disabled_time=1.6; throttle=0; boosting=false
		return
	wheel.missing=true; wheel.contact=false; wheel.load=0
	missing_wheels|=1<<index_value

func tick(delta: float) -> void:
	immune=maxf(0,immune-delta); disabled_time=maxf(0,disabled_time-delta)
	tick_weapon(delta)
	recovery_lock=maxf(0,recovery_lock-delta)
	if ghost_time>0:
		ghost_time=maxf(0,ghost_time-delta)
		if ghost_time<=0 and finish_time<0:
			var query = PhysicsShapeQueryParameters3D.new(); query.shape=body_shape; query.transform=global_transform; query.collision_mask=6; query.exclude=[get_rid()]; query.margin=0.15
			if get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): collision_layer=2; collision_mask=3
			else: ghost_time=0.1; immune=maxf(immune,0.1)
	shield=maxf(0,shield-delta*2.0)
	update_visuals()
	var nearest_index: int=track.nearest(position,checkpoint)
	var advance = posmod(nearest_index-checkpoint,track.COUNT)
	var road_delta: Vector3=position-track.points[nearest_index]
	var on_course = Vector2(road_delta.x,road_delta.z).length()<track.WIDTH*0.5+1.5 and absf(road_delta.y)<2.5
	if advance<12 and on_course and not reset_pending:
		passed+=advance; checkpoint=nearest_index; laps=passed/track.COUNT
	offroad=track.road_distance(position,nearest_index)>track.WIDTH*0.5+0.5
	if grounded and linear_velocity.length()<1.5 and (throttle>0.2 or brake>0.5): stuck_time+=delta
	else: stuck_time=0
	if basis.y.dot(Vector3.UP)<0.2 and linear_velocity.length()<3: overturned_time+=delta
	else: overturned_time=0

func update_visuals() -> void:
	for i in physics.wheels.size():
		var w: Dictionary=physics.wheels[i]
		var lost=(missing_wheels&(1<<i))!=0
		if lost and (displayed_missing&(1<<i))==0 and get_parent().get("effects")!=null:
			get_parent().effects.detach_wheel(self,i)
		w.missing=lost
		wheel_pivots[i].visible=not lost
		wheel_pivots[i].position=w.anchor-Vector3.UP*w.length
		wheel_pivots[i].basis=Basis(Vector3.UP,physics.steer if w.front else 0.0)*Basis(Vector3.RIGHT,-w.spin)
		wheel_colliders[i].position=wheel_pivots[i].position
		if wheel_colliders[i].disabled!=lost: wheel_colliders[i].set_deferred("disabled",lost)
	displayed_missing=missing_wheels
	shield_mesh.visible=shield>0 or immune>0
	if aim.length_squared()>0.1: turret.global_rotation.y=atan2(-aim.x,-aim.z)
	damage_material.albedo_color.a=clampf((100-health)*0.006+0.12,0.12,0.7)
	dirt_mesh.visible=false
	for paint in paint_materials: paint.set_shader_parameter("damage",clampf((100-health)*0.008+0.12,0.12,0.9))

func steer_towards(direction: Vector3) -> void:
	# Navigation helper shared by AI/test drivers; human input bypasses heading conversion.
	var forward=-basis.z; var up=basis.y
	var target=direction.slide(up).normalized()
	steer_input=clampf(-forward.signed_angle_to(target,up)*1.05/0.62,-1,1)

func bot_drive(others: Array = [], delta: float = 1.0/60.0) -> void:
	bot.drive(self,others,delta)

func driver_title() -> String:
	return "You" if local_player else "Player "+str(index+1) if human else BotDriver.STYLES[bot.style_index(index)]+" "+str(index)

func tick_weapon(delta: float) -> void:
	if replica: return # Heat and lockout are authoritative host state.
	fire_cooldown=maxf(0,fire_cooldown-delta)
	var cooling_time = maxf(0,delta-cooling_delay)
	cooling_delay=maxf(0,cooling_delay-delta)
	weapon_heat=maxf(0,weapon_heat-COOLING_PER_SECOND*cooling_time)
	if overheated and weapon_heat<=RESUME_HEAT: overheated=false

func begin_shot() -> bool:
	if replica or overheated or fire_cooldown>0 or disabled_time>0 or finish_time>=0 or ghost_time>0: return false
	fire_cooldown=0.28; cooling_delay=0.45
	weapon_heat=minf(100,weapon_heat+HEAT_PER_SHOT)
	if weapon_heat>=100: overheated=true
	return true
func cool_weapon() -> void:
	weapon_heat=0; overheated=false; cooling_delay=0

func activate_shield() -> void:
	if replica: return
	if shield_item and disabled_time<=0: shield=100; shield_item=false

func take_damage(amount: float, impulse: Vector3 = Vector3.ZERO, hit_point: Vector3 = Vector3.INF) -> bool:
	if replica or immune>0 or disabled_time>0 or finish_time>=0 or ghost_time>0: return false
	var absorbed = minf(shield,amount); shield-=absorbed; amount-=absorbed
	health=maxf(0,health-amount)
	if amount>0 and health<=35 and hit_point.is_finite():
		var nearest_wheel=-1; var distance=1.15
		for i in physics.wheels.size():
			var d=wheel_pivots[i].global_position.distance_to(hit_point)
			if d<distance: nearest_wheel=i; distance=d
		if nearest_wheel>=0: damage_wheel(nearest_wheel,amount*8)
	apply_central_impulse(impulse.limit_length(150))
	if health<=0: disabled_time=1.6; throttle=0; boosting=false
	return true
