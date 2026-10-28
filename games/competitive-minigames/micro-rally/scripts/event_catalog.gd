# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## Presentation registry. Availability is explicit; it never invents a runtime.
const Rules = preload("cup_rules.gd")
const MODES = [
	{"id":"race","title":"Гонки","description":"Круговые заезды · оружие · ускорения","available":true},
	{"id":"arena","title":"Сражения на аренах","description":"Бой на замкнутой арене","available":false},
	{"id":"royale","title":"Батлрояль","description":"Последняя уцелевшая машина","available":false}
]
const FILTERS = ["Все","Гонки","Арены","Батлрояль","Смешанные"]
const CUPS = [
	{"id":Rules.ID,"title":Rules.TITLE,"category":"race","stages":Rules.STAGES,
	"reward":"VORTEX","description":"От грунтовой долины до Северной петли",
	"duration":"38–45+ мин","available":true}
]
static func cups(category: int, entries: Array = CUPS) -> Array:
	var key=["all","race","arena","royale","mixed"][clampi(category,0,4)]
	return entries.filter(func(entry): return key=="all" or entry.category==key)
static func cup(id: String) -> Dictionary:
	for entry in CUPS:
		if entry.id==id: return entry
	return {}
static func can_start(id: String) -> bool:
	# The existing career storage/rules currently implement this one cup.
	return id==Rules.ID and cup(id).get("available",false)
