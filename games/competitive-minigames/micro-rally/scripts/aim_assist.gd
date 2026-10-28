# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
const TITLES=["Off","Low","Normal"]
static func resolve(car: Node3D, others: Array, level: int) -> Vector3:
	var raw: Vector3=Vector3(car.aim.x,0,car.aim.z).normalized()
	var origin: Vector3=car.position+Vector3.UP*0.6
	var result=raw; var best=INF
	for other in others:
		if other==car or other.health<=0 or other.ghost_time>0: continue
		var diff: Vector3=other.position+Vector3.UP*0.3-origin
		var distance=diff.length()
		if distance<2 or distance>34: continue
		var flat=Vector3(diff.x,0,diff.z).normalized()
		var angle=absf(raw.signed_angle_to(flat,Vector3.UP))
		# With assist off, pitch still follows a car directly under the reticle.
		var cone=maxf(atan2(0.65,distance),deg_to_rad([0.0,5.0,8.0][clampi(level,0,2)]))
		if angle>cone or absf(diff.y)>distance*0.7: continue
		var query=PhysicsRayQueryParameters3D.create(origin,origin+diff,3,[car.get_rid()])
		var hit=car.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.collider!=other: continue
		var score=angle+distance*0.0005
		if score>=best: continue
		best=score
		var correction=raw.signed_angle_to(flat,Vector3.UP)*[0.0,0.35,0.6][clampi(level,0,2)]
		result=raw.rotated(Vector3.UP,correction)
		result.y=diff.y/maxf(1,Vector2(diff.x,diff.z).length()); result=result.normalized()
	return result
