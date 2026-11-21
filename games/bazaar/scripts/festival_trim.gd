# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

static func landscape(parent: Node3D, center: Vector3, size: Vector2, waves := false) -> void:
	var cloth:=MeshInstance3D.new()
	var panel:=QuadMesh.new()
	panel.size=size
	var print_material:=ShaderMaterial.new()
	print_material.shader=preload("res://shaders/festival_silk.gdshader")
	print_material.set_shader_parameter("waves",waves)
	panel.material=print_material
	cloth.mesh=panel
	cloth.position=center
	cloth.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(cloth)

static func valance(square: Node3D, center: Vector3, width: float, colors: Array, panels: int) -> void:
	var step:=width/panels
	for i in panels:
		var at:=center+Vector3((i-(panels-1)*.5)*step,0,0)
		var dye:String=colors[i%colors.size()]
		square.block(at,Vector3(step,.14,.94),dye,false)
		square.block(at+Vector3(0,-.12,.43),Vector3(step-.028,.20,.04),dye,false)
		square.block(at+Vector3(0,-.18,.457),Vector3(step-.07,.027,.018),"f4c177",false)
