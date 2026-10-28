# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
# Stable wire IDs. Arcade coefficients, not measurements of real tires.
enum Kind { ASPHALT, CONCRETE, GRAVEL, MUD, GRASS }
const DRY = [Vector3(1.30,1.0,0.22),Vector3(1.22,1.0,0.30),Vector3(1.16,0.97,0.43),Vector3(1.12,0.94,0.55),Vector3(0.72,0.90,1.15)]
const WET_LOSS = [0.30,0.33,0.16,0.25,0.36]
const SLIDING = [0.84,0.83,0.85,0.84,0.78]
const MARKS = [Color("25282a"),Color("30312d"),Color("67533e"),Color("543f29"),Color("455231")]

static func wetness(grip: float) -> float:
	# Existing stage grip field remains the weather contract; do not multiply twice.
	return clampf((1.0-grip)/0.2,0,1)
static func profile(kind: int, wet: float = 0.0) -> Vector3:
	var p: Vector3=DRY[kind]; wet=clampf(wet,0,1)
	p.x*=1.0-WET_LOSS[kind]*wet
	if kind>=Kind.MUD: p.z*=1.0+wet*0.55
	return p
static func intensity(w: Dictionary) -> float:
	if not w.contact or w.missing: return 0.0
	return smoothstep(0.6,6.0,Vector2(w.long_slip,w.slip).length())
static func feedback(car: Node3D) -> Vector2:
	# x sliding / y rolling on loose ground. Shared by local and replica feedback.
	var slide=0.0; var loose=0.0
	for w in car.physics.wheels:
		if not w.contact or w.missing: continue
		slide=maxf(slide,intensity(w))
		if w.surface>=Kind.GRAVEL: loose+=0.25
	return Vector2(slide,loose*clampf(car.linear_velocity.length()/18.0,0,1))
