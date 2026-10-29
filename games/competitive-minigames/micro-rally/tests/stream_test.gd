# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures=0
func check(ok:bool,label:String):
	if not ok: failures+=1;push_error(label)
func _initialize():call_deferred("run")
func run():
	var track=load("res://scripts/nordschleife_track.gd").new();root.add_child(track);track.build()
	var costs=[];var max_steps=0
	for at in [0,460,2378]:
		for frame in 2200:
			track.update_view(track.points[at]);costs.append(track.stream_usec/1000.0);max_steps=maxi(max_steps,track.stream_steps)
			await process_frame
			if track.pending.is_empty() and track.scenery_job.is_empty():break
		check(track.scenery.size()<=9 and track.pending.is_empty() and track.scenery_job.is_empty(),"Bounded streaming completes all visible tiles")
		for offset in [Vector3.ZERO,Vector3(20,0,20),Vector3(-25,0,-30)]:
			var p:Vector3=track.points[at]+offset;var actual=track.nearest(p);var expected=0;var distance=INF
			for i in track.COUNT:
				var d=Vector2(p.x-track.points[i].x,p.z-track.points[i].z).length_squared()
				if d<distance:distance=d;expected=i
			check(actual==expected,"Cached spatial search preserves exhaustive winner")
	check(max_steps<=384,"No unbounded placement loop runs inside one frame")
	costs.sort();print("STREAM_TEST ",JSON.stringify({"failures":failures,"frames":costs.size(),"max_steps":max_steps,"p99_ms":costs[int(costs.size()*.99)],"max_ms":costs.max(),"scenery":track.scenery.size()}))
	track.free();quit(1 if failures else 0)
