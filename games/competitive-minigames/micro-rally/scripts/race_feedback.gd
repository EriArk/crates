# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
# Observe the same authoritative car state in solo, host and replica views.
var previous: Dictionary = {}
var clock = 0.0

func reset() -> void:
	previous.clear(); clock=0

func update(game: Node, delta: float) -> void:
	if game.state not in ["race","countdown"]: return
	clock+=delta
	var trail=clock>=0.075
	if trail: clock=0
	for car in game.cars:
		var id=car.get_instance_id()
		var now={"health":car.health,"shield":car.shield,"ghost":car.ghost_time,"grounded":car.grounded,"vertical":car.linear_velocity.y}
		var before: Dictionary=previous.get(id,now)
		previous[id]=now
		var distance=car.position.distance_to(game.player().position)
		if distance>=45: continue
		if now.grounded and not before.grounded and before.vertical< -3:
			game.sound.play_event("impact0",distance)
			game.effects.dust(car,game.current_wetness)
		if now.health<before.health:
			if now.health<=0:
				game.effects.wreck(car.position); game.sound.play_event("wreck",distance)
			else:
				game.effects.burst(car.position+Vector3.UP*0.4,Color("ffc069"))
				game.sound.play_event("impact0" if car.index%2==0 else "impact1",distance)
		if now.shield>before.shield or now.shield<before.shield-3.0:
			game.effects.ring(car.position,Color("68dfff"))
			game.sound.play_event("shield",distance)
		if now.ghost>before.ghost+0.5:
			game.effects.ring(car.position,Color("b3f4ff"))
		if trail and car.finish_time<0 and car.disabled_time<=0 and car.ghost_time<=0:
			if car.boosting and car.boost>0 and (car.throttle>0 or car.replica): game.effects.exhaust(car)
			if car.grounded and absf(car.linear_velocity.dot(car.transform.basis.x))>2.8:
				game.effects.skid(car,game.track)
			else: game.effects.end_skid(car)
		elif trail: game.effects.end_skid(car)
