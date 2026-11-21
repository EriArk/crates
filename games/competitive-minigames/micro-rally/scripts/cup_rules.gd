# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
const ID = "forest-challenge"
const VERSION = 1
const TITLE = "Woodland Challenge"
const POINTS = [25,20,16,13,11,10,9,8,7,6,5,4,3,2,1,0]
const CARS = ["swift","comet","trail","vortex"]
const MODELS = ["hatchback-sports","sedan-sports","suv","race"]
const TITLES = ["Swift","Comet","Trail","Vortex"]
const STAGES = [
	{"id":"valley","title":"Dirty Valley","track":preload("race_wire.gd").TRACK,"laps":5,"target":"4–6 min","weight":2,"time":"day","weather":"clear","available":true},
	{"id":"quarry","title":"Quarry","track":"quarry.1","laps":6,"target":"6–8 min","weight":2,"time":"sunset","weather":"clear","available":true},
	{"id":"pass","title":"Forest Pass","track":"forest-pass.1","laps":5,"target":"8–10 min","weight":2,"time":"dawn","weather":"rain","available":true},
	{"id":"boss","title":"Nordschleife · boss","track":"nordschleife.1","laps":1,"target":"20+ min","weight":3,"time":"day","weather":"overcast","available":true}
]
static func whole(value, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value==int(value) and value>=low and value<=high
static func model(id: String) -> String: return MODELS[CARS.find(id)]
static func title(id: String) -> String: return TITLES[CARS.find(id)]
static func conditions(stage: int) -> Dictionary:
	return {"version":2,"time":STAGES[stage].time,"weather":STAGES[stage].weather,"seed":38021,"timeline":[]}
static func valid_result(rows) -> bool:
	if not rows is Array or rows.size()!=16: return false
	var slots: Array=[]
	for row in rows:
		if not row is Dictionary or not whole(row.get("slot"),0,15) or slots.has(row.slot): return false
		if not whole(row.get("ms"),-1,7200000) or row.ms==0 or not whole(row.get("progress"),-320,1000000): return false
		slots.append(row.slot)
	return true
static func ranked(rows: Array) -> Array:
	var result=rows.duplicate(true)
	result.sort_custom(func(a,b):
		if a.ms>=0 and b.ms>=0: return a.ms<b.ms if a.ms!=b.ms else a.slot<b.slot
		if a.ms>=0 or b.ms>=0: return a.ms>=0
		return a.progress>b.progress if a.progress!=b.progress else a.slot<b.slot)
	var last_time = -2; var place = 0
	for i in result.size():
		if result[i].ms!=last_time or result[i].ms<0: place=i
		last_time=result[i].ms; result[i].place=place
	return result
static func table(results: Array) -> Array:
	var entries: Array=[]
	for slot in 16: entries.append({"slot":slot,"points2":0,"countback":[],"final_place":16})
	for entry in entries:
		for i in 16: entry.countback.append(0)
	for stage in results.size():
		for row in ranked(results[stage]):
			var entry: Dictionary=entries[int(row.slot)]
			if row.ms>=0:
				entry.points2+=POINTS[int(row.place)]*STAGES[stage].weight
				entry.countback[int(row.place)]+=1
				if stage==STAGES.size()-1: entry.final_place=row.place
	entries.sort_custom(func(a,b):
		var order=compare(a,b)
		return order<0 if order!=0 else a.slot<b.slot)
	var place = 1
	for i in entries.size():
		if i>0 and compare(entries[i-1],entries[i])!=0: place=i+1
		entries[i].place=place
	return entries
static func compare(a: Dictionary, b: Dictionary) -> int:
	if a.points2!=b.points2: return -1 if a.points2>b.points2 else 1
	for i in 16:
		if a.countback[i]!=b.countback[i]: return -1 if a.countback[i]>b.countback[i] else 1
	if a.final_place!=b.final_place: return -1 if a.final_place<b.final_place else 1
	return 0
static func won(results: Array, slot: int = 0) -> bool:
	if results.size()!=STAGES.size(): return false
	for row in table(results):
		if row.slot==slot: return row.place==1 and row.points2>0
	return false
static func points(value: int) -> String:
	return str(value/2)+(".5" if value%2 else "")
