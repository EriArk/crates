# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

# Route sample, lateral offset, longitudinal and lateral radii, signed height (m).
# Each group leaves a clear line. The wooden crossings have their own level decks.
const PATCHES=[
	[56,-2.5,4.1,2.7,-0.46], [62,1.7,3.4,2.4,-0.40],
	[80,0.0,4.3,3.9,0.96],
	[142,2.0,4.5,2.8,-0.50], [148,-2.1,3.5,2.3,-0.38],
	[195,-1.8,3.8,2.4,-0.43], [203,2.0,4.5,2.8,-0.48],
	[251,-0.9,4.8,3.8,1.05], [292,2.0,4.1,2.6,-0.42]
]
const CELL=12.0
var cells: Dictionary={}
var segments: Dictionary={}

func _init(road: Node3D) -> void:
	for spec in PATCHES:
		var at: int=spec[0]
		var forward:=Vector2(road.tangents[at].x,road.tangents[at].z)
		var side:=Vector2(-forward.y,forward.x)
		var center:=Vector2(road.points[at].x,road.points[at].z)+side*float(spec[1])
		var extent:=Vector2.ONE*(maxf(spec[2],spec[3])+0.01)
		var first:=Vector2i(((center-extent)/CELL).floor())
		var last:=Vector2i(((center+extent)/CELL).floor())
		var patch: Array=[center,forward/float(spec[2]),side/float(spec[3]),float(spec[4])]
		for x in range(first.x,last.x+1):
			for z in range(first.y,last.y+1):
				var key:=Vector2i(x,z)
				if not cells.has(key): cells[key]=[]
				cells[key].append(patch)
		# A collar of projected road triangles lets each feature return to grade.
		for step in range(-7,8): segments[posmod(at+step,road.COUNT)]=true

func height(p: Vector2) -> float:
	var key:=Vector2i((p/CELL).floor())
	if not cells.has(key): return 0.0
	var result:=0.0
	for patch in cells[key]:
		var delta: Vector2=p-patch[0]
		var u:=delta.dot(patch[1])
		var v:=delta.dot(patch[2])
		var weight:=maxf(0.0,1.0-u*u-v*v)
		result+=float(patch[3])*weight*weight
	return result
