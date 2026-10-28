# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
const Rules=preload("arena_rules.gd")
const Aim=preload("aim_assist.gd")
const Art=preload("art.gd")
var rules=Rules.new()
var game: Node3D
var rockets: Array=[]
var next_rocket=0
var assist_level=1
func load_settings() -> void:
	var config=ConfigFile.new()
	if config.load("user://arena-controls.cfg")==OK: assist_level=clampi(int(config.get_value("input","assist",1)),0,2)
func change_assist(step: int) -> void:
	assist_level=posmod(assist_level+step,3)
	var config=ConfigFile.new(); config.set_value("input","assist",assist_level); config.save("user://arena-controls.cfg")
	game.hud.menu("controls")
func reset() -> void:
	for rocket in rockets: rocket.node.queue_free()
	rockets.clear(); next_rocket=0; rules.reset(game.cars.size())
func hurt(car: Node3D, amount: float, impulse: Vector3, point: Vector3, attacker: int=-1) -> void:
	car.take_damage(amount,impulse,point,attacker)
func damaged(car: Node3D, attacker: int, amount: float) -> void:
	if game.state=="race": rules.damage(car.index,attacker,amount,game.elapsed)
func recovery_pose(car: Node3D, respawn: bool) -> Variant:
	var best: Variant=null; var best_score=-INF
	var candidates: Array=[]
	if respawn:
		for i in 16: candidates.append(game.track.spawn_pose((i+car.index)%16))
	else:
		for id in game.track.graph.get_point_ids():
			candidates.append(Transform3D(Basis(Vector3.UP,atan2(-car.last_forward.x,-car.last_forward.z)),game.track.graph.get_point_position(id)+Vector3.UP*0.9))
	for pose in candidates:
		var nearest=INF; var visible=0
		for other in game.cars:
			if other==car or other.health<=0: continue
			var other_pos: Vector3=other.reset_pose.origin if other.reset_pending else other.position
			nearest=minf(nearest,other_pos.distance_to(pose.origin))
			if other_pos.distance_to(pose.origin)<34:
				var query=PhysicsRayQueryParameters3D.create(pose.origin,other_pos,1)
				if game.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): visible+=1
		if nearest<8: continue
		var score=minf(nearest,50)-visible*12 if respawn else -car.position.distance_to(pose.origin)
		if score>best_score: best_score=score; best=pose
	return best
func recover(car: Node3D) -> bool:
	if car.health<=0 or car.reset_pending or car.recovery_lock>0: return false
	var outside=not game.track.map_bounds.has_point(Vector2(car.position.x,car.position.z)) or car.position.y< -4
	if not outside and car.overturned_time<0.5 and car.stuck_time<2: return false
	# A recovery is an escape manoeuvre, never a repair or a way to erase damage credit.
	var pose=recovery_pose(car,false)
	if pose==null: return false
	car.reset_at(pose,false); car.recovery_count+=1
	return true
