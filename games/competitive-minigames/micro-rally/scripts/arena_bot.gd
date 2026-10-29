# SPDX-License-Identifier: GPL-3.0-or-later
extends "bot_driver.gd"
var route=PackedVector3Array()
var waypoint=0
var replan=0.0
var objective="hunt"
var retreat=0.0
var retreat_goal=Vector3.ZERO
func _init() -> void: vertical_range=16
func drive(car: Node3D, others: Array, delta: float) -> void:
	car.assist_level=0
	replan-=delta; retreat=maxf(0,retreat-delta)
	var speed: float=car.linear_velocity.length()
	if replan<=0 or waypoint>=route.size():
		replan=0.8+float(car.index%5)*0.07; decision_count+=1
		var goal=car.track.spawn_pose((car.index+decision_count)%16).origin
		var best=INF; objective="hunt"
		for other in others:
			if other==car or other.health<=0 or other.ghost_time>0: continue
			if car.get_parent().is_royale() and not car.get_parent().royale.can_see(car,other): continue
			var score: float=car.position.distance_to(other.position)
			if score<best: best=score; goal=other.position+other.linear_velocity*0.3
		if best<12:
			var away: Vector3=(car.position-goal).normalized()
			goal=car.position+away.rotated(Vector3.UP,0.7 if car.index%2==0 else -0.7)*12
			objective="flank"
		var supply_score=INF
		var supply_goal=goal
		for pickup in car.get_parent().pickups:
			if pickup.cooldown>0: continue
			var useful: bool=(pickup.kind=="repair" and car.health<60) or (pickup.kind in ["rocket","pulse"] and car.ammo==0) or (pickup.kind=="cool" and car.weapon_heat>70)
			var distance: float=car.position.distance_to(pickup.node.position)
			var priority=distance-(100 if pickup.kind=="repair" and car.health<40 else 0)
			if useful and priority<supply_score:
				supply_score=priority; supply_goal=pickup.node.position
		if supply_score<best*0.8: goal=supply_goal; objective="supply"
		if car.get_parent().is_royale():
			if retreat<=0 and car.health<68 and is_instance_valid(opponent) and car.position.distance_to(opponent.position)<32:
				retreat=7.0+car.index%4; retreat_goal=car.get_parent().royale.escape_goal(car,opponent)
			if retreat>0 and objective!="supply": goal=retreat_goal; objective="escape"
			goal=car.get_parent().royale.safe_goal(car,goal)
		route=car.track.path(car.position,goal); waypoint=1 if route.size()>1 else 0
	if route.is_empty(): car.throttle=0; car.brake=0.4; return
	while waypoint<route.size()-1 and car.position.distance_to(route[waypoint]+Vector3.UP*0.7)<6: waypoint+=1
	var direction: Vector3=route[waypoint]-car.position; direction.y=0
	car.desired=direction.normalized(); car.steer_towards(car.desired)
	var angle: float=absf(car.last_forward.signed_angle_to(car.desired,Vector3.UP))
	target_speed=(19.0 if objective=="hunt" else 16.0)*[0.82,1.0,1.10][int(settings.pace)]
	if angle>0.4: target_speed=minf(target_speed,9)
	if angle>1: target_speed=5
	for other in others:
		if other==car or other.health<=0: continue
		var diff: Vector3=other.position-car.position
		if diff.length()<5 and diff.dot(car.last_forward)>0 and objective!="hunt": target_speed=4
	car.throttle=clampf((target_speed-speed)*0.5,0,1); car.brake=clampf((speed-target_speed)*0.25,0,0.8)
	car.handbrake=angle>1 and speed>8; car.boosting=angle<0.12 and speed>8 and car.boost>50 and objective=="hunt"
	if car.stuck_time>0.8 and reversing<=0: reversing=1.1; replan=0
	if reversing>0:
		reversing-=delta; car.throttle=0; car.brake=1; car.steer_input=-car.steer_input; car.boosting=false; car.handbrake=false
	car.weapon_selected=car.ammo>0 and is_instance_valid(opponent) and car.position.distance_to(opponent.position)<(12 if car.weapon=="pulse" else 30)
