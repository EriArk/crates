# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
const SHADER := preload("res://shaders/surface.gdshader")
enum Kind { TURF, SAND, WOOD, STONE, LEAF }

static func make(color: Color, kind: int, axis: Vector3=Vector3.FORWARD, palette: Texture2D=null) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader=SHADER
	result.set_shader_parameter("tint",color)
	result.set_shader_parameter("kind",kind)
	result.set_shader_parameter("grain_axis",axis)
	if palette!=null:
		result.set_shader_parameter("palette",palette)
		result.set_shader_parameter("use_palette",true)
	return result
