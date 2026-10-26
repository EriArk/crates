# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
const TRACK = "dirty-valley.2"
const CAR_LIMITS = [[-30000,30000],[-10000,10000],[-30000,30000],[-3142,3142],[-5000,5000],[-5000,5000],[-5000,5000],[-3142,3142],[0,100],[0,100],[0,100],[0,36],[0,31],[-320,1291],[-1,600100],[0,2000]]

static func integer(value, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value==int(value) and value>=low and value<=high

static func valid_input(values) -> bool:
	if not values is Array or values.size()!=6: return false
	for i in 6:
		var bounds = [[-1000,1000],[-1000,1000],[-3142,3142],[0,1000],[0,1000],[0,15]][i]
		if not integer(values[i],bounds[0],bounds[1]): return false
	return Vector2(values[0],values[1]).length()<=1420

static func input(car: Node3D) -> Array:
	return [roundi(car.desired.x*1000),roundi(car.desired.z*1000),roundi(atan2(car.aim.x,car.aim.z)*1000),roundi(car.throttle*1000),roundi(car.brake*1000),(1 if car.boosting else 0)|(2 if car.firing else 0)|(4 if car.handbrake else 0)|(8 if car.shield_pressed else 0)]

static func apply_input(car: Node3D, values: Array) -> void:
	car.desired=Vector3(values[0]/1000.0,0,values[1]/1000.0).limit_length(1)
	car.aim=Vector3(sin(values[2]/1000.0),0,cos(values[2]/1000.0))
	car.throttle=values[3]/1000.0; car.brake=values[4]/1000.0
	car.boosting=(int(values[5])&1)!=0; car.firing=(int(values[5])&2)!=0; car.handbrake=(int(values[5])&4)!=0
	if (int(values[5])&8)!=0: car.activate_shield()

static func car_state(car: Node3D) -> Array:
	return [roundi(car.position.x*100),roundi(car.position.y*100),roundi(car.position.z*100),roundi(wrapf(car.rotation.y,-PI,PI)*1000),roundi(car.linear_velocity.x*100),roundi(car.linear_velocity.y*100),roundi(car.linear_velocity.z*100),roundi(atan2(car.aim.x,car.aim.z)*1000),roundi(car.health),roundi(car.shield),roundi(car.boost),car.ammo,(1 if car.immune>0 else 0)|(2 if car.shield_item else 0)|(4 if car.boosting else 0)|(8 if car.ghost_time>0 else 0)|(16 if car.grounded else 0),car.passed,roundi(car.finish_time*1000) if car.finish_time>=0 else -1,roundi(car.disabled_time*1000)]

static func valid_snapshot(data: Dictionary, pickup_count: int) -> bool:
	if not integer(data.get("seq"),0,2147483647) or not integer(data.get("ms"),0,600100) or not integer(data.get("countdown"),0,3000): return false
	if data.get("phase") not in ["countdown","race","results"]: return false
	var cars = data.get("cars"); var pickups = data.get("pickups")
	if not cars is Array or cars.size()!=16 or not pickups is Array or pickups.size()!=pickup_count: return false
	for state in cars:
		if not state is Array or state.size()!=CAR_LIMITS.size(): return false
		for i in state.size():
			if not integer(state[i],CAR_LIMITS[i][0],CAR_LIMITS[i][1]): return false
	for value in pickups:
		if not integer(value,0,8000): return false
	var beams = data.get("beams",[])
	if not beams is Array or beams.size()>12: return false
	for beam in beams:
		if not beam is Array or beam.size()!=7 or not integer(beam[0],0,15): return false
		for i in range(1,7):
			if not integer(beam[i],-40000,40000): return false
	return true
