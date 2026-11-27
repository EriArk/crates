# SPDX-License-Identifier: GPL-3.0-or-later
extends CanvasLayer
class_name VenueLoading

static func cover_rebuild(game:Node,title:String) -> void:
	if not game.is_node_ready() or DisplayServer.get_name()=="headless":return
	var root:=game.get_tree().root
	if root.has_node("VenueLoading"):return
	var layer:=VenueLoading.new()
	layer.name="VenueLoading"
	layer.layer=119
	root.add_child(layer)
	var image:=TextureRect.new()
	image.texture=preload("res://assets/transit/arrival.jpg")
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	layer.add_child(image)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label:=Label.new()
	label.text=title
	label.add_theme_font_size_override("font_size",28)
	label.add_theme_constant_override("outline_size",5)
	label.add_theme_color_override("font_outline_color",Color("#25323b"))
	image.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	label.offset_left=30
	label.offset_top=-74
	# Course rebuilds also run inside synchronous multiplayer transactions.
	RenderingServer.force_draw()
	layer.queue_free_after_draw.call_deferred()

func queue_free_after_draw() -> void:
	await RenderingServer.frame_post_draw
	queue_free()
