# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
const ITEM_ICONS := {
	"inventory":preload("res://assets/market/inventory.png"),
	"star":preload("res://assets/market/star.png"),
	"shield":preload("res://assets/market/shield.png"),
	"shop":preload("res://assets/market/shop.png"),
	"gamepad":preload("res://assets/market/gamepad.png"),
	"map":preload("res://assets/market/map.png")
}

const ART_CATALOGUE = preload("res://assets/market/item-art.json")
const ITEM_ART := {
	"blue-berry":preload("res://assets/market/blue-berry.png"),
	"peach-berry":preload("res://assets/market/peach-berry.png")
}

static func illustration(info: Dictionary) -> Texture2D:
	var collection: Dictionary=ART_CATALOGUE.data.get(str(info.get("game","")),{})
	var key: String=collection.get(str(info.get("title","")),"")
	return ITEM_ART.get(key,ITEM_ICONS.get(info.get("icon"),ITEM_ICONS.inventory))
