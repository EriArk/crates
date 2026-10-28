# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
# Game-owned props and pose only. Appearance, clothing and facial rig are SDK-owned.
var model: Node3D
var skeleton: Skeleton3D
var wheel: Node3D
var seated: Array[Transform3D] = []
var grips: Array[Vector3] = []
var hand_errors: Array[float] = []
var foot_errors: Array[float] = []
var pedals: Dictionary = {}
var foot_rest: Dictionary = {}

func material_for(color: String, metallic: float = 0.0) -> StandardMaterial3D:
	var mat=StandardMaterial3D.new(); mat.albedo_color=Color(color); mat.roughness=0.65; mat.metallic=metallic
	return mat

func box(parent: Node3D, dimensions: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh=MeshInstance3D.new(); var shape=BoxMesh.new(); shape.size=dimensions
	mesh.mesh=shape; mesh.position=at; mesh.material_override=mat; parent.add_child(mesh)
	return mesh

func shell(points: PackedVector2Array, depth: float, z: float, mat: Material) -> MeshInstance3D:
	var surface=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles=Geometry2D.triangulate_polygon(points)
	for side in [-1,1]:
		for offset in range(0,triangles.size(),3):
			for j in ([0,1,2] if side>0 else [2,1,0]):
				var point=points[triangles[offset+j]]
				surface.add_vertex(Vector3(point.x,point.y,z+depth*0.5*side))
	for i in points.size():
		var a=points[i]; var b=points[(i+1)%points.size()]
		for v in [Vector3(a.x,a.y,z-depth*0.5),Vector3(b.x,b.y,z-depth*0.5),Vector3(b.x,b.y,z+depth*0.5),Vector3(a.x,a.y,z-depth*0.5),Vector3(b.x,b.y,z+depth*0.5),Vector3(a.x,a.y,z+depth*0.5)]: surface.add_vertex(v)
	surface.generate_normals()
	var mesh=MeshInstance3D.new(); mesh.mesh=surface.commit(); mesh.material_override=mat; add_child(mesh)
	return mesh

func cushion(dimensions: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var node=MeshInstance3D.new(); var shape=SphereMesh.new(); shape.radial_segments=16; shape.rings=8
	node.mesh=shape; node.scale=dimensions; node.position=at; node.material_override=mat; add_child(node)
	return node

func recline(part: Node3D) -> Node3D:
	var rotation_basis=Basis(Vector3.RIGHT,deg_to_rad(-20))
	var pivot=Vector3(0,0.26,-0.22)
	part.transform=Transform3D(rotation_basis,pivot-rotation_basis*pivot)*part.transform
	return part

func rotate_bone(name: String, angle: float) -> void:
	var bone=skeleton.find_bone(name)
	var value=skeleton.get_bone_global_pose(bone)
	var axis=skeleton.global_basis.inverse()*global_basis.x
	value.basis=Basis(axis.normalized(),deg_to_rad(angle))*value.basis
	skeleton.set_bone_global_pose(bone,value)

func solve_limb(first: String, second: String, last: String, target: Vector3, pole: Vector3) -> void:
	var upper=skeleton.find_bone(first); var lower=skeleton.find_bone(second); var end=skeleton.find_bone(last)
	var origin=bone_position(first); var joint=bone_position(second); var tip=bone_position(last)
	var a=origin.distance_to(joint); var b=joint.distance_to(tip)
	var axis=(target-origin).normalized(); var distance=clampf(origin.distance_to(target),absf(a-b)+0.001,a+b-0.001)
	var along=(a*a-b*b+distance*distance)/(2*distance)
	var perpendicular=(pole-axis*pole.dot(axis)).normalized()
	var bend=origin+axis*along+perpendicular*sqrt(maxf(0,a*a-along*along))
	aim_bone(upper,lower,bend); aim_bone(lower,end,target)

func build(avatar: Node3D) -> bool:
	model=avatar
	var charcoal=material_for("172731"); var padding=material_for("344d5c"); var trim=material_for("d9a12e"); var steel=material_for("738994",0.65)
	box(self,Vector3(0.29,0.04,0.27),Vector3(0,0.215,-0.105),charcoal)
	cushion(Vector3(0.265,0.025,0.255),Vector3(0,0.238,-0.105),padding)
	# Sculpted bucket back: broad shoulder wings, narrow waist and integrated headrest.
	recline(shell(PackedVector2Array([Vector2(-0.115,0.24),Vector2(0.115,0.24),Vector2(0.13,0.43),Vector2(0.17,0.55),Vector2(0.145,0.60),Vector2(0.105,0.63),Vector2(0.09,0.70),Vector2(-0.09,0.70),Vector2(-0.105,0.63),Vector2(-0.145,0.60),Vector2(-0.17,0.55),Vector2(-0.13,0.43)]),0.045,-0.25,charcoal))
	recline(cushion(Vector3(0.24,0.17,0.045),Vector3(0,0.44,-0.215),padding))
	recline(cushion(Vector3(0.17,0.055,0.04),Vector3(0,0.655,-0.22),padding))
	for side in [-1,1]:
		var bolster=cushion(Vector3(0.048,0.15,0.09),Vector3(side*0.13,0.435,-0.21),charcoal); bolster.rotation.z=side*deg_to_rad(-10); recline(bolster)
		var seam=cushion(Vector3(0.012,0.14,0.035),Vector3(side*0.147,0.44,-0.187),trim); seam.rotation.z=side*deg_to_rad(-10); recline(seam)
		cushion(Vector3(0.04,0.028,0.23),Vector3(side*0.13,0.25,-0.105),charcoal)
		recline(box(self,Vector3(0.045,0.016,0.01),Vector3(side*0.052,0.605,-0.222),charcoal))
	# Two independent pedal pads; no chassis, column, legs or floor platform.
	for side in ["L","R"]:
		var pedal=Node3D.new(); pedal.name="BrakePedal" if side=="L" else "ThrottlePedal"
		pedal.position=Vector3(0.085 if side=="L" else -0.085,0.065,0.145); add_child(pedal); pedals[side]=pedal
		box(pedal,Vector3(0.078,0.14,0.012),Vector3(0,0.07,0),steel)
		for y in [0.025,0.05,0.075,0.10,0.125]: box(pedal,Vector3(0.056,0.007,0.003),Vector3(0,y,0.008),charcoal)
	wheel=Node3D.new(); wheel.position=Vector3(0,0.405,-0.055); wheel.rotation.x=deg_to_rad(-18); add_child(wheel)
	var ring=MeshInstance3D.new(); var torus=TorusMesh.new(); torus.inner_radius=0.084; torus.outer_radius=0.105; torus.rings=24; torus.ring_segments=8
	ring.mesh=torus; ring.rotation.x=PI/2; ring.material_override=charcoal; wheel.add_child(ring)
	box(wheel,Vector3(0.18,0.014,0.016),Vector3.ZERO,steel)
	box(wheel,Vector3(0.014,0.09,0.016),Vector3(0,-0.04,0),steel)
	box(wheel,Vector3(0.04,0.03,0.025),Vector3.ZERO,trim)
	box(wheel,Vector3(0.012,0.018,0.025),Vector3(0,0.094,0),trim)
	if model==null: return true # Empty chair is the explicit no-profile fallback.
	add_child(model)
	var skeletons=model.find_children("*","Skeleton3D",true,false)
	if skeletons.is_empty(): return false
	skeleton=skeletons[0]
	for side in ["L","R"]:
		for name in ["upper_arm.","forearm.","hand.","middle.01.","thigh.","shin.","foot.","toes."]:
			if skeleton.find_bone(name+side)<0: return false
	if skeleton.find_bone("spine")<0 or skeleton.find_bone("neck")<0: return false
	if not model.play_action("sit"): return false
	model.animation_player.seek(1.5,true); model.animation_player.pause()
	for side in ["L","R"]: foot_rest[side]=global_basis.inverse()*skeleton.global_basis*skeleton.get_bone_global_rest(skeleton.find_bone("foot."+side)).basis
	rotate_bone("spine",-20); rotate_bone("neck",12)
	for i in skeleton.get_bone_count(): seated.append(skeleton.get_bone_pose(i))
	pose(0)
	return true

func bone_position(name: String) -> Vector3:
	return to_local(skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(name)).origin)

func aim_bone(index: int, child: int, target: Vector3) -> void:
	var pose_now=skeleton.get_bone_global_pose(index)
	var current=skeleton.get_bone_global_pose(child).origin-pose_now.origin
	var desired=skeleton.to_local(to_global(target))-pose_now.origin
	if current.length_squared()<0.000001 or desired.length_squared()<0.000001: return
	pose_now.basis=Basis(Quaternion(current.normalized(),desired.normalized()))*pose_now.basis
	skeleton.set_bone_global_pose(index,pose_now)

func pose(steer: float, throttle: float = 0.0, brake: float = 0.0) -> void:
	wheel.rotation.z=deg_to_rad(35)*clampf(steer,-1,1)
	for side in pedals:
		pedals[side].rotation.x=deg_to_rad(35+25*clampf(brake if side=="L" else throttle,0,1))
	if skeleton==null: return
	# Restore the sampled Sit pose before solving, so rotations never accumulate.
	for i in skeleton.get_bone_count(): skeleton.set_bone_pose(i,seated[i])
	grips.clear(); hand_errors.clear(); foot_errors.clear()
	for side in ["L","R"]:
		var sign_value=1.0 if side=="L" else -1.0
		var target=to_local(wheel.to_global(Vector3(sign_value*0.094,0,0)))
		solve_limb("upper_arm."+side,"forearm."+side,"hand."+side,target,Vector3(sign_value*0.5,-1,0))
		var hand=skeleton.find_bone("hand."+side)
		# Aim the palms around the rim, then curl the existing finger joints.
		aim_bone(hand,skeleton.find_bone("middle.01."+side),target+Vector3(-sign_value*0.015,-0.05,0))
		for finger in ["index","middle","ring","pinky"]:
			for segment in ["01","02","03"]:
				var bone=skeleton.find_bone(finger+"."+segment+"."+side)
				if bone<0: continue
				var bent=skeleton.get_bone_global_pose(bone)
				var finger_axis=skeleton.global_basis.inverse()*global_basis.x
				bent.basis=Basis(finger_axis.normalized(),deg_to_rad(25 if segment=="01" else 60))*bent.basis
				skeleton.set_bone_global_pose(bone,bent)
		grips.append(target); hand_errors.append(bone_position("hand."+side).distance_to(target))
		var pedal: Node3D=pedals[side]
		var ankle=to_local(pedal.to_global(Vector3(0,0.02,-0.09)))
		solve_limb("thigh."+side,"shin."+side,"foot."+side,ankle,Vector3(sign_value*0.1,1,0))
		# The toe joint slopes downward in the rest rig; aiming that joint directly
		# would drive the sole through the pedal. Align the actual rest sole plane.
		var pedal_basis=global_basis.inverse()*pedal.global_basis
		var sole_rotation=Basis(pedal_basis.x,-pedal_basis.z,pedal_basis.y)
		var foot=skeleton.find_bone("foot."+side)
		var foot_pose=skeleton.get_bone_global_pose(foot)
		foot_pose.basis=skeleton.global_basis.inverse()*global_basis*sole_rotation*foot_rest[side]
		skeleton.set_bone_global_pose(foot,foot_pose)
		foot_errors.append(bone_position("foot."+side).distance_to(ankle))
