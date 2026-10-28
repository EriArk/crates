# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
class Recorder extends "res://scripts/haptics.gd":
	var pad=3
	var supported=true
	var writes: Array=[]
	func available_device(_game: Node) -> int: return pad
	func supports(value: int) -> bool: return value>=0 and supported
	func write_pad(value: int, strength: Vector2, duration: float) -> void: writes.append([value,strength,duration])
var failures=0
func check(ok: bool, label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	game.set_process(false); game.set_physics_process(false); game.state="race"
	game.cup.store.load_profile("haptics","user://haptics-"+str(Time.get_ticks_usec()))
	game.controls.neutral_required=false
	for c in game.cars: c.freeze=true; c.ghost_time=0; c.grounded=true
	var car=game.player(); car.throttle=0; car.boosting=false; car.linear_velocity=Vector3.ZERO
	game.haptics.free(); var h=Recorder.new(); game.haptics=h; game.add_child(h)
	h.update(game,0.02)
	check(h.output==Vector2.ZERO,"New pad primes local state without replaying events")
	car.health-=12; h.update(game,0.02)
	check(h.events.impact==1 and h.output.y>0,"Local damage gives strong-motor impact")
	for i in 20: h.update(game,0.02)
	check(h.events.impact==1 and h.output==Vector2.ZERO,"Repeated state cannot replay damage; finite pulse ends")
	game.cars[1].health-=30; h.update(game,0.02)
	check(h.events.impact==1,"Other drivers cannot vibrate local pad")
	car.grounded=false; car.linear_velocity.y=-7; h.update(game,0.02)
	car.grounded=true; car.linear_velocity.y=0; h.update(game,0.02)
	check(h.events.landing==1,"Landing uses actual airborne transition")
	car.weapon_heat+=8; h.update(game,0.04); check(h.events.shot==1,"Authoritative local shot produces pulse")
	car.weapon_heat-=2; h.update(game,0.04); check(h.events.shot==1,"Cooling or held fire without a shot is silent")
	car.transmission.gear=2; h.update(game,0.04); check(h.events.shift==1,"Accepted gear change pulses once")
	car.shield=100; h.update(game,0.04); car.shield=99; h.update(game,0.04)
	check(not h.events.has("shield"),"Passive shield decay is silent")
	car.shield=80; h.update(game,0.04); check(h.events.shield==1,"Shield hit has separate feedback")
	car.reset_serial+=1; h.update(game,0.04)
	check(h.output==Vector2.ZERO and h.pulses.is_empty(),"Recovery cancels effects and seeds fresh telemetry")
	car.linear_velocity=Vector3(5,0,-10); car.boosting=true; car.throttle=1
	h.update(game,0.04); check(h.output.x>0 and h.output.y>0,"Drift and boost make a bounded continuous layer")
	game.net.overlay=true; h.update(game,0.02)
	check(h.output==Vector2.ZERO,"Online menu stops motors while race keeps running")
	game.net.overlay=false; h.update(game,0.02); h.update(game,0.04)
	h._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(h.output==Vector2.ZERO and not h.focused,"Focus loss immediately stops motors")
	h.update(game,0.04); check(h.output==Vector2.ZERO,"No effect while unfocused")
	h._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN); h.update(game,0.04); h.update(game,0.04)
	var old=h.device; h.pad=7; h.update(game,0.02)
	check(h.writes[-1][0]==old and h.writes[-1][1]==Vector2.ZERO and h.device==7,"Pad swap stops old device before new one")
	h.update(game,0.04); h._connection(7,false)
	check(h.output==Vector2.ZERO and h.device== -1,"Disconnect cancels device ownership and effects")
	h.pad=-1; h.update(game,0.04); check(h.output==Vector2.ZERO,"No controller safely stays silent")
	h.pad=8; h.supported=false; h.update(game,0.04); h.update(game,0.04)
	check(h.output==Vector2.ZERO,"Unsupported vibration safely stays silent")
	h.supported=true; game.cup.store.set_haptics_level(0); h.update(game,0.04)
	check(h.output==Vector2.ZERO,"Off disables pulses and background")
	game.cup.store.set_haptics_level(1); h.update(game,0.04); h.update(game,0.04); var weak=h.output
	game.cup.store.set_haptics_level(3); h.update(game,0.04)
	check(h.output.length()>weak.length()*3,"Intensity scales both motors")
	game.cup.store.set_haptics_level(0); h.update(game,0.04)
	check(h.output==Vector2.ZERO and h.writes[-1][1]==Vector2.ZERO,"Switching off stops an already active motor")
	game.cup.store.set_haptics_level(3); h.update(game,0.04); h.update(game,0.04)
	game.state="pause"; h.update(game,0.04); check(h.output==Vector2.ZERO,"Solo pause stops vibration")
	game.state="race"; car.finish_time=4; h.update(game,0.04); check(h.output==Vector2.ZERO,"Finish remains silent")
	check(h.writes.all(func(w): return w[1].x>=0 and w[1].x<=1 and w[1].y>=0 and w[1].y<=1 and w[2]<=0.1),"Every hardware command is bounded and expires")
	game.hud.menu("controls"); game.hud.buttons[1].pressed.emit()
	check(game.cup.store.haptics_level()==0,"Controller/touch menu action cycles to off")
	var base=game.cup.store.base_path; game.cup.store.load_profile("haptics",base.get_base_dir())
	check(game.cup.store.haptics_level()==0,"Vibration preference survives reopening")
	game.cup.store.load_profile("other",base.get_base_dir()); check(game.cup.store.haptics_level()==2,"Another profile has its own default")
	check(not game.cup.store.set_haptics_level(4),"Out-of-range intensity rejected")
	print("HAPTICS TEST failures=",failures," hardware_calls_recorded=",h.writes.size()," events=",h.events)
	await preload("audio_drain.gd").dispose(game,self); quit(1 if failures else 0)
