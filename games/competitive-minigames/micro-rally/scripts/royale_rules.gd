# SPDX-License-Identifier: GPL-3.0-or-later
extends "arena_rules.gd"
var places: Array[int]=[]
func reset(count: int) -> void:
	super.reset(count); places.assign(range(count)); places.fill(0)
func eliminate(slots: Array,now: float) -> void:
	# Simultaneous eliminations share a place; slot iteration cannot choose a winner.
	var remaining=places.count(0)
	for slot in slots:
		if places[slot]!=0: continue
		wreck(slot,now); places[slot]=remaining
func finish() -> void:
	for i in places.size():
		if places[i]==0: places[i]=1
func ranked() -> Array:
	var result=rows.duplicate(true)
	result.sort_custom(func(a,b):
		var pa=places[a.slot]; var pb=places[b.slot]
		if pa!=pb: return pa<pb if pa>0 and pb>0 else pa==0
		return a.slot<b.slot)
	for row in result: row.place=places[row.slot] if places[row.slot]>0 else 1
	return result
func place(slot: int) -> int: return places[slot]
