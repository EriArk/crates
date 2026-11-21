# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
# Facade/roof dressing shares each building's two meshes and existing collision.
# No new solid objects or hidden obstacles are introduced into driving routes.
const TRIM=Color("d4c6a6")
const GLASS=Color("294d59")
const SHADOW=Color("343a36")

static func street_front(track: Node3D,entry: Dictionary) -> float:
	var pos=Vector2(entry.position[0],entry.position[2]); var closest=pos; var best=INF
	for road in track.roads:
		if road.kind not in ["main","residential"]: continue
		for i in road.points.size()-1:
			var a: Vector3=road.points[i]; var b: Vector3=road.points[i+1]
			var p=Geometry2D.get_closest_point_to_segment(pos,Vector2(a.x,a.z),Vector2(b.x,b.z))
			if pos.distance_squared_to(p)<best: best=pos.distance_squared_to(p); closest=p
	var front=Vector2(sin(entry.yaw),cos(entry.yaw))
	return PI if front.dot(closest-pos)<0 else 0.0

static func apron(track: Node3D,entry: Dictionary,material: Material) -> void:
	# Ground-following paving; deliberately flush, so curb edges cannot snag wheels.
	# Visual mesh uses the same sampled triangle heights as the terrain collider.
	var origin: Vector3=track.v3(entry.position); var w=float(entry.size[0]); var d=float(entry.size[2])
	var basis=Basis(Vector3.UP,float(entry.yaw)); var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var extent=2.4 if entry.kind=="shop" else 1.6
	var half_w=w/2+extent; var half_d=d/2+extent
	var nx=ceili(half_w*2); var nz=ceili(half_d*2)
	for x in nx:
		for z in nz:
			var x0=lerpf(-half_w,half_w,float(x)/nx); var x1=lerpf(-half_w,half_w,float(x+1)/nx)
			var z0=lerpf(-half_d,half_d,float(z)/nz); var z1=lerpf(-half_d,half_d,float(z+1)/nz)
			if x0> -w/2 and x1<w/2 and z0> -d/2 and z1<d/2: continue
			var tint=Color("929384") if (x+z)%3 else Color("9d9b88")
			for corner in [Vector3(x0,0,z0),Vector3(x1,0,z0),Vector3(x1,0,z1),Vector3(x0,0,z0),Vector3(x1,0,z1),Vector3(x0,0,z1)]:
				var p=origin+basis*corner; p.y=track.height_at(p)+0.035
				st.set_color(tint); st.add_vertex(p-origin)
	st.generate_normals(); var mesh=MeshInstance3D.new(); mesh.mesh=st.commit(); mesh.material_override=material
	mesh.position=origin; mesh.visibility_range_end=140; mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; track.add_child(mesh)

static func box(track: Node3D,st: SurfaceTool,size: Vector3,pos: Vector3,color: Color) -> void:
	track._box(st,size,pos,color)

static func window(track: Node3D,st: SurfaceTool,x: float,y: float,z: float,w: float,h: float,side: int) -> void:
	box(track,st,Vector3(w+0.3,h+0.3,0.16),Vector3(x,y,z),TRIM)
	box(track,st,Vector3(w,h,0.18),Vector3(x,y,z+side*0.1),GLASS)
	box(track,st,Vector3(0.10,h,0.2),Vector3(x,y,z+side*0.13),TRIM)
	box(track,st,Vector3(w,0.10,0.2),Vector3(x,y,z+side*0.13),TRIM)
	box(track,st,Vector3(w+0.5,0.16,0.4),Vector3(x,y-h/2-0.1,z),TRIM.darkened(0.15))

