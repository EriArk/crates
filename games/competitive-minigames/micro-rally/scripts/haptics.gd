# SPDX-License-Identifier: GPL-3.0-or-later
extends Node
const Tires = preload("tire_surface.gd")
# One bounded mix for the local driver's pad. All writes expire even if a frame stalls.
const LEVELS = [0.0,0.3,0.65,1.0]
const TITLES = ["off","low","normal","high"]
const PULSES = {
	"impact":Vector3(0.32,0.85,0.22), "landing":Vector3(0.22,0.62,0.18),
	"shot":Vector3(0.26,0.08,0.065), "shift":Vector3(0.12,0.20,0.07),
	"shield":Vector3(0.42,0.18,0.12)
}
var device = -1
var focused = true
var previous: Dictionary = {}
var pulses: Dictionary = {}
var output = Vector2.ZERO
var refresh = 0.0
var events: Dictionary = {} # Bounded diagnostic counters by event name.

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_connection)
func available_device(game: Node) -> int:
	game.controls.detect(); return game.controls.device
func supports(pad: int) -> bool:
	return pad>=0 and (not Input.has_method("has_joy_vibration") or Input.call("has_joy_vibration",pad))
func write_pad(pad: int, strength: Vector2, duration: float) -> void:
	if strength==Vector2.ZERO: Input.stop_joy_vibration(pad)
	else: Input.start_joy_vibration(pad,strength.x,strength.y,duration)
func _connection(pad: int, connected: bool) -> void:
	if pad==device:
		stop(); device=-1 # A reconnected controller, even with the same ID, starts fresh.
func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT: focused=false; stop()
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN: focused=true
func _exit_tree() -> void: stop()
func stop() -> void:
	if device>=0 and output!=Vector2.ZERO: write_pad(device,Vector2.ZERO,0)
	output=Vector2.ZERO; pulses.clear(); previous.clear(); refresh=0
func pulse(kind: String, amount: float = 1.0) -> void:
	var spec: Vector3=PULSES[kind]
	pulses[kind]={"value":Vector2(spec.x,spec.y)*clampf(amount,0,1),"left":spec.z,"duration":spec.z}
	events[kind]=int(events.get(kind,0))+1
func sample(car: Node3D) -> Dictionary:
	return {"id":car.get_instance_id(),"reset":car.reset_serial,"health":car.health,
		"shield":car.shield,"heat":car.weapon_heat,"ground":car.grounded,
		"vertical":car.linear_velocity.y,"gear":car.transmission.gear,
		"impact":car.impact_cooldown,"missing":car.missing_wheels}
func update(game: Node, delta: float) -> void:
	var next=available_device(game)
	if next!=device: stop(); device=next
	var level: float=LEVELS[game.cup.store.haptics_level()]
	if not focused or game.state!="race" or game.net.overlay or game.controls.neutral_required or level<=0 or not supports(device):
		stop(); return
	var car=game.player()
	if car.finish_time>=0: stop(); return
	var now=sample(car)
	if previous.is_empty() or now.id!=previous.id or now.reset!=previous.reset or car.ghost_time>0:
		stop(); previous=now; return
	# Merge simultaneous local damage/physics impact into one impact envelope.
	if now.health<previous.health or now.missing!=previous.missing or now.impact>previous.impact+0.15:
		pulse("impact",clampf((previous.health-now.health)/22.0,0.35,1.0))
	if now.ground and not previous.ground and previous.vertical< -3: pulse("landing",clampf(-previous.vertical/10.0,0.3,1))
	if now.heat>previous.heat+1: pulse("shot")
	if now.gear!=previous.gear and not car.transmission.reverse: pulse("shift")
	if now.shield<previous.shield-3: pulse("shield")
	previous=now
	var strength=Vector2.ZERO
	if car.grounded and car.disabled_time<=0:
		var tire=Tires.feedback(car)
		var drift=tire.x
		strength=Vector2(0.11,0.045)*drift+Vector2(0.015,0.025)*tire.y
		if car.boosting and car.boost>0 and (car.throttle>0 or car.replica): strength=strength.max(Vector2(0.08,0.14))
	for kind in pulses.keys():
		var effect: Dictionary=pulses[kind]
		strength=strength.max(effect.value*smoothstep(0.0,1.0,effect.left/effect.duration))
		effect.left-=delta
		if effect.left<=0: pulses.erase(kind)
	strength=(strength*level).clamp(Vector2.ZERO,Vector2.ONE)
	refresh-=delta
	# At most 30 updates/s, with a finite 100 ms watchdog on every command.
	if strength==Vector2.ZERO:
		if output!=Vector2.ZERO: write_pad(device,Vector2.ZERO,0)
		output=Vector2.ZERO; refresh=0
	elif refresh<=0:
		write_pad(device,strength,0.10); output=strength; refresh=1.0/30.0
