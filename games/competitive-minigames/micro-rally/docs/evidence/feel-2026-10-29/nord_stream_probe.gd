extends SceneTree
func _initialize(): call_deferred("run")
func percentile(values:Array,p:float):
 values.sort(); return values[mini(values.size()-1,int(values.size()*p))]
func run():
 var track=load("res://scripts/nordschleife_track.gd").new();root.add_child(track)
 var began=Time.get_ticks_usec();track.build();var build_ms=(Time.get_ticks_usec()-began)/1000.0
 var samples=[];var query_ms=[]
 for at in [0,460,2378]:
  for frame in 240:
   began=Time.get_ticks_usec();track.update_view(track.points[at]);samples.append((Time.get_ticks_usec()-began)/1000.0)
   await process_frame
  began=Time.get_ticks_usec()
  for i in 1000: track.tire_surface_at(track.points[(at+i%20)%track.COUNT])
  query_ms.append((Time.get_ticks_usec()-began)/1000.0)
 print("PERF_NORD ",JSON.stringify({"build_ms":build_ms,"stream_p95_ms":percentile(samples,.95),"stream_p99_ms":percentile(samples,.99),"stream_max_ms":samples.max(),"surface_1000_ms":query_ms,"scenery":track.scenery.size(),"pending":track.pending.size()}))
 track.free();quit()
