# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
# Authoritative fixed-point rolling model. 0.1 micrometres, 120 ticks/s; no float math
# or engine contacts enter the shared result. Public paths/positions use mm.
const HZ := 120
const SCALE := 10000
const RADIUS := 180*SCALE
const CUP_RADIUS := 330*SCALE
const CUP_CORE := CUP_RADIUS-RADIUS
const CUP_SPEED := 18*SCALE # 2.16 m/s; fast putts cross the cup.
const GRASS_DRAG := 950 # 1.368 m/s^2
const SAND_DRAG := 4800
const RESTITUTION := 72 # percent, normal component only
const MAX_TICKS := 1200

static func root_int(n: int) -> int:
	if n<=0: return 0
	var x: int = n
	var y: int = (x+1)/2
	while y<x:
		x=y
		y=(x+n/x)/2
	return x

static func length_int(x: int, z: int) -> int:
	return root_int(x*x+z*z)

static func rounded_div(numerator: int, denominator: int) -> int:
	# Truncating both velocity components would add diagonal-only rolling drag.
	return (numerator+denominator/2)/denominator if numerator>=0 else -((-numerator+denominator/2)/denominator)

# Circle/rectangle contact: radial normals around corners, face normals elsewhere.
# Full-power launch travels 70 mm/tick, well below the 360 mm collision diameter.
# The thin-wall regression covers face crossings; grazing corners remain discrete.
# Project out before reflecting.
static func wall_contact(p: Array, v: Array, wall: Array) -> bool:
	var left: int = wall[0]*SCALE
	var top: int = wall[1]*SCALE
	var right: int = wall[2]*SCALE
	var bottom: int = wall[3]*SCALE
	var cx: int = clampi(p[0],left,right)
	var cz: int = clampi(p[1],top,bottom)
	var nx: int = p[0]-cx
	var nz: int = p[1]-cz
	if nx*nx+nz*nz>=RADIUS*RADIUS: return false
	var distance := length_int(nx,nz)
	if distance>=RADIUS: return false
	if distance==0:
		var gaps := [p[0]-left,right-p[0],p[1]-top,bottom-p[1]]
		var side: int = gaps.find(gaps.min())
		nx=-1 if side==0 else 1 if side==1 else 0
		nz=-1 if side==2 else 1 if side==3 else 0
		cx=left if side==0 else right if side==1 else p[0]
		cz=top if side==2 else bottom if side==3 else p[1]
		distance=1
	p[0]=cx+nx*(RADIUS+1)/distance
	p[1]=cz+nz*(RADIUS+1)/distance
	var normal_speed: int = (v[0]*nx+v[1]*nz)/distance
	if normal_speed>=0: return false
	var impulse: int = normal_speed*(100+RESTITUTION)/100
	v[0]-=impulse*nx/distance
	v[1]-=impulse*nz/distance
	return true

static func trace(course: Dictionary, origin: Array, direction: Array, power: int) -> Dictionary:
	var p := [origin[0]*SCALE,origin[1]*SCALE]
	var norm := length_int(direction[0],direction[1])
	var v := [direction[0]*power*7000/norm,direction[1]*power*7000/norm]
	var path: Array = [origin.duplicate()]
	var heights: Array = [190]
	var bounces: Array = []
	var rims: Array = []
	var sunk := false
	var in_cup := false
	var capture_frame := -1
	var stopped := false
	for tick in MAX_TICKS:
		p[0]+=v[0]; p[1]+=v[1]
		var bounced := false
		for axis in 2:
			var limit := (4820 if axis==0 else 7820)*SCALE
			if absi(p[axis])>limit:
				p[axis]=clampi(p[axis],-limit,limit)
				v[axis]=-v[axis]*RESTITUTION/100
				bounced=true
		# Revisit contacts at intersections (wall/rail, or multiple walls).
		for pass_index in 3:
			for wall in course.walls:
				if wall_contact(p,v,wall): bounced=true
			p[0]=clampi(p[0],-4820*SCALE,4820*SCALE)
			p[1]=clampi(p[1],-7820*SCALE,7820*SCALE)
		path.append([p[0]/SCALE,p[1]/SCALE]); heights.append(190)
		if bounced: bounces.append(path.size()-1)
		var dx: int = course.cup[0]*SCALE-p[0]
		var dz: int = course.cup[1]*SCALE-p[1]
		var distance := length_int(dx,dz)
		var speed := length_int(v[0],v[1])
		var drag := GRASS_DRAG
		for sand in course.sand:
			if p[0]>sand[0]*SCALE and p[0]<sand[2]*SCALE and p[1]>sand[1]*SCALE and p[1]<sand[3]*SCALE:
				drag=SAND_DRAG
		if distance<CUP_RADIUS:
			if not in_cup: rims.append(path.size()-1)
			in_cup=true
			if distance<=CUP_CORE and speed<=CUP_SPEED:
				sunk=true; stopped=true; capture_frame=path.size()-1
				var entry: Array = path.back().duplicate()
				# Continue the trajectory into the bowl; don't teleport or shrink.
				for drop in range(1,37):
					var travel := mini(drop,18)
					path.append([entry[0]+(course.cup[0]-entry[0])*travel/18,entry[1]+(course.cup[1]-entry[1])*travel/18])
					heights.append(190-480*drop*drop/(36*36))
				break
			# Shallow bowl bends grazing paths. Only slow central contacts sink.
			if distance>0:
				var pull: int = 1000+3000*(CUP_RADIUS-distance)/CUP_RADIUS
				v[0]+=dx*pull/distance; v[1]+=dz*pull/distance
				speed=length_int(v[0],v[1])
			drag=300
		else: in_cup=false
		if speed<=drag:
			stopped=true; break
		v[0]=rounded_div(v[0]*(speed-drag),speed)
		v[1]=rounded_div(v[1]*(speed-drag),speed)
	return {"path":path,"heights":heights,"hz":HZ,"sunk":sunk,"bounces":bounces,"rims":rims,"capture_frame":capture_frame,"stopped":stopped,"position":path.back().duplicate()}
