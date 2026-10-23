# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

static func get_course(index: int) -> Dictionary:
	return [
		{"title":"FIRST LIGHT", "par":2, "tee":[0,6000], "cup":[0,-5500], "walls":[], "sand":[]},
		{"title":"THE BANK SHOT", "par":3, "tee":[-2500,6000], "cup":[2600,-5500], "walls":[[-4800,-500,700,500]], "sand":[]},
		{"title":"SAND & STONE", "par":3, "tee":[2400,6000], "cup":[-2400,-5700], "walls":[[600,-1800,4600,-1000],[-4600,2200,-1300,2900]], "sand":[[-900,-6500,900,500]]}
	][index].duplicate(true)
