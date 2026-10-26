# SPDX-License-Identifier: GPL-3.0-or-later
extends RigidBody3D
const Art = preload("art.gd")
const COLORS = [Color("ff8a28"),Color("27bec0"),Color("db4472"),Color("ad75ed"),Color("8dc84e"),Color("e7c13e"),Color("4c89d9"),Color("eeeece")]
var index = 0
var model_id = "hatchback-sports"
var track: Node3D
var checkpoint = 0
var passed = 0
var laps = 0
var finish_time = -1.0
var health = 100.0
var shield = 0.0
var shield_item = true
var ammo = 12
var boost = 100.0
var immune = 2.0
var disabled_time = 0.0
var fire_cooldown = 0.0
var desired = Vector3.ZERO
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

func _ready() -> void:
	mass=65; linear_damp=0.14; angular_damp=4.0; can_sleep=false
	axis_lock_angular_x=true; axis_lock_angular_z=true; continuous_cd=true
	contact_monitor=true; max_contacts_reported=4
	collision_layer=2; collision_mask=3
	var collider = CollisionShape3D.new(); var shape = BoxShape3D.new(); shape.size=Vector3(1.75,0.9,3.25)
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
	body_entered.connect(_collision)

func reset_at(pose: Transform3D) -> void:
	reset_pose=pose; reset_pending=true; immune=2.0

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if reset_pending:
		state.transform=reset_pose; state.linear_velocity=Vector3.ZERO; state.angular_velocity=Vector3.ZERO; reset_pending=false
		return
	var step = state.step
	var forward = -state.transform.basis.z; forward.y=0; forward=forward.normalized(); last_forward=forward
	var right = state.transform.basis.x; right.y=0; right=right.normalized()
	var speed = state.linear_velocity.dot(forward)
	var side_speed = state.linear_velocity.dot(right); slip=absf(side_speed)
	grounded=false
	for wheel in [Vector3(-0.51,0,0.83),Vector3(0.51,0,0.83),Vector3(-0.51,0,-0.83),Vector3(0.51,0,-0.83)]:
		var origin = state.transform*wheel
		var query = PhysicsRayQueryParameters3D.create(origin+Vector3.UP*0.25,origin-Vector3.UP*1.0,1)
		var hit = state.get_space_state().intersect_ray(query)
		if hit.is_empty(): continue
		var height: float=origin.y-hit.position.y
		if height>0.85: continue
		grounded=true
		var force = clampf((0.72-height)*1600.0-state.linear_velocity.y*130.0,0,2200)
		state.apply_central_force(Vector3.UP*force)
	if not grounded: return
	var grip = (2.8 if offroad else 5.6)*(0.25 if handbrake else 1.0)
	state.apply_central_force(-right*side_speed*mass*grip)
	var engine = throttle*mass*13.0
	if disabled_time>0: engine=0
	if boosting and boost>0 and throttle>0 and disabled_time<=0:
		engine*=1.7; boost=maxf(0,boost-step*23)
	else: boost=minf(100,boost+step*10)
	var top_speed = (12.0 if offroad else 19.0)+(8.0 if boosting and boost>0 else 0.0)
	if speed<top_speed: state.apply_central_force(forward*engine)
	if brake>0:
		if speed>0.6: state.apply_central_force(-forward*brake*mass*22)
		elif speed>-5: state.apply_central_force(-forward*brake*mass*7)
	if throttle<0.05 and brake<0.05: state.apply_central_force(-forward*speed*mass*0.6)
	if handbrake: state.apply_central_force(-forward*speed*mass*0.9)
	if desired.length_squared()>0.1 and disabled_time<=0:
		var error = forward.signed_angle_to(desired,Vector3.UP)
		var rate = clampf(absf(speed)*0.26,0.0,2.5)*(1.45 if handbrake else 1.0)
		state.angular_velocity.y=move_toward(state.angular_velocity.y,clampf(error*4.0,-rate,rate),step*9)
	else: state.angular_velocity.y=move_toward(state.angular_velocity.y,0,step*5)

func tick(delta: float) -> void:
	immune=maxf(0,immune-delta); disabled_time=maxf(0,disabled_time-delta); fire_cooldown=maxf(0,fire_cooldown-delta)
	shield=maxf(0,shield-delta*2.0)
	shield_mesh.visible=shield>0 or immune>0
	if aim.length_squared()>0.1: turret.global_rotation.y=atan2(-aim.x,-aim.z)
	damage_material.albedo_color.a=clampf((100-health)*0.006+0.12,0.12,0.7)
	dirt_mesh.visible=false
	for paint in paint_materials: paint.set_shader_parameter("damage",clampf((100-health)*0.008+0.12,0.12,0.9))
	var nearest_index: int=track.nearest(position,checkpoint)
	var advance = posmod(nearest_index-checkpoint,track.COUNT)
	if advance<12:
		passed+=advance; checkpoint=nearest_index; laps=passed/track.COUNT
	offroad=track.road_distance(position,nearest_index)>track.WIDTH*0.5+0.5
	if linear_velocity.length()<1 and throttle>0.5: stuck_time+=delta
	else: stuck_time=0

func bot_drive() -> void:
	var target: Vector3=track.points[(checkpoint+7)%track.COUNT]
	var tangent: Vector3=track.tangents[(checkpoint+7)%track.COUNT]
	var lane = (float(index%5)-2.0)*1.45
	target+=Vector3(-tangent.z,0,tangent.x)*lane
	desired=target-position; desired.y=0; desired=desired.normalized()
	var angle = absf(last_forward.signed_angle_to(desired,Vector3.UP))
	throttle=1.0 if angle<0.8 else 0.55
	brake=0.7 if angle>0.75 and linear_velocity.length()>11 else 0.0
	handbrake=angle>0.8 and index%4==3
	boosting=angle<0.15 and boost>40 and index%4!=2
	aim=desired; firing=false

func activate_shield() -> void:
	if shield_item and disabled_time<=0: shield=100; shield_item=false

func take_damage(amount: float, impulse: Vector3 = Vector3.ZERO) -> bool:
	if immune>0 or disabled_time>0: return false
	var absorbed = minf(shield,amount); shield-=absorbed; amount-=absorbed
	health=maxf(0,health-amount)
	apply_central_impulse(impulse.limit_length(150))
	if health<=0: disabled_time=1.6; throttle=0; boosting=false
	return true

func _collision(body: Node) -> void:
	if not body is PhysicsBody3D: return
	var relative = linear_velocity
	if body is RigidBody3D: relative-=body.linear_velocity
	if relative.length()>7: take_damage(minf(14,(relative.length()-7)*1.0))
