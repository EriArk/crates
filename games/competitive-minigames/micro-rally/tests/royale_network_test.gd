# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Wire=preload("res://scripts/race_wire.gd")
var failures=0
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func admit(game,seat: int) -> void:
	var bridge=game.net.bridge; bridge.disconnect_host(); bridge.registered=true; bridge.set_process(false)
	var members=[]; var links=[]
	for i in 16: members.append({"id":"p"+str(i),"seat":i+1,"connected":true})
	if seat==0:
		for i in range(1,16): links.append({"peer":"p"+str(i),"channel":"g"+str(i)})
	else: links=[{"peer":"p0","channel":"host"}]
	bridge._packet({"event":"network.ready","session":{"protocol":"micro-rally.7","delivery":"reliable-ordered","host":seat==0,"self":"p"+str(seat),"hostMember":"p0","members":members,"channels":links,"maxBytes":16384,"window":64}})
func run() -> void:
	var game=load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	game.set_physics_process(false); game.net.set_process(false)
	admit(game,0)
	check(game.net.phase=="waiting" and game.hud.menu_mode=="network_setup","Host chooses the event inside the existing lobby session")
	game.net.select_event("royale")
	check(game.is_arena() and game.state=="network_wait" and game.cars.size()==16,"Host prepares the real arena with the admitted roster")
	var prepare=JSON.parse_string(Marshalls.base64_to_raw(game.net.bridge.records[0].data).get_string_from_utf8())
	check(prepare.track==game.Tracks.ROYALE and prepare.mode=="royale" and prepare.rules==1,"Prepare identifies arena, mode and rules")
	for i in range(1,16): game.net._receive("p"+str(i),{"type":"ready","round":1})
	check(game.state=="countdown","All-ready starts one arena countdown")
	game.net._receive("p15",{"type":"input","round":1,"seq":1,"values":[0,0,0,700,0,0,0,0,0,1,1]})
	game.cars[15].ammo=3; game.net.apply_remote(game.cars[15])
	check(game.cars[15].throttle==0.7 and game.cars[15].assist_level==1 and game.cars[15].weapon_selected,"Authenticated seat input includes bounded assistance and weapon choice")
	var packet={"type":"state","round":1,"seq":1,"phase":"race","ms":5000,"countdown":0,"cars":game.cars.map(Wire.car_state),"pickups":game.pickups.map(func(_p): return 0),"beams":[],"arena":game.arena.snapshot(),"royale":game.royale.snapshot()}
	packet.arena.scores[15]=[9,3,0,0,0]
	packet.royale[1][15]=1
	for i in 15: packet.arena.scores[i][3]=1; packet.royale[1][i]=i+2; packet.cars[i][8]=0
	packet.cars[0][15]=3000
	check(game.arena.valid_state(packet.arena) and Wire.valid_snapshot(packet,16),"Sixteen-car arena packet validates")
	var invalid=packet.royale.duplicate(true); invalid[1][0]=17
	check(not game.royale.valid_state(invalid,packet.arena),"Invalid placement rejected")
	print("ROYALE PACKET bytes=",JSON.stringify(packet).to_utf8_buffer().size())
	check(JSON.stringify(packet).to_utf8_buffer().size()<16384,"Combat packet fits the existing SDK record budget")
	var bad=packet.arena.duplicate(true); bad.weapons[0][1]=999
	check(not game.arena.valid_state(bad),"Forged weapon inventory is rejected")
	bad=packet.arena.duplicate(true); bad.rockets=[[1,0,0,0,0],[1,0,0,0,0]]
	check(not game.arena.valid_state(bad),"Duplicate projectile identities are rejected")
	game.return_menu(); admit(game,15); game.net._receive("p0",prepare); game.net._receive("p0",{"type":"begin","round":1})
	check(game.is_arena() and game.player_index==15 and game.cars.all(func(c): return c.replica),"Client loads agreed map and never simulates authoritative cars")
	game.net._receive("p0",packet); game.net.apply_targets(1,true)
	check(game.arena.rules.rows[15].score==9 and game.standings()[0]==game.player(),"Client standings use host combat score")
	game.network_pause(); check(not paused and game.net.overlay,"Online battle keeps running under menu")
	game.resume_race(); packet.seq=2; packet.ms=660000; packet.phase="results"; game.net._receive("p0",packet)
	check(game.state=="results" and game.hud.menu_mode=="results","Authoritative battle result reaches normal results screen")
	game.net.rematch(); prepare.round=2; game.net._receive("p0",prepare)
	check(game.net.round_id==2 and game.arena.rules.rows[15].score==0,"Arena rematch clears combat state")
	game.return_menu(); admit(game,15); prepare.round=1; prepare.track="unknown-map"; game.net._receive("p0",prepare)
	check(not game.net.online,"Unknown map cannot start a mismatched session")
	await preload("audio_drain.gd").dispose(game,self)
	print("ROYALE NETWORK TEST failures=",failures); quit(1 if failures else 0)
