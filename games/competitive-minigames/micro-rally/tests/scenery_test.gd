# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures=0
func check(ok: bool, label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var art=preload("res://scripts/art.gd")
	var world=Node3D.new(); root.add_child(world)
	var poses=[]
	for point in [Vector3(-130,7,140),Vector3(-129,8,141),Vector3(160,3,-180)]:
		poses.append(Transform3D(Basis(Vector3.UP,0.7).scaled(Vector3.ONE*2),point))
	for id in ["rock_largeA","grass_large"]:
		var parent=Node3D.new(); world.add_child(parent)
		art.instances(parent,"nature",id,poses)
		var source=art.model("nature",id); var parts=art.mesh_parts(source)
		check(parent.get_child_count()==parts.size()*2,"Separate remote scenery regions have independent visibility origins")
		var expected=[]; var actual=[]
		for part in parts:
			for pose in poses: expected.append(pose*part[1])
		for batch in parent.get_children():
			check(batch.position.length()>100,"Far scenery does not inherit map-centre visibility")
			check(batch.visibility_range_end== (52 if id.contains("grass") else 100),"Keep existing per-kind distance budget")
			for i in batch.multimesh.instance_count:
				var local=batch.multimesh.get_instance_transform(i)
				check(Vector2(local.origin.x,local.origin.z).length()<20,"Each batch covers only a local region")
				actual.append(batch.transform*local)
		check(actual.size()==expected.size(),"Batching preserves every mesh part")
		for transform in expected:
			check(actual.any(func(t): return t.is_equal_approx(transform)),"Batch origin conversion preserves placement, rotation and scale")
		source.free()
	world.free(); print("SCENERY ",JSON.stringify({"failures":failures})); quit(1 if failures else 0)
