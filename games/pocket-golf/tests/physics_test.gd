# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Rules = preload("res://scripts/rules.gd")
const Physics = preload("res://scripts/ball_physics.gd")
const Courses = preload("res://scripts/courses.gd")
var failures := 0

func check(value: bool, label: String) -> void:
	if not value: failures+=1; printerr("FAIL: "+label)

func _initialize() -> void:
	var grass := {"cup":[90000,90000],"walls":[],"sand":[]}
	var shortest := 1.0e10
	var longest := 0.0
	var corpus: Array = []
	for angle in range(0,360,5):
		var shot: Dictionary = Rules.trace(grass,[0,0],angle,30)
		var distance := Vector2(shot.position[0],shot.position[1]).length()
		shortest=minf(shortest,distance); longest=maxf(longest,distance)
		check(shot.stopped and shot.bounces.is_empty(),"unobstructed roll stops")
		corpus.append(shot)
	check(longest-shortest<3,"direction-independent range within 3 mm / 2.3 m")
	print("RANGE mm shortest=",shortest," longest=",longest," spread=",longest-shortest)
	var previous_distance := 0
	for power in range(10,41,5):
		var shot: Dictionary = Rules.trace(grass,[0,0],0,power)
		check(-shot.position[1]>previous_distance,"power increases range")
		previous_distance=-shot.position[1]
		var previous_step := 100000
		for i in range(1,shot.path.size()):
			var step: int = shot.path[i-1][1]-shot.path[i][1]
			check(step<=previous_step+1 and step>=0,"smooth monotonic deceleration")
			previous_step=step
	var sand: Dictionary = grass.duplicate(true); sand.sand=[[-5000,-8000,5000,8000]]
	check(-Rules.trace(sand,[0,0],0,30).position[1]<shortest/3,"sand brakes substantially harder")
	var p := [-120*Physics.SCALE,-120*Physics.SCALE]; var v := [40*Physics.SCALE,40*Physics.SCALE]
	check(Physics.wall_contact(p,v,[0,0,1000,1000]),"round corner contact")
	check(v[0]<0 and v[1]<0 and absi(v[0]-v[1])<=1,"corner reflects radially")
	check(Physics.length_int(p[0],p[1])>=Physics.RADIUS,"corner resolves penetration")
	check(Physics.length_int(v[0],v[1])<Physics.length_int(40*Physics.SCALE,40*Physics.SCALE),"bounce loses energy")
	p=[-179*Physics.SCALE,500*Physics.SCALE]; v=[0,70*Physics.SCALE]
	check(not Physics.wall_contact(p,v,[0,0,1000,1000]) and v==[0,70*Physics.SCALE],"tangential motion is preserved")
	var narrow: Dictionary = grass.duplicate(true); narrow.walls=[[0,-1000,1,1000]]
	var thin: Dictionary = Rules.trace(narrow,[-2000,0],90,100)
	check(not thin.bounces.is_empty(),"maximum-power contact with 1 mm wall")
	for point in thin.path: check(point[0]<=-180,"no tunnelling through thin wall")
	var cup: Dictionary = grass.duplicate(true); cup.cup=[0,0]
	var slow: Dictionary = Rules.trace(cup,[0,900],0,20)
	var fast: Dictionary = Rules.trace(cup,[0,1000],0,50)
	var lip: Dictionary = Rules.trace(cup,[310,900],0,35)
	var miss: Dictionary = Rules.trace(cup,[400,900],0,35)
	check(slow.sunk and slow.position==[0,0],"slow central putt sinks")
	check(slow.capture_frame>=0 and slow.heights.back()<0 and slow.path.size()-slow.capture_frame==37,"continuous drop below ground")
	check(not fast.sunk and not fast.rims.is_empty() and fast.position[1]<-1000,"fast putt crosses cup")
	check(not lip.sunk and not lip.rims.is_empty() and absi(lip.position[0]-310)>5,"grazing lip redirects without automatic capture")
	check(not miss.sunk and miss.rims.is_empty() and miss.position[0]==400,"near miss stays outside physical rim")
	print("CUP slow=",slow.sunk," fast=",fast.position," lip=",lip.position," miss=",miss.position)
	# Cross-platform replay fingerprint covers full paths, heights and contact events.
	for hole in 3:
		for angle in range(0,360,15):
			for power in [10,35,70,100]:
				var shot: Dictionary = Rules.trace(Courses.get_course(hole),Courses.get_course(hole).tee,angle,power)
				check(shot.stopped,"simulation settles before safety limit")
				for point in shot.path:
					check(absi(point[0])<=4820 and absi(point[1])<=7820,"course bounds")
					for wall in Courses.get_course(hole).walls:
						var dx: int = point[0]-clampi(point[0],wall[0],wall[2])
						var dz: int = point[1]-clampi(point[1],wall[1],wall[3])
						check(dx*dx+dz*dz>=178*178,"ball remains outside walls, mm rounding tolerance")
				corpus.append(shot)
	corpus.append_array([slow,fast,lip,miss,thin])
	print("REPLAY cases=",corpus.size()," sha256=",JSON.stringify(corpus).sha256_text())
	print("PHYSICS ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(0 if failures==0 else 1)
