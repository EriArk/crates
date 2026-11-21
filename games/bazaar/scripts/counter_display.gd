# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
const Plush=preload("festival_plush.gd")
const Goods=preload("market_goods.gd")

static func fill(display: Node3D, items: Array) -> void:
	var count:=mini(3,items.size())
	for i in count:
		var item:Dictionary=items[i]
		var x:float=(i-(count-1)*.5)*.83
		var index:=Plush.NAMES.find(str(item.get("title",""))) if item.get("game")=="Festival Park" else -1
		if index>=0:
			var toy:=Plush.create(index)
			display.add_child(toy)
			toy.position=Vector3(x,-.025,-.10)
			toy.scale=Vector3.ONE*.88
			toy.visibility_range_end=24
		else:
			var icon:=Sprite3D.new()
			icon.texture=Goods.illustration(item)
			icon.pixel_size=.32/maxf(1,icon.texture.get_width())
			icon.position=Vector3(x,.19,0)
			display.add_child(icon)
			icon.layers=1 << (2-1)
		var plaque:=MeshInstance3D.new()
		var card:=BoxMesh.new()
		card.size=Vector3(.79,.116,.026)
		plaque.mesh=card
		var dye:=StandardMaterial3D.new()
		dye.albedo_color=Color("304e4d")
		plaque.material_override=dye
		plaque.layers=1 << (2-1)
		plaque.visibility_range_end=4.2
		plaque.position=Vector3(x,.055,.215)
		display.add_child(plaque)
		var tag:=Label3D.new()
		tag.text="%s  ·  %d ✦"%[str(item.get("title","Item")).left(22),int(item.price)]
		tag.font_size=28
		tag.pixel_size=minf(.003,.75/maxf(1,ThemeDB.fallback_font.get_string_size(tag.text,HORIZONTAL_ALIGNMENT_LEFT,-1,28).x))
		tag.position=plaque.position+Vector3.BACK*.017
		tag.modulate=Color("fff0cf")
		tag.outline_size=2
		tag.visibility_range_end=4.2
		tag.layers=1 << (2-1)
		display.add_child(tag)