func tick(delta: float) -> void:
	if game.state=="race": game.elapsed+=delta
	game._update_conditions(game.elapsed)
	for car in game.cars:
		if car.health<=0:
			if game.state!="race": continue
			var previous_kills: int=rules.rows[game.player_index].kills
			if rules.wreck(car.index,game.elapsed):
				car.freeze=true; car.collision_layer=0; game.controls.neutral(car)
				if rules.rows[game.player_index].kills>previous_kills: game.hud.portrait.set_mood("victory")
			car.disabled_time=maxf(0.1,3-(game.elapsed-rules.death_time[car.index]))
			if game.elapsed-rules.death_time[car.index]>=3:
				var pose=recovery_pose(car,true)
				if pose!=null:
					car.health=100; car.shield=0; car.shield_item=true; car.disabled_time=0; car.cool_weapon()
					car.ammo=0; car.weapon_selected=false; car.boost=100; car.reset_at(pose); car.freeze=false; rules.revived(car.index)
			continue
		if game.net.online and car.human and not car.local_player: game.net.apply_remote(car)
		elif car.local_player and game.net.online and game.net.overlay: game.controls.neutral(car)
		elif car.local_player and game.state=="race" and not game.demo_auto: game.controls.read(car,game.camera)
		else: car.bot_drive(game.cars,delta); car.bot.combat(car,game.cars,delta)
		car.tick(delta)
		if car.overturned_time>2 or car.stuck_time>4 or not game.track.map_bounds.grow(5).has_point(Vector2(car.position.x,car.position.z)) or car.position.y< -5: recover(car)
		if car.firing and game.state=="race": shoot(car)
	if game.state=="race":
		update_rockets(delta)
		if game.elapsed>=Rules.DURATION: game.finish_race(); return
		game.hud.message=rules.feed if game.elapsed<rules.feed_time else ""
	for pickup in game.pickups:
		pickup.cooldown=maxf(0,pickup.cooldown-delta); pickup.node.visible=pickup.cooldown<=0; pickup.node.rotation.y+=delta
		if pickup.cooldown>0: continue
		for car in game.cars:
			if car.health<=0 or car.ghost_time>0 or car.immune>0 or car.position.distance_to(pickup.node.position)>2.6: continue
			match pickup.kind:
				"repair":
					if car.health>=100 and car.missing_wheels==0: continue
					var amount=minf(40,100-car.health); car.health+=amount; car.repair_wheels(); rules.repair(car.index,amount)
				"shield":
					if car.shield_item: continue
					car.shield_item=true
				"cool":
					if car.weapon_heat<10: continue
					car.cool_weapon()
				_:
					if car.ammo>0: continue
					car.weapon=pickup.kind; car.ammo=3 if pickup.kind=="rocket" else 2; car.weapon_selected=true
			car.bot.pickups_collected+=1; pickup.cooldown=8
			game.effects.ring(pickup.node.position,Color("f6cc54")); game.sound.play_event("pickup",car.position.distance_to(game.player().position)); break
func shoot(car: Node3D) -> void:
	if not car.weapon_selected or car.ammo<=0: game._shoot(car); return
	if car.replica or car.health<=0 or car.disabled_time>0 or car.fire_cooldown>0 or car.ghost_time>0 or car.immune>0: return
	if car.weapon=="rocket" and rockets.size()>=32: return
	car.fire_cooldown=0.8; car.ammo-=1
	if car.ammo==0: car.weapon_selected=false
	var direction=Aim.resolve(car,game.cars,car.assist_level if car.human or car.local_player and not game.demo_auto else 0)
	if car.weapon=="pulse":
		game.effects.ring(car.position,Color("5ce9ff"))
		for other in game.cars:
			if other==car: continue
			var diff: Vector3=other.position-car.position
			if diff.length()>11: continue
			var hit=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(car.position,other.position,1))
			if hit.is_empty(): hurt(other,32,diff.normalized()*150,other.position,car.index)
		game.net.shot(car,car.position,car.position+Vector3(0.01,3,0))
	else:
		var node=Art.box(game,Vector3(0.24,0.24,0.8),car.position+Vector3.UP*0.6,Color("ffcc56"))
		node.look_at(node.position+direction,Vector3.UP); next_rocket+=1
		rockets.append({"id":next_rocket,"owner":car.index,"node":node,"velocity":direction*42,"life":1.6})
	game.sound.play_event("shot",car.position.distance_to(game.player().position))
