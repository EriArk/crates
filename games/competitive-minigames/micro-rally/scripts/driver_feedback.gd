# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
# Authoritative progress is shared by solo, host and replicas. Hysteresis excludes
# start-grid sorting, equal-progress jitter and recoveries from overtake reactions.
var opponents: Dictionary = {}
var player_id=0
var player_reset=-1
var previous_vertical=0.0
var previous_grounded=true
var bounce=0.0
var bounce_velocity=0.0
var steering=0.0
var yaw=0.0
var throttle=0.0
var brake=0.0
var last_elapsed=-1.0

func reset() -> void:
	opponents.clear(); player_id=0; player_reset=-1; last_elapsed=-1
	bounce=0; bounce_velocity=0; previous_vertical=0; steering=0; yaw=0; throttle=0; brake=0

func motion(delta: float, steer: float, vertical: float, grounded: bool, discontinuity: bool) -> void:
	var dt=clampf(delta,0,0.05)
	if discontinuity:
		bounce=0; bounce_velocity=0; previous_vertical=vertical; previous_grounded=grounded
	steering=lerpf(steering,clampf(steer,-1,1),1-exp(-10*dt))
	var target=signf(steering)*lerpf(15,35,absf(steering)) if absf(steering)>0.06 else 0.0
	yaw=lerpf(yaw,-deg_to_rad(target),1-exp(-8*dt))
	if not discontinuity:
		var impulse=clampf((vertical-previous_vertical)*0.012,-0.08,0.10)
		if grounded and not previous_grounded: impulse+=clampf(-previous_vertical*0.012,0,0.14)
		bounce_velocity+=impulse
	bounce_velocity+=(-110*bounce-12*bounce_velocity)*dt
	bounce=clampf(bounce+bounce_velocity*dt,-0.018,0.045)
	previous_vertical=vertical; previous_grounded=grounded

func observe(game: Node, delta: float) -> String:
	if game.state=="pause": return ""
	if game.state not in ["race","countdown"]:
		opponents.clear(); last_elapsed=-1; return ""
	var car=game.player()
	var changed=player_id!=car.get_instance_id() or player_reset!=car.reset_serial or game.elapsed<last_elapsed
	player_id=car.get_instance_id(); player_reset=car.reset_serial; last_elapsed=game.elapsed
	if changed: opponents.clear()
	throttle=lerpf(throttle,clampf(car.throttle,0,1),1-exp(-16*minf(delta,0.05)))
	brake=lerpf(brake,clampf(car.brake,0,1),1-exp(-16*minf(delta,0.05)))
	motion(delta,-car.physics.steer/0.62,car.linear_velocity.y,car.grounded,changed or car.ghost_time>0)
	var enabled=game.state=="race" and game.elapsed>2 and car.ghost_time<=0 and car.finish_time<0 and car.disabled_time<=0
	var reaction=""; var alive: Dictionary={}
	for other in game.cars:
		if other==car: continue
		var id=other.get_instance_id(); alive[id]=true
		var separation=other.passed-car.passed
		var side=1 if separation>1.5 else -1 if separation< -1.5 else 0
		var entry: Dictionary=opponents.get(id,{"side":side,"candidate":side,"time":0.0,"reset":other.reset_serial})
		if not enabled or other.reset_serial!=entry.reset or other.ghost_time>0 or other.disabled_time>0 or other.finish_time>=0:
			entry={"side":side,"candidate":side,"time":0.0,"reset":other.reset_serial}
		elif side!=0:
			if entry.side==0: entry.side=side
			if entry.candidate!=side: entry.candidate=side; entry.time=0.0
			entry.time+=minf(delta,0.1)
			if side!=entry.side and entry.time>=0.35:
				reaction="happy" if side<entry.side else "sad"
				entry.side=side; entry.time=0
		opponents[id]=entry
	for id in opponents.keys():
		if not alive.has(id): opponents.erase(id)
	return reaction
