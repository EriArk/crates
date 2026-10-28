# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Wire = preload("res://scripts/race_wire.gd")
const Client = preload("res://addons/traineros/group_client.gd")
var failures = 0
func check(ok: bool, label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func roster(count: int) -> Array:
	var result: Array=[]
	for i in count: result.append({"id":"p"+str(i),"seat":i+1,"connected":true})
	return result
func admitted(client, self_id: String, count: int) -> void:
	client.disconnect_host(); client.registered=true
	var links: Array=[]
	if self_id=="p0":
		for i in range(1,count): links.append({"peer":"p"+str(i),"channel":"g"+str(i)})
	else: links.append({"peer":"p0","channel":"host"})
	client._packet({"event":"network.ready","session":{"protocol":"micro-rally.4","delivery":"reliable-ordered","host":self_id=="p0","self":self_id,"hostMember":"p0","members":roster(count),"channels":links,"maxBytes":16384,"window":64}})
func run() -> void:
	var game=load("res://main.tscn").instantiate(); root.add_child(game); await process_frame; await process_frame
	var bridge=game.net.bridge; bridge.set_process(false)
	game.cycle_track()
	check(game.current_track==game.Tracks.QUARRY,"Solo selection can start on Quarry before a lobby invitation")
	game.cup.store.set_bot_settings("quick",game.BotSettings.preset(2))
	admitted(bridge,"p0",16)
	check(game.net.online and game.state=="network_wait" and game.player_index==0,"Sixteen admitted players wait for common start")
	check(game.current_track==Wire.TRACK and game.laps==4 and game.race_limit_seconds==600,"Network prepare loads its agreed Valley, not the previous solo track")
	check(game.net.bot_settings==game.BotSettings.preset(2) and game.race_bots==game.net.bot_settings,"Host admits selected difficulty into shared round")
	game.cup.store.set_bot_settings("quick",game.BotSettings.preset(0))
	check(game.net.bot_settings==game.BotSettings.preset(2),"Later local preference cannot mutate admitted round")
	for i in range(1,15): game.net._receive("p"+str(i),{"type":"ready","round":1})
	check(game.state=="network_wait","One missing ready prevents early start")
	game.net._receive("p15",{"type":"ready","round":1})
	check(game.state=="countdown" and game.net.phase=="playing","All ready starts shared countdown")
	game.net._receive("p15",{"type":"input","round":1,"seq":0,"values":[1000,0,0,750,0,0,0,0,0]})
	game.net.apply_remote(game.cars[15]); game.net.apply_remote(game.cars[14])
	check(game.cars[15].steer_input==1 and game.cars[15].throttle==0.75 and game.cars[14].throttle==0,"Sender controls only its admitted seat")
	game.net.inputs.p15.at=Time.get_ticks_msec()-1000; game.net.apply_remote(game.cars[15])
	check(game.cars[15].throttle==0,"Expired input releases throttle")
	game.net._receive("p15",{"type":"state","round":1,"seq":1})
	check(not game.net.online and game.state=="menu","Client cannot forge authority state")
	admitted(bridge,"p15",16)
	check(game.player_index==15,"Local camera/control seat comes from membership, not host flag")
	game.net._receive("p0",{"type":"prepare","round":1,"track":Wire.TRACK,"conditions":game.conditions.descriptor(),"laps":4})
	check(game.race_bots==game.BotSettings.preset(),"Legacy host without bot descriptor retains ordinary difficulty")
	game.net._receive("p0",{"type":"begin","round":1})
	check(game.cars.all(func(c): return c.replica and c.freeze),"Only host simulates authoritative physics")
	var snapshot={"type":"state","round":1,"seq":1,"phase":"race","ms":5000,"countdown":0,"cars":game.cars.map(Wire.car_state),"pickups":game.pickups.map(func(_p): return 0),"beams":[]}
	check(Wire.valid_snapshot(snapshot,game.pickups.size()),"Bounded full state validates")
	game.net._receive("p0",snapshot)
	check(game.elapsed==5 and game.state=="race","Client accepts host time and phase")
	snapshot.cars[15][39]=4; snapshot.cars[15][40]=5760; snapshot.cars[15][41]=80; snapshot.cars[15][42]=0
	snapshot.cars[15][13]=350; snapshot.cars[15][12]=8|32; snapshot.cars[15][11]=91
	game.net.apply_targets(1.0,true)
	check(game.player().checkpoint==30 and game.player().ghost_time>0,"Replica restores lap checkpoint and recovery visuals")
	check(game.player().weapon_heat==91 and game.player().overheated,"Replica restores host heat and overheat lock")
	check(game.player().transmission.gear==4 and game.player().transmission.rpm==5760 and game.player().transmission.shift_left==0.08,"Replica instruments use authoritative gear, rpm and shift")
	var invalid_gear=snapshot.duplicate(true); invalid_gear.cars[15][39]=6
	check(not Wire.valid_snapshot(invalid_gear,game.pickups.size()),"Invalid gear rejected")
	invalid_gear=snapshot.duplicate(true); invalid_gear.cars[15][40]=8001
	check(not Wire.valid_snapshot(invalid_gear,game.pickups.size()),"Invalid rpm rejected")
	var invalid_heat=snapshot.duplicate(true); invalid_heat.cars[15][11]=101
	check(not Wire.valid_snapshot(invalid_heat,game.pickups.size()),"Out-of-range heat is rejected")
	var rotated=Quaternion(Vector3.FORWARD,1.9)
	snapshot.cars[15][16]=roundi(rotated.x*10000); snapshot.cars[15][17]=roundi(rotated.y*10000)
	snapshot.cars[15][18]=roundi(rotated.z*10000); snapshot.cars[15][19]=roundi(rotated.w*10000)
	snapshot.cars[15][23]=1; snapshot.cars[15][38]=14; snapshot.cars[15][24]=9
	snapshot.cars[15][26]=400; snapshot.cars[15][25]=-320
	game.net.apply_targets(1.0,true)
	check(game.player().basis.y.y<0 and game.player().missing_wheels==1 and game.player().reset_serial==9,"Replica restores roll, missing wheel and recovery generation")
	check(is_equal_approx(game.player().physics.wheels[0].length,0.4),"Replica restores suspension travel")
	var wheel_count=game.effects.loose_wheels.size()
	game.net.apply_targets(1.0,true)
	check(game.effects.loose_wheels.size()==wheel_count,"Repeated snapshot does not replay wheel separation")
	var invalid_rotation=snapshot.duplicate(true); invalid_rotation.cars[15][19]=10000
	check(not Wire.valid_snapshot(invalid_rotation,game.pickups.size()),"Non-unit orientation is rejected")
	var invalid_contact=snapshot.duplicate(true); invalid_contact.cars[15][38]=15
	check(not Wire.valid_snapshot(invalid_contact,game.pickups.size()),"Missing wheel cannot claim ground contact")
	check(JSON.stringify(snapshot).to_utf8_buffer().size()<16384,"Full 16-car 3D state fits SDK packet budget")
	game.weather.update_headlights(game.cars,1.0,15)
	check(game.weather.light_cars[0]==game.player(),"Headlight budget follows local seat fifteen")
	game.net._receive("p0",{"type":"input","round":0,"values":[]})
	check(game.net.online,"Delayed previous-round input is ignored")
	game.network_pause(); check(not paused and game.net.overlay,"Online menu does not pause shared simulation")
	game.resume_race(); check(not game.net.overlay and game.controls.neutral_required,"Online resume requires released controls")
	var bad=snapshot.duplicate(true); bad.seq=2; bad.cars[15][0]=NAN
	game.net._receive("p0",bad)
	check(not game.net.online,"Nonfinite snapshot is rejected atomically")
	admitted(bridge,"p1",2)
	game.net._receive("p0",{"type":"prepare","round":1,"track":Wire.TRACK,"conditions":game.conditions.descriptor(),"laps":4,"bots":game.BotSettings.preset(2)})
	check(game.race_bots==game.BotSettings.preset(2) and game.cars[2].bot.settings==game.race_bots,"Client adopts host difficulty for all bot seats, ignoring own easy preference")
	game.return_menu(); admitted(bridge,"p1",2)
	game.net._receive("p0",{"type":"prepare","round":1,"track":Wire.TRACK,"conditions":game.conditions.descriptor(),"laps":4,"bots":{"version":99}})
	check(not game.net.online,"Invalid host difficulty aborts before round starts")
	for invalid in [[],[0,0,0,1001,0,0],[0,0,0,1,0,16],[NAN,0,0,0,0,0]]: check(not Wire.valid_input(invalid),"Malformed controls rejected")
	var client=Client.new(); admitted(client,"p0",16)
	for n in 100:
		for peer in client.channels: check(client.send_latest(peer,"state",{"n":n}),"Latest-state queue accepts replacement")
	check(client.records.size()==15,"Congestion retains only one unsent snapshot per peer")
	for item in client.records: check(JSON.parse_string(Marshalls.base64_to_raw(item.data).get_string_from_utf8()).n==99,"Only newest unsent snapshot survives")
	client.pending["late"]={"method":"network.consume"}
	client.close_channel(); check(client.records.is_empty() and client.channels.is_empty(),"Closing revokes queued state and grants")
	client._packet({"id":"late","error":{"code":"channel_unavailable"}})
	client._packet({"event":"network.data","channel":"g1","peer":"p1","sequence":"0","data":""})
	check(client.registered,"Late closed-grant replies preserve SDK registration and avatar access")
	client.free(); await preload("audio_drain.gd").dispose(game,self)
	print("NETWORK TEST failures=",failures); quit(1 if failures else 0)
