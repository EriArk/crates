# SPDX-License-Identifier: GPL-3.0-or-later
extends Control
## Tailor's paper patterns; silhouettes describe designs before garments ship.
var design := ""
func _draw() -> void:
	var scale_factor := minf(size.x / 112.0, size.y / 112.0)
	draw_set_transform(size*.5,0,Vector2.ONE*scale_factor)
	var ink := Color("423331")
	var paper := Color("ecdcaf")
	draw_rect(Rect2(-56,-56,112,112),paper)
	var shape := PackedVector2Array()
	var dye := Color("628471")
	match design.to_lower():
		"traveller":
			shape = PackedVector2Array([Vector2(-12,-35),Vector2(12,-35),Vector2(27,-21),Vector2(39,16),Vector2(15,12),Vector2(13,33),Vector2(-17,33),Vector2(-17,13),Vector2(-35,22),Vector2(-25,-20)])
		"mage":
			dye=Color("676088")
			shape = PackedVector2Array([Vector2(0,-44),Vector2(13,-24),Vector2(21,-19),Vector2(34,5),Vector2(21,16),Vector2(14,7),Vector2(25,38),Vector2(-25,38),Vector2(-14,6),Vector2(-21,16),Vector2(-34,4),Vector2(-19,-20),Vector2(-12,-24)])
		"merchant":
			dye=Color("ae6852")
			shape = PackedVector2Array([Vector2(-10,-35),Vector2(10,-35),Vector2(26,-25),Vector2(34,-7),Vector2(21,0),Vector2(16,-8),Vector2(21,33),Vector2(-20,33),Vector2(-16,-8),Vector2(-23,0),Vector2(-34,-8),Vector2(-24,-25)])
		_:
			shape = PackedVector2Array([Vector2(0,-27),Vector2(22,-13),Vector2(20,16),Vector2(0,29),Vector2(-20,16),Vector2(-22,-13)])
	draw_colored_polygon(shape,dye)
	shape.append(shape[0])
	draw_polyline(shape,ink,2,true)
	draw_line(Vector2(-11,-24),Vector2(10,6),ink,2,true)
	draw_line(Vector2(-15,7),Vector2(15,5),ink,3,true)
	draw_circle(Vector2(3,5),3,Color("f0c365"))