static func facades(track: Node3D,st: SurfaceTool,entry: Dictionary) -> void:
	var w=float(entry.size[0]); var h=float(entry.size[1]); var d=float(entry.size[2]); var v=int(entry.variant)
	var accent: Color=[Color("355e59"),Color("a54b34"),Color("39546b"),Color("8b7139")][v]
	# Foundation, string course, corner trim and rear service door.
	box(track,st,Vector3(w+0.08,0.65,d+0.08),Vector3(0,0.33,0),Color("797c70"))
	for x in [-w/2,w/2]:
		for z in [-d/2,d/2]: box(track,st,Vector3(0.28,h,0.28),Vector3(x,h/2,z),TRIM.darkened(0.1))
	box(track,st,Vector3(2,2.8,0.15),Vector3(0,1.4,-d/2-0.1),SHADOW)
	# Side elevations matter from the oblique gameplay camera, not only the front.
	for side in [-1,1]:
		for z in [-d*0.28,d*0.28]:
			box(track,st,Vector3(0.15,2.2,2.1),Vector3(side*(w/2+0.04),h*0.6,z),TRIM)
			box(track,st,Vector3(0.2,1.9,1.8),Vector3(side*(w/2+0.1),h*0.6,z),GLASS)
			box(track,st,Vector3(0.22,0.1,1.8),Vector3(side*(w/2+0.13),h*0.6,z),TRIM)
	if entry.kind=="warehouse":
		for x in [-w*0.27,w*0.27]:
			box(track,st,Vector3(6.5,4.8,0.16),Vector3(x,2.4,d/2+0.08),SHADOW)
			box(track,st,Vector3(6,4.5,0.2),Vector3(x,2.25,d/2+0.12),accent)
			for y in range(1,9): box(track,st,Vector3(6,0.07,0.23),Vector3(x,y*0.5,d/2+0.14),accent.lightened(0.16))
			box(track,st,Vector3(4.8,0.65,0.26),Vector3(x,3.7,d/2+0.18),GLASS)
			# Hazard marks sit on the existing wall, not freestanding bollards.
			for sign_value in [-1,1]:
				for y in range(6): box(track,st,Vector3(0.32,0.3,0.22),Vector3(x+sign_value*3.18,0.3+y*0.3,d/2+0.1),Color("d5aa42") if y%2==0 else SHADOW)
		for x in range(-int(w/2)+1,int(w/2),2):
			box(track,st,Vector3(0.12,h,0.14),Vector3(x,h/2,-d/2-0.08),TRIM.darkened(0.3))
		box(track,st,Vector3(w,0.65,0.22),Vector3(0,h-0.8,d/2+0.12),accent)
	elif entry.kind=="shop":
		for side in [-1,1]:
			for x in [-w*0.3,0.0,w*0.3]: window(track,st,x,h*0.7,side*(d/2+0.08),2,2.3,side)
			box(track,st,Vector3(w+0.35,0.25,0.5),Vector3(0,4.1,side*d/2),TRIM)
		for x in [-w*0.30,w*0.30]: window(track,st,x,1.95,d/2+0.08,4.1,2.65,1)
		box(track,st,Vector3(2.1,3.2,0.16),Vector3(0,1.6,d/2+0.12),accent)
		box(track,st,Vector3(1.55,1.9,0.22),Vector3(0,2,d/2+0.16),GLASS)
		box(track,st,Vector3(w-0.5,0.78,0.3),Vector3(0,4.7,d/2+0.12),accent)
		# Alternating canvas bands read at handheld scale without tiny UI text.
		for i in range(int(w)):
			box(track,st,Vector3(1,0.24,1.65),Vector3(-w/2+0.5+i,3.7,d/2+0.65),accent if i%2==0 else TRIM)
		for x in [-w*0.46,w*0.46]: box(track,st,Vector3(0.3,h-0.6,0.35),Vector3(x,(h-0.6)/2,d/2+0.08),TRIM)
	else:
		for side in [-1,1]:
			for x in [-w*0.28,w*0.28]:
				window(track,st,x,h*0.64,side*(d/2+0.08),2,2,side)
				for offset in [-1.4,1.4]: box(track,st,Vector3(0.55,2.25,0.18),Vector3(x+offset,h*0.64,side*(d/2+0.12)),accent)
		box(track,st,Vector3(2.1,3,0.18),Vector3(0,1.5,d/2+0.1),accent)
		box(track,st,Vector3(0.85,1,0.22),Vector3(0,2.1,d/2+0.14),GLASS)
		# Shallow porch canopy only; ground stays drivable right up to the wall.
		box(track,st,Vector3(3,0.2,1.8),Vector3(0,3.2,d/2+0.65),accent.darkened(0.2))
		for y in range(1,int(h*2)):
			box(track,st,Vector3(w,0.045,0.03),Vector3(0,y*0.5,-d/2-0.02),Color("8e826c"))

static func roof_details(track: Node3D,st: SurfaceTool,entry: Dictionary) -> void:
	var w=float(entry.size[0]); var h=float(entry.size[1]); var d=float(entry.size[2]); var v=int(entry.variant)
	if entry.kind=="house":
		box(track,st,Vector3(0.24,0.20,d+1.1),Vector3(0,h+3,0),Color("563f35"))
		for x in [-w/2-0.45,w/2+0.45]: box(track,st,Vector3(0.2,0.3,d+1.2),Vector3(x,h,0),TRIM)
		box(track,st,Vector3(1.2,3,1.2),Vector3(w*0.23,h+1.1,-d*0.2),Color("8a5843"))
		box(track,st,Vector3(1.5,0.2,1.5),Vector3(w*0.23,h+2.65,-d*0.2),TRIM.darkened(0.2))
	else:
		# Parapets, roof seams, skylights and exhausts stay on the hidden roof node.
		for side in [-1,1]:
			box(track,st,Vector3(w+0.6,0.65,0.38),Vector3(0,h+0.4,side*d/2),TRIM.darkened(0.12))
			box(track,st,Vector3(0.38,0.65,d),Vector3(side*w/2,h+0.4,0),TRIM.darkened(0.12))
		if entry.kind=="shop":
			box(track,st,Vector3(w*0.55,0.8,0.5),Vector3(0,h+0.9,d/2),TRIM)
			box(track,st,Vector3(2.5,0.8,2),Vector3(w*0.25,h+0.65,-d*0.2),Color("81897e"))
		else:
			for x in range(-int(w/2)+2,int(w/2),2): box(track,st,Vector3(0.07,0.09,d-1),Vector3(x,h+0.29,0),Color("899087"))
			for z in [-d*0.25,d*0.25]:
				box(track,st,Vector3(w*0.6,0.35,2),Vector3(0,h+0.4,z),Color("8fada9"))
			box(track,st,Vector3(1.5,1.3,1.5),Vector3(w*0.34,h+0.8,-d*0.32),Color("888477"))
			if v%2==0: box(track,st,Vector3(0.7,3,0.7),Vector3(-w*0.35,h+1.5,-d*0.3),Color("684c3b"))
