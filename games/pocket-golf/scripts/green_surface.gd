# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
const Size = preload("res://scripts/dimensions.gd")
# One integer height grid and one triangle split for rendering AND shot rules.
const STEP := 250 # mm
const WIDTH := 41
const DEPTH := 65
const Q := 10000

static func root_int(n: int) -> int:
	if n<=0: return 0
	# Start Newton near sqrt(n), rather than halving a micrometre-squared value
	# dozens of times for each simulation tick. Every operation stays integral.
	var size := n; var bits := 0
	for shift in [32,16,8,4,2,1]:
		if size>=(1<<shift): size>>=shift; bits+=shift
	var x: int = 1<<((bits+2)/2)
	var y: int = (x+n/x)/2
	while y<x:
		x=y; y=(x+n/x)/2
	return x

static func bump_height(bumps: Array, x: int, z: int) -> int:
	var height := 0
	for bump in bumps:
		var dx: int = x-bump[0]; var dz: int = z-bump[1]
		if absi(dx)>=bump[2] or absi(dz)>=bump[3]: continue
		var u: int = Q-dx*dx*Q/(bump[2]*bump[2])
		var v: int = Q-dz*dz*Q/(bump[3]*bump[3])
		height+=bump[4]*(u*u/Q)*(v*v/Q)/(Q*Q)
	return height

static func bake(course: Dictionary) -> PackedInt32Array:
	var grid := PackedInt32Array(); grid.resize(WIDTH*DEPTH)
	var bumps: Array = course.get("hills",[])
	for iz in DEPTH:
		for ix in WIDTH:
			var x := -5000+ix*STEP; var z := -8000+iz*STEP
			var height := bump_height(bumps,x,z)
			# Flat, level pads: all cup contacts and the initial stance have zero slope.
			for point in [course.tee,course.cup]:
				var dx: int = x-point[0]; var dz: int = z-point[1]
				var t := clampi((dx*dx+dz*dz-1000*1000)*Q/(2200*2200-1000*1000),0,Q)
				var blend: int = (t*t/Q)*(3*Q-2*t)/Q
				var level := bump_height(bumps,point[0],point[1])
				height=level+(height-level)*blend/Q
			# Borders meet the existing level rails, including sub-mm pad rounding.
			grid[iz*WIDTH+ix]=0 if ix==0 or iz==0 or ix==WIDTH-1 or iz==DEPTH-1 else height
	return grid

# Return [height in mm, dh/dx * Q, dh/dz * Q]. The diagonal is b--c:
# a--b    Godot clockwise triangles a,b,c and b,d,c.
# | /|
# c--d
static func sample(grid: PackedInt32Array, x: int, z: int) -> Array:
	if grid.is_empty(): return [0,0,0]
	var local_x := clampi(x+5000,0,10000)
	var local_z := clampi(z+8000,0,16000)
	var ix: int = mini(local_x/STEP,WIDTH-2)
	var iz: int = mini(local_z/STEP,DEPTH-2)
	var u: int = local_x-ix*STEP; var v: int = local_z-iz*STEP
	var index := iz*WIDTH+ix
	var a := grid[index]; var b := grid[index+1]
	var c := grid[index+WIDTH]; var d := grid[index+WIDTH+1]
	if u+v<=STEP:
		return [a+((b-a)*u+(c-a)*v)/STEP,(b-a)*Q/STEP,(c-a)*Q/STEP]
	return [d+((c-d)*(STEP-u)+(b-d)*(STEP-v))/STEP,(d-c)*Q/STEP,(d-b)*Q/STEP]

static func normal(grid: PackedInt32Array, x: int, z: int) -> Vector3:
	var s := sample(grid,x,z)
	return Vector3(-s[1]/float(Q),1,-s[2]/float(Q)).normalized()

static func ball_height(grid: PackedInt32Array, x: int, z: int) -> int:
	if grid.is_empty(): return 190
	var s := sample(grid,x,z)
	return s[0]+Size.BALL_MM*root_int(Q*Q+s[1]*s[1]+s[2]*s[2])/Q+2

static func make_mesh(grid: PackedInt32Array) -> ArrayMesh:
	var vertices := PackedVector3Array(); var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for iz in DEPTH:
		for ix in WIDTH:
			var x := -5000+ix*STEP; var z := -8000+iz*STEP
			vertices.append(Vector3(x,grid[iz*WIDTH+ix],z)/1000.0)
			# Smooth shading only; vertices and triangle planes remain authoritative.
			var dx: int = sample(grid,x+125,z)[0]-sample(grid,x-125,z)[0]
			var dz: int = sample(grid,x,z+125)[0]-sample(grid,x,z-125)[0]
			normals.append(Vector3(-dx/250.0,1,-dz/250.0).normalized())
	for iz in DEPTH-1:
		for ix in WIDTH-1:
			var a := iz*WIDTH+ix; var b := a+1; var c := a+WIDTH; var d := c+1
			indices.append_array(PackedInt32Array([a,b,c,b,d,c]))
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_NORMAL]=normals; arrays[Mesh.ARRAY_INDEX]=indices
	var result := ArrayMesh.new(); result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result
