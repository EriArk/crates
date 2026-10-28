# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
# Original arcade drivetrain. Sources and tuning rationale: docs/TRANSMISSION.md.
const RATIOS = [3.2,2.25,1.65,1.25,1.0]
const IDLE = 1100.0
const REDLINE = 8000.0
const SHIFT_RPM = 6200.0
const SHIFT_TIME = 0.16
# Final drive / rolling radius: equal gearing across the differently sized toy cars.
const REDUCTION_PER_METRE = 28.0
var gear = 1
var rpm = IDLE
var shift_left = 0.0
var cooldown = 0.0
var pending = 0
var reverse = false
var torque_factor = 1.0

func reset() -> void:
	gear=1; rpm=IDLE; shift_left=0; cooldown=0; pending=0; reverse=false; torque_factor=1

static func road_rpm(speed: float, selected: int) -> float:
	return absf(speed)*REDUCTION_PER_METRE*RATIOS[selected-1]*60.0/TAU

func request(direction: int) -> void:
	pending=clampi(direction,-1,1)

func change(direction: int, speed: float) -> bool:
	var next=clampi(gear+direction,1,RATIOS.size())
	if next==gear or cooldown>0 or reverse: return false
	if direction<0 and road_rpm(speed,next)>REDLINE*0.91: return false
	gear=next; shift_left=SHIFT_TIME; cooldown=0.4
	return true

func step(dt: float, speed: float, wheel_speed: float, throttle: float, brake: float, grounded: bool, manual: bool) -> void:
	shift_left=maxf(0,shift_left-dt); cooldown=maxf(0,cooldown-dt)
	# Same brake-to-reverse convenience in both modes, without an unsafe forward/reverse shift at speed.
	if not reverse and speed<0.4 and throttle<0.05 and brake>0.05:
		reverse=true; gear=1; shift_left=0; pending=0
	elif reverse and speed> -0.4 and (throttle>0.05 or brake<0.05):
		reverse=false; gear=1; shift_left=0; pending=0
	if pending!=0:
		if manual: change(pending,speed)
		pending=0
	if not manual and grounded and not reverse and speed>=0:
		var coupled=road_rpm(speed,gear)
		if coupled>SHIFT_RPM and throttle>0.1: change(1,speed)
		elif gear>1 and coupled<2900 and road_rpm(speed,gear-1)<SHIFT_RPM*0.85: change(-1,speed)
	var coupled=road_rpm(wheel_speed,gear)
	var pedal=brake if reverse else throttle
	var target=maxf(IDLE,coupled)
	# Automatic clutch avoids stalling; free revs during jumps do not upshift the automatic.
	if not grounded: target=lerpf(IDLE,REDLINE,pedal)
	elif absf(speed)<2.0: target=maxf(target,IDLE+pedal*1400)
	if shift_left>0: target=maxf(IDLE,rpm-dt*18000)
	rpm=lerpf(rpm,clampf(target,IDLE,REDLINE),1-exp(-dt*18))
	var curve=0.58+0.42*sin(clampf(rpm/REDLINE,0,1)*PI)
	var limiter=1.0-smoothstep(REDLINE*0.94,REDLINE,coupled)
	var clutch=1.0-smoothstep(0.0,SHIFT_TIME,shift_left)
	torque_factor=RATIOS[gear-1]*curve*limiter*clutch

func drive_acceleration(boost: bool) -> float:
	return minf(22.0 if boost else 13.0,14.0*torque_factor*(1.7 if boost else 1.0))

func gear_label() -> String:
	return "R" if reverse else str(gear)

static func speed_kmh(velocity: Vector3) -> float:
	# Chassis ground speed, including sideways drift; pure vertical bounce adds no speed.
	return Vector2(velocity.x,velocity.z).length()*3.6
