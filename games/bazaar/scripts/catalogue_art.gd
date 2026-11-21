# SPDX-License-Identifier: GPL-3.0-or-later
extends Control
## Product renders from the same four garment meshes used on the fitting podium.
const LOOKS := {
	"traveller":preload("res://assets/outfits/traveller.png"),
	"mage":preload("res://assets/outfits/mage.png"),
	"merchant":preload("res://assets/outfits/merchant.png")
}
var design := ""
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("e7d9b9"))
	if not LOOKS.has(design):return
	var aspect := 176.0/192
	var height := minf(size.y-4,(size.x-4)/aspect)
	var picture := Vector2(height*aspect,height)
	draw_texture_rect(LOOKS[design],Rect2((size-picture)*.5,picture),false)
