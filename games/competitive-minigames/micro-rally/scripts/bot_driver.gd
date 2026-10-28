# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
# Bot decisions produce the same inputs as a person. No transform/speed injection.
const STYLES = ["Рейсер","Штурмовик","Тактик","Смельчак"]
var lane = 0.0
var decision_clock = 0.0
var reversing = 0.0
var decision_count = 0
var target_speed = 15.0
var desired_lane = 0.0
var lane_hold = 0.0
var combat_clock = 0.0
var opponent: Node3D
var clear_shot = false
var lane_changes = 0
var shots = 0
var pickups_collected = 0
var cooling_weapon = false

func drive(car: Node3D, others: Array, delta: float) -> void:
	var track = car.track; var style: int=car.index%4
	var speed: float=car.linear_velocity.length()
	decision_clock-=delta; lane_hold=maxf(0,lane_hold-delta)
	var at: int=track.nearest(car.position,car.checkpoint)
	# Look ahead in metres: longer tracks must not make the same sample count cut corners.
	var ahead: int=track.steps_ahead(at,clampf(7.0+speed*0.55,7,17))
	var target_at: int=(at+ahead)%track.COUNT
	var tangent: Vector3=track.tangents[target_at]
	var side = Vector3(-tangent.z,0,tangent.x)
	if decision_clock<=0:
		decision_clock=0.25; decision_count+=1
		var best_score = INF; var selected = desired_lane
		for candidate in [-2.8,0.0,2.8]:
			var score: float=absf(candidate-desired_lane)*0.25+absf(candidate-(float(car.index%3)-1)*2.8)*0.08
			if lane_hold>0 and absf(candidate-desired_lane)>1: score+=1.5
			var point: Vector3=track.points[target_at]+side*candidate
			for other in others:
				if other==car or other.finish_time>=0 or other.ghost_time>0: continue
				# Score the approach, not only the endpoint: an occupied passing gap stays unsafe.
				for horizon in [0.25,0.5,0.75]:
					var travel: float=minf(1.0,maxf(speed,6)*horizon/maxf(1,car.position.distance_to(point)))
					var own: Vector3=car.position.lerp(point,travel)
					var predicted: Vector3=other.position+other.linear_velocity*horizon
					var distance: float=Vector2(own.x-predicted.x,own.z-predicted.z).length()
					if distance<3.4: score+=(3.4-distance)*4.0
			var ray = PhysicsRayQueryParameters3D.create(car.position,point+Vector3.UP*0.65,1)
			var hit: Dictionary=car.get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty() and absf(hit.normal.y)<0.5: score+=12.0
			for item in car.get_parent().pickups:
				if item.cooldown>0: continue
				var useful: bool=(item.shield and (not car.shield_item or car.health<80)) or (not item.shield and car.weapon_heat>50)
				if useful and point.distance_to(item.node.position)<3.5: score-=1.2
			if score<best_score: best_score=score; selected=candidate
		if selected!=desired_lane: lane_changes+=1; lane_hold=0.75
		desired_lane=selected
	lane=move_toward(lane,desired_lane,delta*3.6)
	var target: Vector3=track.points[target_at]+side*lane
	car.desired=target-car.position; car.desired.y=0; car.desired=car.desired.normalized()
	var angle: float=absf(car.last_forward.signed_angle_to(car.desired,Vector3.UP))
	var bend = 0.0
	for n in [ahead,track.steps_ahead(at,20),track.steps_ahead(at,30)]:
		var next: int=(at+n)%track.COUNT
		var distance: float=maxf(2,track.points[at].distance_to(track.points[next]))
		bend=maxf(bend,absf(track.tangents[at].signed_angle_to(track.tangents[next],Vector3.UP))/distance)
	target_speed=clampf(sqrt((9.0+[0.0,0.3,-0.8,1.2][style])*car.surface_grip/maxf(bend,0.015)),8,19)
	if angle>0.6: target_speed=minf(target_speed,10.0)
	if angle>1.1: target_speed=6.0
	if car.offroad: target_speed=minf(target_speed,9.0)
	if car.missing_wheels!=0: target_speed=minf(target_speed,10.0)
	var rise: float=track.points[target_at].y-track.points[at].y
	if absf(rise)>1.0: target_speed=minf(target_speed,13.0)
	var blocked = false
	for other in others:
		if other==car or other.finish_time>=0 or other.ghost_time>0: continue
		var diff: Vector3=other.position-car.position
		var longitudinal: float=diff.dot(car.last_forward)
		var lateral: float=absf(diff.dot(Vector3(-car.last_forward.z,0,car.last_forward.x)))
		if longitudinal>0 and longitudinal<6.0 and lateral<1.8:
			blocked=true; target_speed=minf(target_speed,maxf(4,other.linear_velocity.length()-1))
	car.throttle=clampf((target_speed-speed)*0.5,0,1)
	car.brake=clampf((speed-target_speed)*0.3,0,0.9)
	car.handbrake=style==3 and angle>0.8 and speed>10 and car.surface_grip>0.9
	car.boosting=not blocked and bend<0.025 and angle<0.15 and speed>9 and car.boost>35 and style!=2
	car.firing=false
	if reversing<=0 and car.grounded and car.stuck_time>1.1: reversing=0.7
	if reversing>0:
		reversing-=delta; car.throttle=0; car.brake=1; car.boosting=false; car.handbrake=false
		# Yaw follows actual reverse motion through the ordinary steering model.
		car.desired=-car.desired

	car.steer_towards(car.desired)

func combat(car: Node3D, others: Array, delta: float) -> void:
	car.firing=false
	combat_clock-=delta
	if combat_clock<=0:
		combat_clock=0.2; clear_shot=false
		var selected: Node3D=null; var best_score = INF
		for other in others:
			if other==car or other.finish_time>=0 or other.ghost_time>0 or other.disabled_time>0: continue
			var diff: Vector3=other.position-car.position; var distance = diff.length()
			if distance>25 or absf(diff.y)>3: continue
			var score: float=distance-(4.0 if other==opponent else 0.0)
			if score<best_score: selected=other; best_score=score
		opponent=selected
		if is_instance_valid(opponent):
			var ray = PhysicsRayQueryParameters3D.create(car.position+Vector3.UP*0.2,opponent.position+Vector3.UP*0.2,3,[car.get_rid()])
			var hit: Dictionary=car.get_world_3d().direct_space_state.intersect_ray(ray)
			clear_shot=not hit.is_empty() and hit.collider==opponent
			var to_us: Vector3=(car.position-opponent.position).normalized()
			var threatened: bool=opponent.firing and opponent.aim.dot(to_us)>0.9
			if threatened or (car.health<65 and best_score<12): car.activate_shield()
	if not is_instance_valid(opponent): return
	var direction: Vector3=opponent.position-car.position; direction.y=0; direction=direction.normalized()
	var turn: float=car.aim.signed_angle_to(direction,Vector3.UP)
	car.aim=car.aim.rotated(Vector3.UP,clampf(turn,-2.4*delta,2.4*delta)).normalized()
	if car.weapon_heat>=[65.0,90.0,55.0,100.0][car.index%4] or car.overheated: cooling_weapon=true
	if car.weapon_heat<=25: cooling_weapon=false
	car.firing=clear_shot and absf(turn)<0.12 and not cooling_weapon
