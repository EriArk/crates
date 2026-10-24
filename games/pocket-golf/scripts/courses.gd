# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
const Surface = preload("res://scripts/green_surface.gd")
static var prepared: Array = []

static func get_course(index: int) -> Dictionary:
	if prepared.is_empty():
		prepared = [
		{"title":"FIRST LIGHT", "par":2, "tee":[0,6000], "cup":[0,-5500], "walls":[], "sand":[]},
		{"title":"THE BANK SHOT", "par":3, "tee":[-2500,6000], "cup":[2600,-5500], "walls":[[-4800,-500,700,500]], "sand":[]},
		{"title":"SAND & STONE", "par":3, "tee":[2400,6000], "cup":[-2400,-5700], "walls":[[600,-1800,4600,-1000],[-4600,2200,-1300,2900]], "sand":[[-900,-6500,900,500]]}
		]
		var relief := [
			[[0,0,4400,6000,650]],
			[[-500,-1800,4500,5500,800]],
			[[1900,1800,3100,4300,550],[-1900,-3500,3100,4000,600]]
		]
		for hole in 3:
			prepared[hole]["hills"]=relief[hole]
			prepared[hole]["height_grid"]=Surface.bake(prepared[hole])
	return prepared[index].duplicate(true)
