# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
const Rules=preload("royale_rules.gd")
const DURATION=660.0
const Storm=preload("storm_front.gd")
var game: Node3D
var final_index=0
var center=Vector2.ZERO
var radius=280.0
var next_center=Vector2.ZERO
var next_radius=200.0
var next_change=90.0
var phase=0
var storm: Node3D
var spectator=-1
var path_clock=0.0
var eliminations: Array=[]
func reset() -> void:
	if is_instance_valid(storm): storm.queue_free()
	storm=null; spectator=-1; path_clock=0; eliminations.clear()
	if not game.is_royale(): return
	final_index=posmod(game.conditions.seed_value+game.net.round_id,4)
	update_zone(0)
	storm=Storm.new(); storm.game=game; game.add_child(storm)
func update_zone(time: float) -> void:
	var final: Vector2=game.track.FINALS[final_index]
	var times=[0.0,90.0,210.0,270.0,390.0,450.0,540.0,570.0,630.0,660.0]
	var radii=[280.0,280.0,200.0,200.0,110.0,110.0,55.0,55.0,20.0,0.0]
	var shifts=[0.0,0.0,0.4,0.4,0.9,0.9,1.0,1.0,1.0,1.0]
	phase=0
	while phase<times.size()-2 and time>=times[phase+1]: phase+=1
	var blend=clampf((time-times[phase])/(times[phase+1]-times[phase]),0,1)
	center=final*lerpf(shifts[phase],shifts[phase+1],blend); radius=lerpf(radii[phase],radii[phase+1],blend)
	var target=mini(phase+2 if radii[phase]==radii[phase+1] else phase+1,times.size()-1)
	next_center=final*shifts[target]; next_radius=radii[target]; next_change=times[phase+1]
func outside(p: Vector3) -> float: return Vector2(p.x,p.z).distance_to(center)-radius
func alive() -> int: return game.cars.filter(func(c): return c.health>0).size()
func damage_rate() -> float: return 2.0+float(phase)*0.65
func tick_before(delta: float) -> void:
	update_zone(game.elapsed); path_clock-=delta
	if path_clock<=0:
		path_clock=1
		for id in game.track.graph.get_point_ids():
			var p: Vector3=game.track.graph.get_point_position(id)
			game.track.graph.set_point_weight_scale(id,1+maxf(0,outside(p)+10)*0.12)
	for car in game.cars:
		if car.health<=0: continue
		if outside(car.position)>0 or game.elapsed>=DURATION or (game.track.wet_channel(car.position) and car.position.y<10 and not game.track.on_bridge(car.position)):
			# Storm damage bypasses repair/recovery immunity and shield; no invulnerability camping.
			var loss=minf(car.health,(damage_rate() if game.elapsed<DURATION else 30.0)*delta)
			car.health-=loss; game.arena.damaged(car,-1,loss)
func tick_after() -> bool:
	var eliminated: Array=[]
	for car in game.cars:
		if car.health<=0 and game.arena.rules.places[car.index]==0:
			eliminated.append(car.index)
			eliminations.append({"slot":car.index,"time":snappedf(game.elapsed,0.1),"position":str(car.position),"last_attacker":game.arena.rules.ledger[car.index][-1].source if not game.arena.rules.ledger[car.index].is_empty() else -1})
	game.arena.rules.eliminate(eliminated,game.elapsed)
	if alive()<=1:
		game.arena.rules.finish(); game.finish_race(); return true
	return false
func safe_goal(car: Node3D,goal: Vector3) -> Vector3:
	var projected=Vector2(goal.x,goal.z)
	var target_center=next_center if next_change-game.elapsed<35 else center
	var target_radius=next_radius if next_change-game.elapsed<35 else radius
	if projected.distance_to(target_center)<target_radius-18 and outside(car.position)< -12: return goal
	var offset=Vector2.from_angle(car.index*TAU/16)*minf(22,maxf(0,target_radius-12)*0.5)
	var p=Vector3(target_center.x+offset.x,0,target_center.y+offset.y); p.y=game.track.height_at(p)
	return game.track.graph.get_point_position(game.track.graph.get_closest_point(p))
func escape_goal(car: Node3D,enemy: Node3D) -> Vector3:
	var away: Vector3=(car.position-enemy.position).normalized(); away.y=0
	var best=car.position; var score=-INF
	for angle in [-1.2,-0.6,0.0,0.6,1.2]:
		var target=car.position+away.rotated(Vector3.UP,angle)*38; target.y=game.track.height_at(target)
		target=game.track.graph.get_point_position(game.track.graph.get_closest_point(target))
		var cover=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(enemy.position+Vector3.UP,target+Vector3.UP,1))
		var value=target.distance_to(enemy.position)+(25 if not cover.is_empty() else 0)-maxf(0,outside(target)+15)*3
		if value>score: score=value; best=target
	return best
func can_see(observer: Node3D,target: Node3D) -> bool:
	var distance: float=observer.position.distance_to(target.position)
	var in_fog=outside(observer.position)>-8 or outside(target.position)>-8
	if distance>(24.0 if in_fog else 60.0): return false
	var hit=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(observer.position+Vector3.UP*0.6,target.position+Vector3.UP*0.3,1))
	return hit.is_empty()
func focus() -> Node3D:
	if game.player().health>0: return game.player()
	if spectator<0 or spectator>=game.cars.size() or game.cars[spectator].health<=0: cycle_spectator(1)
	return game.cars[spectator] if spectator>=0 else game.player()
func cycle_spectator(step: int) -> void:
	for offset in range(1,game.cars.size()+1):
		var slot=posmod(maxi(spectator,0)+offset*step,game.cars.size())
		if game.cars[slot].health>0: spectator=slot; return
	spectator=-1
func snapshot() -> Array: return [final_index,game.arena.rules.places.duplicate()]
static func valid_state(value,combat: Dictionary) -> bool:
	if not value is Array or value.size()!=2 or not preload("race_wire.gd").integer(value[0],0,3) or not value[1] is Array or value[1].size()!=16: return false
	for i in 16:
		if not preload("race_wire.gd").integer(value[1][i],0,16): return false
		if value[1][i]>1 and combat.scores[i][3]!=1: return false
		if combat.scores[i][3]>1 or combat.scores[i][4]!=0: return false
	return true
func apply_snapshot(value: Array) -> void:
	final_index=int(value[0]); game.arena.rules.places.assign(value[1]); update_zone(game.elapsed)
func visual_update(delta: float) -> void:
	if is_instance_valid(storm) and DisplayServer.get_name()!="headless": storm.update(delta)
