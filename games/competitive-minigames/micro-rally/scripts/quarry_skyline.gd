# SPDX-License-Identifier: GPL-3.0-or-later
extends MeshInstance3D
## Distant exposed benches beyond the playable outer plateau.
const BLUFFS := [Vector4(-202,49,26,34),Vector4(-201,87,20,23),
	Vector4(-198,-118,18,32),Vector4(44,-209,29,28),Vector4(98,-205,18,36),
	Vector4(213,6,27,32),Vector4(-12,210,22,28)]
const SHELVES := [Vector2(1.0,0.0),Vector2(0.79,0.44),Vector2(0.70,0.46),
	Vector2(0.63,0.72),Vector2(0.47,0.77),Vector2(0.39,0.99),Vector2(0.0,1.0)]
const STRATA := ["aa684e","d6a274","ae7158","dba777","b77d61","deb389"]

func _ready() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for bluff in BLUFFS:
		for layer in STRATA.size():
			var tint:=Color(STRATA[layer])
			for i in 9:
				var a:=ledge(bluff,i,SHELVES[layer])
				var b:=ledge(bluff,i+1,SHELVES[layer])
				var c:=ledge(bluff,i+1,SHELVES[layer+1])
				var d:=ledge(bluff,i,SHELVES[layer+1])
				surface.set_color(tint)
				for v in [a,b,c,a,c,d]: surface.add_vertex(v)
	surface.generate_normals()
	mesh=surface.commit()
	var stone:=StandardMaterial3D.new()
	stone.vertex_color_use_as_albedo=true
	stone.vertex_color_is_srgb=true
	stone.roughness=1
	material_override=stone
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func ledge(bluff: Vector4, index: int, shelf: Vector2) -> Vector3:
	var angle:=TAU*(index%9)/9.0
	var rough:=1.0+0.16*sin(angle*3.0+bluff.y)
	var rim:=shelf.x*bluff.z*rough
	return Vector3(bluff.x+cos(angle)*rim,12.0+bluff.w*shelf.y+sin(angle*2.0)*shelf.x,
			bluff.y+sin(angle)*rim*0.78)
