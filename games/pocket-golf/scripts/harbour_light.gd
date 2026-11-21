# SPDX-License-Identifier: GPL-3.0-or-later
extends MeshInstance3D
## One faceted, vertex-coloured mesh for the reef, tower and lantern.
func _ready() -> void:
	position=Vector3(-10.5,-1.62,-24.5)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rock := Color("708987")
	for offset in [Vector3(-2.3,0,0.6), Vector3(1.8,-0.3,0.9),Vector3(0,0.25,0)]:
		band(surface,offset,0,1.3,2.8,1.45,rock,7)
		band(surface,offset,1.3,1.35,1.45,0.01,Color("93a193"),7)
	var ivory := Color("f2dfb6")
	var vermilion := Color("c75438")
	var ink := Color("36595b")
	band(surface,Vector3.ZERO,1.58,1.9,1.06,0.95,ink)
	band(surface,Vector3.ZERO,1.9,3.15,0.87,0.77,ivory)
	band(surface,Vector3.ZERO,3.15,4.05,0.77,0.70,vermilion)
	band(surface,Vector3.ZERO,4.05,5.15,0.70,0.60,ivory)
	band(surface,Vector3.ZERO,5.15,5.37,0.85,0.85,ink)
	band(surface,Vector3.ZERO,5.37,6.12,0.54,0.54,Color("ffca76"))
	for i in 6:
		var angle:=TAU*i/6.0
		band(surface,Vector3(cos(angle),0,sin(angle))*0.54,5.37,6.12,0.06,0.06,ink,4)
	band(surface,Vector3.ZERO,6.12,6.81,0.83,0.03,vermilion)
	surface.generate_normals()
	mesh=surface.commit()
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo=true
	paint.vertex_color_is_srgb=true
	paint.roughness=0.86
	material_override=paint
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func band(surface: SurfaceTool, origin: Vector3, low: float, high: float,
		foot: float, crown: float, color: Color, sides := 12) -> void:
	for i in sides:
		var a:=TAU*i/sides
		var b:=TAU*(i+1)/sides
		var left:=Vector3(cos(a),0,sin(a))
		var right:=Vector3(cos(b),0,sin(b))
		var p:=origin+Vector3.UP*low+left*foot
		var q:=origin+Vector3.UP*low+right*foot
		var r:=origin+Vector3.UP*high+right*crown
		var s:=origin+Vector3.UP*high+left*crown
		surface.set_color(color)
		for vertex in [p,q,r,p,r,s]:
			surface.add_vertex(vertex)
