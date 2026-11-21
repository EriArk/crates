# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures:=0
func check(ok: bool, label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game=load("res://main.tscn").instantiate()
	root.add_child(game); await process_frame
	game.net.platform_enabled=false
	game.bot_count=0; game.start_race(); game.state="race"; game.set_physics_process(false)
	var car=game.player()
	car.immune=0; car.ghost_time=0; car.freeze=true
	var first=game.pickups[0]; var crate=game.pickups[1]
	check(first.kind=="rocket" and crate.kind=="mystery" and first.node.position.distance_to(crate.node.position)>4.4,"First gate offers a readable lane choice")
	car.position=first.node.position
	game._physics_process(0.016)
	check(car.ammo==2 and car.weapon_selected and not first.node.visible and crate.node.visible,"Driving over the rocket crate equips it immediately")
	car.position=crate.node.position
	game._physics_process(0.016)
	check(crate.cooldown==0 and car.ammo==2,"Loaded slot preserves both ammunition and unclaimed crate")
	car.position=Vector3(0,45,0); car.aim=Vector3.FORWARD
	var wall=game.Art.collider(game,Vector3(10,8,1),car.position+Vector3.FORWARD*9)
	await physics_frame; await physics_frame
	game.arena.shoot(car)
	check(car.ammo==1 and game.arena.rockets.size()==1,"Race weapon dispatch creates a live rocket")
	for tick in 24: game.arena.update_rockets(1.0/60)
	check(game.arena.rockets.is_empty() and game.effects.particles.any(func(part):return part.has("wave")),"Rocket collides and triggers explosion")
	car.fire_cooldown=0; game.arena.shoot(car)
	check(car.ammo==0 and not car.weapon_selected,"Last round returns to machine gun")
	car.fire_cooldown=0; game.arena.shoot(car)
	check(car.weapon_heat>0 and game.effects.particles.any(func(part):return part.has("shape") and part.velocity.length()>40),"Ordinary gun emits a travelling tracer")
	car.position=crate.node.position; game._physics_process(0.016)
	check(car.ammo>0 and car.weapon in ["rocket","pulse"] and crate.cooldown>0,"Wild crate awards usable ammunition")
	car.boost=12; check(game.Supplies.collect(car,"boost") and car.boost==77,"Nitro refills the boost gauge")
	car.weapon_heat=97; car.overheated=true; check(game.Supplies.collect(car,"cool") and not car.overheated,"Coolant releases gun lockout")
	car.health=35; car.shield_item=false; check(game.Supplies.collect(car,"shield") and car.shield_item and car.health==55,"Pit shield repairs and stocks protection")
	check(game.arena.valid_state(game.arena.combat_snapshot(),false)==false,"Online combat validator requires sixteen seats")
	game.start_race()
	check(game.arena.rockets.is_empty() and game.player().ammo==0 and game.pickups.all(func(item):return item.cooldown==0),"Rematch clears inventory, missiles and gate cooldowns")
	wall.queue_free()
	print("RACE SUPPLIES failures=",failures)
	await preload("audio_drain.gd").dispose(game,self); quit(1 if failures else 0)
