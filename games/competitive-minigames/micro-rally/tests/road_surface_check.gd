# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
static func inspect(track: Node3D) -> Dictionary:
	var arrays: Array=track.get_node("RoadSurface").mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var error=0.0; var area=0.0; var expected=0.0
	for i in range(0,indices.size(),3):
		var a=vertices[indices[i]]; var b=vertices[indices[i+1]]; var c=vertices[indices[i+2]]
		area+=absf(Vector2(b.x-a.x,b.z-a.z).cross(Vector2(c.x-a.x,c.z-a.z)))*0.5
		for p in [(a+b+c)/3.0,(a+b)*0.5,(b+c)*0.5,(c+a)*0.5]:
			error=maxf(error,absf(p.y-track.surface_height(p.x,p.z)-0.035))
	for i in track.COUNT:
		var j=(i+1)%track.COUNT; var a: Vector3=track.points[i]; var b: Vector3=track.points[j]
		var sa=Vector3(-track.tangents[i].z,0,track.tangents[i].x)*track.WIDTH*0.5
		var sb=Vector3(-track.tangents[j].z,0,track.tangents[j].x)*track.WIDTH*0.5
		var corners=[a-sa,b-sb,a+sa,b+sb]
		for ids in [[0,1,2],[2,1,3]]:
			var ab: Vector3=corners[ids[1]]-corners[ids[0]]; var ac: Vector3=corners[ids[2]]-corners[ids[0]]
			expected+=absf(Vector2(ab.x,ab.z).cross(Vector2(ac.x,ac.z)))*0.5
	return {"interior_error":error,"coverage_error":absf(area-expected)/expected,"triangles":indices.size()/3}
