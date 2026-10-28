# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
const VALLEY = "dirty-valley.4"
const QUARRY = "quarry.1"
const NORD = "nordschleife.1"
const PASS = "forest-pass.1"
const TRACKS = {
	VALLEY: {"scene":preload("track.gd"),"title":"Грязевая долина","sign":"DIRTY VALLEY","limit":600.0,"finish_grace":45.0},
	QUARRY: {"scene":preload("quarry_track.gd"),"title":"Карьер","sign":"REDSTONE QUARRY","limit":900.0,"finish_grace":60.0},
	PASS: {"scene":preload("pass_track.gd"),"title":"Лесной перевал","sign":"PINECREST PASS","limit":1100.0,"finish_grace":90.0},
	NORD: {"scene":preload("nordschleife_track.gd"),"title":"Nordschleife · финал","sign":"NORDSCHLEIFE","limit":3600.0,"finish_grace":180.0,"quick_laps":1}
}
static func has_track(id: String) -> bool: return TRACKS.has(id)
static func create(id: String) -> Node3D:
	return TRACKS[id].scene.new() if has_track(id) else null
