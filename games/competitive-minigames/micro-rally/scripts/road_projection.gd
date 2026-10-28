# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
# Clip road triangles against the actual terrain triangles. Matching only the
# ribbon vertices leaves its interior dipping through a differently triangulated hill.
static func append(track: Node3D, surface: SurfaceTool, vertices: Array, uvs: Array) -> void:
	var road=PackedVector2Array()
	for v in vertices: road.append(Vector2(v.x,v.z))
	var n: int=track.terrain_cells()
	var low=road[0].min(road[1]).min(road[2]); var high=road[0].max(road[1]).max(road[2])
	var first=Vector2i(floori((low.x+n)/2),floori((low.y+n)/2))
	var last=Vector2i(floori((high.x+n)/2),floori((high.y+n)/2))
	var ab=road[1]-road[0]; var ac=road[2]-road[0]; var area=ab.cross(ac)
	if absf(area)<0.000001: return
	for z in range(maxi(0,first.y),mini(n-1,last.y)+1):
		for x in range(maxi(0,first.x),mini(n-1,last.x)+1):
			var a=Vector2(x*2-n,z*2-n); var b=a+Vector2(2,0); var c=a+Vector2(0,2); var d=a+Vector2(2,2)
			for cell in [PackedVector2Array([a,b,c]),PackedVector2Array([b,d,c])]:
				for polygon in Geometry2D.intersect_polygons(road,cell):
					if polygon.size()<3: continue
					# Boolean clipping can return 56.00001 at a shared grid corner.
					# Snap only that numerical residue so neighbouring cells share vertices.
					for k in polygon.size():
						var point: Vector2=polygon[k]; var grid=point.snapped(Vector2(2,2))
						if absf(point.x-grid.x)<0.0001: point.x=grid.x
						if absf(point.y-grid.y)<0.0001: point.y=grid.y
						polygon[k]=point
					if Geometry2D.is_polygon_clockwise(polygon)!=Geometry2D.is_polygon_clockwise(road): polygon.reverse()
					for i in range(1,polygon.size()-1):
						if absf((polygon[i]-polygon[0]).cross(polygon[i+1]-polygon[0]))<0.000001: continue
						for p in [polygon[0],polygon[i],polygon[i+1]]:
							var offset: Vector2=p-road[0]
							var wb=offset.cross(ac)/area; var wc=ab.cross(offset)/area
							surface.set_uv(uvs[0]*(1-wb-wc)+uvs[1]*wb+uvs[2]*wc)
							surface.add_vertex(Vector3(p.x,track.surface_height(p.x,p.y)+0.035,p.y))
