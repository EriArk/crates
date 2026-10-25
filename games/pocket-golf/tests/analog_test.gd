# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Match = preload("res://scripts/match.gd")
const Aim = preload("res://scripts/aim_input.gd")
var failures := 0
class Wire extends Match.Client:
	var peer
	var records: Array = []
	func send(data: Dictionary) -> bool:
		records.append(data.duplicate(true))
		if peer!=null: peer._receive_member(session.get("self","a"),JSON.parse_string(JSON.stringify(data)))
		return true
func check(ok: bool, label: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(Aim.response(Vector2(0.17,-0.17))==Vector2.ZERO,"dead zones prevent drift")
	check(Aim.response(Vector2(0.3,0)).x>0 and Aim.response(Vector2(0.3,0)).x<0.03,"small deflection is precise")
	var ui=load("res://main.tscn").instantiate(); root.add_child(ui)
	await process_frame
	ui.set_process(false); ui.game.set_process(false)
	ui._start_local(2); ui.game.accept_turn(); ui.neutral_required=false
	var hash_before: String = ui.game.world.digest()
	var results: Array = []
	for fps in [30,60,120]:
		ui.game.angle=0; ui.game.power=50
		for tick in fps: ui._aim_stick(Vector2(0.4,-0.5),1.0/fps)
		results.append(Vector2(ui.game.angle,ui.game.power))
	check(results[0].distance_to(results[1])<0.0001 and results[0].distance_to(results[2])<0.0001,"30/60/120 FPS identical rates")
	check(fmod(results[0].x,5)>0.1 and fmod(results[0].y,5)>0.1,"aim and power retain sub-step values")
	check(ui.game.world.digest()==hash_before,"preparation does not mutate rules")
	var angle: float = ui.game.angle
	ui._pause(); ui._aim_stick(Vector2.RIGHT,1); check(ui.game.angle==angle,"pause blocks analog")
	ui._pause(); ui.neutral_required=true; ui._aim_stick(Vector2.RIGHT,1); check(ui.game.angle==angle,"focus recovery requires neutral")
	ui.neutral_required=false; ui.game.online=true; ui.game.seat=1
	ui._aim_stick(Vector2.RIGHT,1); check(ui.game.angle==angle,"opponent owns preparation")
	ui.game.online=false; ui.game.angle=359.9; ui.game.power=99.9
	ui._aim_stick(Vector2(1,-1),1.0/30)
	check(is_equal_approx(ui.game.angle,2.9) and ui.game.power==100,"wrap angle and clamp power")
	ui.game.adjust_continuous(0,-1000); check(ui.game.power==10,"minimum power")
	var a := Match.new(); a.bridge.free(); a.bridge=Wire.new(); root.add_child(a); a.set_process(false)
	var b := Match.new(); b.bridge.free(); b.bridge=Wire.new(); root.add_child(b); b.set_process(false)
	a.local(2); b.local(2); a.accept_turn(); b.accept_turn()
	a.online=true; b.online=true; a.seat=0; b.seat=1; a.host=true
	a.members=["a","b"]; b.members=["a","b"]
	a.bridge.session={"self":"a","hostMember":"a"}; b.bridge.session={"self":"b","hostMember":"a"}
	a.heartbeat_at=Time.get_ticks_msec()+60000; b.heartbeat_at=Time.get_ticks_msec()+60000
	a.bridge.peer=b; b.bridge.peer=a
	var before: String = b.world.digest()
	a.angle=359; b.angle=359
	a.adjust_continuous(2.37,-0.63); a._process(0.1); b._process(0.01)
	check(b.angle>359 and b.angle<360,"remote interpolation crosses zero by shortest path")
	for tick in 90: b._process(1.0/60)
	check(is_equal_approx(b.angle,1.37) and is_equal_approx(b.power,74.37),"peer sees fine aim and power before putt")
	check(b.world.digest()==before,"preview leaves authoritative state untouched")
	var count: int = a.bridge.records.size()
	for tick in 60:
		a.adjust_continuous(0.037,0.013); a._process(1.0/60)
	check(a.bridge.records.size()-count<=15,"preview traffic bounded at 15 Hz")
	count=a.bridge.records.size()
	for tick in 60: a._process(1.0/60)
	check(a.bridge.records.size()-count<=1,"idle preview sends no repeats")
	a.bridge.pending={1:{},2:{},3:{},4:{},5:{},6:{},7:{},8:{}}
	a.adjust_continuous(1,0); count=a.bridge.records.size(); a._process(1)
	check(a.bridge.records.size()==count,"backpressure drops obsolete cosmetic updates")
	a.bridge.pending.clear()
	# Fire before the next preview: the putt itself carries exact authoritative aim.
	a.adjust_continuous(0.23,0.17); a.fire()
	check(a.phase=="moving" and b.phase=="moving" and a.world.digest()==b.world.digest(),"fine putt survives JSON exchange and matches peer rules")
	check(is_equal_approx(b.angle,round(a.angle*100)/100),"putt overrides delayed visual target")
	# Every presentation must finish before any participant can take the next turn.
	b.finish_shot(); b.adjust_continuous(-11.23,-2.47)
	check(b.phase=="waiting_turn" and not b.can_fire(),"fast peer waits for slow animation")
	a.finish_shot()
	check(a.phase=="aim" and b.phase=="aim" and b.can_fire(),"all-player barrier releases next actor")
	check(a.world.digest()==b.world.digest(),"barrier leaves rules synchronized")
	ui.game.online=true; ui.game.seat=1; ui.game.world.setup(2); ui.game.phase="aim"
	ui.game.angle=47.31; ui._refresh()
	check(ui.anchor.visible and ui.aim_root.visible and absf(ui.anchor.rotation.y+deg_to_rad(47.31))<0.001,"scene presents opponent orientation and aim guide")
	check(not ui.game.can_fire(),"remote preview grants no local shot authority")
	var flat := {"cup":[90000,90000],"walls":[],"sand":[]}
	var coarse := Match.Rules.trace(flat,[0,0],0,30)
	check(Match.Rules.trace(flat,[0,0],0.37,30).path!=coarse.path,"fine direction affects actual trajectory")
	check(Match.Rules.trace(flat,[0,0],0,30.23).path!=coarse.path,"fine power affects actual trajectory")
	ui.audio.shutdown(); await create_timer(.25).timeout
	ui.queue_free(); a.queue_free(); b.queue_free(); await process_frame
	print("ANALOG ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(0 if failures==0 else 1)
