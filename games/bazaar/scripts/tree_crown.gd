# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## Replace the imported single canopy shell while retaining its authored trunk.
static func apply(mesh: ArrayMesh, leaf_surface: int, color: Color, broad: bool) -> void:
	mesh.surface_remove(leaf_surface)
	var crown:=SurfaceTool.new()
	crown.begin(Mesh.PRIMITIVE_TRIANGLES)
	crown.set_smooth_group(-1)
	var lobes:=6 if broad else 5
	for i in range(lobes+1):
		var angle:=TAU*i/lobes
		var center:=Vector3(cos(angle)*0.25,0.79+0.07*sin(i*2.18),sin(angle)*0.25)
		var scale:=Vector3(0.34,0.28,0.32)
		if i==lobes:
			center=Vector3(0.02,1.03,0)
			scale=Vector3(0.39,0.31,0.37)
		if not broad:
			center.x*=0.72;center.z*=0.78;scale.x*=0.84
		var lower:=PackedVector3Array()
		for level in 5:
			var ring:=PackedVector3Array()
			var width: float=[0.18,0.87,1.0,0.71,0.13][level]
			var height: float=[-1.0,-0.61,0.06,0.72,1.0][level]
			for k in 7:
				var a:=TAU*k/7+angle*0.3+0.25*(level%2)
				var uneven:=1.0+0.09*sin(k*3.7+i)
				ring.append(center+scale*Vector3(cos(a)*width*uneven,height,sin(a)*width*uneven))
			if level>0:
				for k in 7:
					var next: int=(k+1)%7
					crown.set_color(color.darkened(0.04*(3-level)+0.045*(i%3)))
					for point in [lower[k],lower[next],ring[k],lower[next],ring[next],ring[k]]:
						crown.add_vertex(point)
			if level==0 or level==4:
				for k in range(1,6):
					crown.set_color(color)
					crown.add_vertex(ring[0])
					crown.add_vertex(ring[k if level==4 else k+1])
					crown.add_vertex(ring[k+1 if level==4 else k])
			lower=ring
	crown.generate_normals()
	var mat:=StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo=true
	mat.vertex_color_is_srgb=true
	mat.roughness=1.0
	crown.set_material(mat)
	crown.commit(mesh)
