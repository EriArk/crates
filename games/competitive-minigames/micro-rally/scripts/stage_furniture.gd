# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
const Art = preload("res://scripts/art.gd")
const SIGN = preload("res://shaders/stage_sign.gdshader")

static func gate(track: Node3D, title: String, enamel: Color) -> void:
	var frame:=Node3D.new()
	frame.position=track.points[0]
	frame.basis=Basis.looking_at(track.tangents[0],Vector3.UP)
	track.add_child(frame)
	for side in [-1,1]:
		var x: float=side*7.0
		Art.box(frame,Vector3(0.40,5.2,0.40),Vector3(x,2.6,0),enamel)
		Art.box(frame,Vector3(0.52,0.82,0.52),Vector3(x,0.41,0),Color("bf9a62"))
		var brace:=Art.box(frame,Vector3(0.20,2.1,0.20),Vector3(x-side*0.65,4.28,0),Color("cba86c"))
		brace.rotation.z=side*PI/4.0
	var header:=Art.box(frame,Vector3(14.5,1.26,0.76),Vector3(0,5.12,0),enamel)
	var face:=ShaderMaterial.new()
	face.shader=SIGN
	face.set_shader_parameter("enamel",enamel)
	header.material_override=face
	for side in [-1,1]:
		var nameplate:=Label3D.new()
		nameplate.text=title
		nameplate.font_size=96
		nameplate.pixel_size=0.0095
		nameplate.outline_size=3
		nameplate.modulate=Color("fff0cd")
		nameplate.double_sided=false
		nameplate.position=Vector3(0,5.12,side*0.39)
		nameplate.rotation.y=0.0 if side==1 else PI
		frame.add_child(nameplate)

static func turn_sign(track: Node3D, index: int, bend: float, shoulder: float) -> void:
	# Positive signed yaw is a left turn. Place the sign on the outside shoulder.
	var heading: Vector3=track.tangents[index]
	var right:=Vector3(-heading.z,0,heading.x)
	var pos: Vector3=track.points[index]+right*shoulder*signf(bend)
	pos.y=track.surface_height(pos.x,pos.z)
	var post:=Art.box(track,Vector3(0.15,1.65,0.15),pos+Vector3.UP*0.825,Color("735d43"))
	post.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var face:=ShaderMaterial.new()
	face.shader=SIGN
	face.set_shader_parameter("enamel",Color("38413d"))
	face.set_shader_parameter("ink",Color("ffd25b"))
	face.set_shader_parameter("arrow_direction",-signf(bend))
	var board:=Art.box(track,Vector3(2.05,0.83,0.10),pos+Vector3.UP*1.57,Color.WHITE)
	board.basis=Basis.looking_at(heading,Vector3.UP)
	board.material_override=face