func update_rockets(delta: float) -> void:
	for i in range(rockets.size()-1,-1,-1):
		var rocket: Dictionary=rockets[i]; var from: Vector3=rocket.node.position; var to: Vector3=from+rocket.velocity*delta
		rocket.life-=delta
		var hit=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,3,[game.cars[rocket.owner].get_rid()]))
		if not hit.is_empty() or rocket.life<=0:
			var pos: Vector3=hit.position if not hit.is_empty() else to
			game.effects.wreck(pos); game.sound.play_event("wreck",pos.distance_to(game.player().position))
			for car in game.cars:
				var diff: Vector3=car.position-pos; var distance=diff.length()
				if distance>6: continue
				var wall=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(pos-rocket.velocity.normalized()*0.15,car.position,1))
				if wall.is_empty(): hurt(car,48*(1-distance/7),diff.normalized()*130,car.position,rocket.owner)
			game.net.shot(game.cars[rocket.owner],pos,pos+Vector3(0.01,2,0))
			rocket.node.queue_free(); rockets.remove_at(i)
		else: rocket.node.position=to
func snapshot() -> Dictionary:
	return {"scores":rules.rows.map(func(r): return [r.score,r.kills,r.assists,r.deaths,r.life]),"weapons":game.cars.map(func(c): return [1 if c.weapon=="rocket" else 2,c.ammo,1 if c.weapon_selected else 0]),"rockets":rockets.map(func(r): return [r.id,r.owner,roundi(r.node.position.x*100),roundi(r.node.position.y*100),roundi(r.node.position.z*100)])}
static func valid_state(data) -> bool:
	if not data is Dictionary or not data.get("scores") is Array or data.scores.size()!=16 or not data.get("weapons") is Array or data.weapons.size()!=16 or not data.get("rockets") is Array or data.rockets.size()>32: return false
	var ids=[]
	for key in ["scores","weapons","rockets"]:
		for row in data[key]:
			var bounds=[[ -1000,10000],[0,2000],[0,2000],[0,2000],[0,2000]] if key=="scores" else [[1,2],[0,3],[0,1]] if key=="weapons" else [[0,2147483647],[0,15],[-30000,30000],[-10000,10000],[-30000,30000]]
			if not row is Array or row.size()!=bounds.size(): return false
			for i in row.size():
				if not preload("race_wire.gd").integer(row[i],bounds[i][0],bounds[i][1]): return false
			if key=="rockets":
				if ids.has(row[0]): return false
				ids.append(row[0])
	return true
func apply_snapshot(data: Dictionary) -> void:
	for i in data.scores.size():
		var s: Array=data.scores[i]
		if s[1]>rules.rows[i].kills:
			rules.feed=game.cars[i].driver_title()+" SCORED A KO"; rules.feed_time=game.elapsed+3
			if i==game.player_index: game.hud.portrait.set_mood("victory")
		rules.rows[i]={"slot":i,"score":s[0],"kills":s[1],"assists":s[2],"deaths":s[3],"life":s[4]}
		var car: Node3D=game.cars[i]; car.weapon="rocket" if data.weapons[i][0]==1 else "pulse"; car.ammo=data.weapons[i][1]
		if not car.local_player: car.weapon_selected=data.weapons[i][2]==1
	var live=[]
	for r in data.rockets:
		live.append(r[0]); var target=Vector3(r[2],r[3],r[4])/100
		var existing=rockets.filter(func(item): return item.id==r[0])
		if not existing.is_empty():
			var rocket: Dictionary=existing[0]
			rocket.target=target
		else:
			var node=Art.box(game,Vector3(0.3,0.3,0.8),target,Color("ffcc56"))
			rockets.append({"id":r[0],"owner":r[1],"node":node,"target":target})
	for i in range(rockets.size()-1,-1,-1):
		if not live.has(rockets[i].id):
			game.effects.burst(rockets[i].node.position,Color("ffc655"))
			rockets[i].node.queue_free(); rockets.remove_at(i)
func display_client(delta: float) -> void:
	for rocket in rockets:
		var diff: Vector3=rocket.target-rocket.node.position
		if diff.length_squared()>0.01: rocket.node.look_at(rocket.target,Vector3.UP)
		rocket.node.position=rocket.node.position.lerp(rocket.target,1-exp(-delta*30))
	game.hud.message=rules.feed if game.elapsed<rules.feed_time else ""
