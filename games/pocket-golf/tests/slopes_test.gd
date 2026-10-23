# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Surface = preload("res://scripts/green_surface.gd")
const Rules = preload("res://scripts/rules.gd")
const Courses = preload("res://scripts/courses.gd")
var failures := 0

func check(value: bool, label: String) -> void:
	if not value: failures+=1; printerr("FAIL: "+label)

func plane(percent: int) -> Dictionary:
	var grid := PackedInt32Array()
	for z in Surface.DEPTH:
		for x in Surface.WIDTH: grid.append(x*Surface.STEP*percent/100)
	return {"cup":[90000,90000],"walls":[],"sand":[],"height_grid":grid}

func _initialize() -> void:
	var flat := Rules.trace(plane(0),[0,0],90,25)
	var uphill := Rules.trace(plane(10),[0,0],90,25)
	var downhill := Rules.trace(plane(10),[0,0],270,25)
	var crosshill := Rules.trace(plane(10),[0,0],0,25)
	check(uphill.position[0]<flat.position[0]*0.8,"uphill loses range")
	check(-downhill.position[0]>flat.position[0]*1.4,"downhill gains range")
	check(crosshill.position[0]<-200,"cross-slope bends a putt downhill")
	check(uphill.stopped and downhill.stopped and crosshill.stopped,"gentle slopes settle")
	var rollback := Rules.trace(plane(35),[0,0],90,10)
	var furthest := 0
	for p in rollback.path: furthest=maxi(furthest,p[0])
	check(furthest>50 and rollback.position[0]<-500,"weak uphill putt rolls back on steep slope")
	check(rollback.stopped,"downhill wall contact eventually rests")
	var accelerating := Rules.trace(plane(35),[0,0],270,25)
	check(accelerating.path[19][0]-accelerating.path[20][0]>accelerating.path[0][0]-accelerating.path[1][0],"steep downhill accelerates")
	print("SLOPE range mm flat=",flat.position," uphill=",uphill.position," downhill=",downhill.position," cross=",crosshill.position," rollback=",rollback.position)
	var largest_error := 0.0
	var signatures: Array = []
	for hole in 3:
		var course: Dictionary = Courses.get_course(hole)
		var grid: PackedInt32Array = course.height_grid
		var mesh := Surface.make_mesh(grid)
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var max_gradient := 0.0
		check(grid.size()==Surface.WIDTH*Surface.DEPTH and grid.to_byte_array()==Surface.bake(course).to_byte_array(),"reproducible height grid")
		# Independent engine ray/triangle intersection against actual render geometry.
		for i in range(0,indices.size(),3):
			var a := vertices[indices[i]]; var b := vertices[indices[i+1]]; var c := vertices[indices[i+2]]
			var probe := a*0.19+b*0.37+c*0.44
			var x := roundi(probe.x*1000); var z := roundi(probe.z*1000)
			var hit = Geometry3D.ray_intersects_triangle(Vector3(x/1000.0,5,z/1000.0),Vector3.DOWN,a,b,c)
			check(hit is Vector3,"triangle intersects vertical probe")
			if not hit is Vector3: continue
			var s := Surface.sample(grid,x,z)
			var error: float = absf(hit.y*1000-s[0]); largest_error=maxf(largest_error,error)
			check(error<1.01,"rendered and physical triangle height agree within mm quantization")
			max_gradient=maxf(max_gradient,Vector2(s[1],s[2]).length()/Surface.Q)
			var centre := Surface.ball_height(grid,x,z)
			var normal := Vector3(-s[1]/float(Surface.Q),1,-s[2]/float(Surface.Q)).normalized()
			check((centre-hit.y*1000)*normal.y>=180,"sphere clears sloped surface")
		for point in [course.tee,course.cup]:
			var level: int = Surface.sample(grid,point[0],point[1])[0]
			for dx in [-450,0,450]:
				for dz in [-450,0,450]:
					var s := Surface.sample(grid,point[0]+dx,point[1]+dz)
					check(s==[level,0,0],"flat tee/cup pad")
		for i in Surface.WIDTH:
			check(grid[i]==0 and grid[(Surface.DEPTH-1)*Surface.WIDTH+i]==0,"north/south rails remain at ground level")
		for i in Surface.DEPTH:
			check(grid[i*Surface.WIDTH]==0 and grid[i*Surface.WIDTH+Surface.WIDTH-1]==0,"east/west rails remain at ground level")
		check(max_gradient<0.55,"playable slopes remain bounded")
		print("GREEN ",hole+1," vertices=",grid.size()," crest mm=",Array(grid).max()," gradient=",max_gradient," cup mm=",Surface.sample(grid,course.cup[0],course.cup[1])[0])
		signatures.append(grid)
		var raised := Rules.trace(course,course.tee,0,75)
		for frame in raised.path.size():
			if raised.capture_frame>=0 and frame>raised.capture_frame: break
			var p: Array = raised.path[frame]
			check(raised.heights[frame]==Surface.ball_height(grid,p[0],p[1]),"trajectory follows surface including sphere clearance")
		signatures.append(raised)
		# Shots beginning on hills, near sand and walls, including weak uphill shots.
		for x in [-3500,0,3500]:
			for z in [-6000,-3000,0,3000,6000]:
				var blocked := false
				for wall in course.walls:
					if Rules.inside([x,z],wall,190): blocked=true
				if blocked: continue
				for power in [10,65]:
					var shot := Rules.trace(course,[x,z],posmod((x+z)/100,72)*5,power)
					check(shot.stopped,"off-tee hillside shot settles before safety limit")
					signatures.append(shot)
	signatures.append_array([flat,uphill,downhill,crosshill,rollback,accelerating])
	print("SURFACE ray error mm=",largest_error," sha256=",JSON.stringify(signatures).sha256_text())
	print("SLOPES ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(0 if failures==0 else 1)
