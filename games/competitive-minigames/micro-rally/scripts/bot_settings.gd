# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
const AXES = ["pace","reaction","aggression","accuracy"]
const LABELS = {"pace":"Pace", "reaction":"Reaction", "aggression":"Aggression", "accuracy":"Accuracy"}
const VALUES = {"pace":["Relaxed","Normal","Fast"], "reaction":["Slow","Normal","Fast"],
	"aggression":["Low","Normal","High"], "accuracy":["Low","Normal","High"]}
const PRESETS = ["Easy","Normal","Hard"]
const STYLES = ["mixed","racer","assault","tactical","daredevil"]
const STYLE_TITLES = ["Mixed styles","Racers","Bruisers","Tacticians","Daredevils"]
static func preset(level: int = 1) -> Dictionary:
	return {"version":1,"pace":level,"reaction":level,"aggression":level,"accuracy":level,"style":"mixed"}
static func valid(value) -> bool:
	if not value is Dictionary or value.size()!=6 or value.get("version")!=1 or value.get("style") not in STYLES: return false
	for key in AXES:
		var n=value.get(key)
		if not (n is int or n is float) or not is_finite(float(n)) or n!=int(n) or n<0 or n>2: return false
	return true
static func normalized(value: Dictionary) -> Dictionary:
	# JSON numbers return as floats; use one canonical representation at boundaries.
	return {"version":1,"pace":int(value.pace),"reaction":int(value.reaction),"aggression":int(value.aggression),"accuracy":int(value.accuracy),"style":value.style}
static func level(value: Dictionary) -> int:
	for i in 3:
		if key(value)==key(preset(i)): return i
	return -1
static func title(value: Dictionary) -> String:
	var i=level(value); return PRESETS[i] if i>=0 else "Custom"
static func key(value: Dictionary) -> String:
	return "bots.v1/%d%d%d%d/%s" % [value.pace,value.reaction,value.aggression,value.accuracy,value.style]
static func style_index(value: Dictionary, slot: int) -> int:
	return posmod(slot,4) if value.style=="mixed" else STYLES.find(value.style)-1
