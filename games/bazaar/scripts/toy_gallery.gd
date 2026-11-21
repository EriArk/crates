# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D

const SITE := Vector3(-9,0,19)
const MARKS := [Vector2(-1.42,.94),Vector2(0,.94),Vector2(1.42,.94),Vector2(-.78,1.82),Vector2(.78,1.82)]
const COATS := ["fa9c9c","7ab68c","dfaf61","8fc9df","ac9ad5"]
var toys: Array[Node3D] = []
var eye: Camera3D
var aim := Vector2(0,1.32)
var sight: Node3D
var launcher: Node3D
var cork: MeshInstance3D
var topple: Tween
var flight: Tween
var sound := AudioStreamPlayer.new()
var sphere := SphereMesh.new()
var paints := {}

func part(parent: Node3D, pos: Vector3, size_: Vector3, color: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh=sphere
	if not paints.has(color):
		var mat:=StandardMaterial3D.new()
		mat.albedo_color=Color(color)
		mat.roughness=.94
		mat.emission_enabled=true
		mat.emission=Color(color)
		mat.emission_energy_multiplier=.22
		if color in ["fff6c5","ff764c"]:mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		paints[color]=mat
	mesh.material_override=paints[color]
	parent.add_child(mesh)
	mesh.position=pos
	mesh.scale=size_
	return mesh

func build(s) -> void:
	position=SITE
	sphere.radial_segments=14
	sphere.rings=8
	s.block(SITE+Vector3(0,1.38,-.43),Vector3(4.45,2.76,.2),"244e59")
	for x in [-2.22,2.22]:
		s.block(SITE+Vector3(x,1.41,.03),Vector3(.15,2.82,.72),"99573d")
		s.lantern(SITE+Vector3(x,2.48,.44),"ffc978")
	for i in 11:
		s.block(SITE+Vector3((i-5)*.42,2.67,0),Vector3(.42,.21,1.05),"cb5c4e" if i%2 else "f5dc9d",false)
	for h in [.62,1.50]:
		s.block(SITE+Vector3(0,h-.045,-.02),Vector3(4.4,.09,.61),"d4a36c")
	s.block(SITE+Vector3(0,.28,-.04),Vector3(4.4,.57,.7),"9f5540")
	s.text3d("TOY GALLERY",SITE+Vector3(0,2.37,-.31),.006)
	for i in MARKS.size():
		var toy:=Node3D.new()
		add_child(toy)
		var mark:Vector2=MARKS[i]
		toy.position=Vector3(mark.x,mark.y-.32,0)
		toys.append(toy)
		var coat:String=COATS[i]
		part(toy,Vector3(0,.21,0),Vector3(.41,.37,.34),coat)
		part(toy,Vector3(0,.40,.015),Vector3(.48,.38,.37),coat)
		for side in [-1,1]:
			part(toy,Vector3(side*.14,.08,.11),Vector3(.15,.12,.18),coat)
			part(toy,Vector3(side*.23,.24,.02),Vector3(.13,.20,.15),coat).rotation.z=side*.35
			if i==0:
				part(toy,Vector3(side*.12,.64,0),Vector3(.12,.32,.12),coat).rotation.z=-side*.15
				part(toy,Vector3(side*.12,.65,.056),Vector3(.054,.21,.035),"fbd3bd").rotation.z=-side*.15
			elif i==4:
				var ear:=part(toy,Vector3(side*.15,.57,0),Vector3(.17,.19,.14),coat)
				var tip:=CylinderMesh.new()
				tip.top_radius=0;tip.bottom_radius=.55;tip.height=1
				tip.radial_segments=4;ear.mesh=tip
				part(toy,Vector3(side*.16,.37,.17),Vector3(.10,.014,.02),"69587f").rotation.z=side*.18
			elif i in [1,2]:
				part(toy,Vector3(side*.16,.555,0),Vector3(.15,.22 if i==4 else .14,.13),coat)
			var face:=Vector3(side*.15,.555,.073) if i==1 else Vector3(side*.087,.43,.185)
			part(toy,face,Vector3(.045,.057,.025),"302f43")
			part(toy,face+Vector3(-.007,.011,.012),Vector3.ONE*.013,"fff1d2")
			if i==2:part(toy,Vector3(side*.034,.365,.185),Vector3(.116,.096,.065),"ffdeb6")
		part(toy,Vector3(0,.365,.195),Vector3(.15 if i==3 else .071,.066,.08),"efaa55" if i==3 else "704a4a")
		part(toy,Vector3(0,.18,.151),Vector3(.23,.22,.065),"ffdeb6")
		if i==1:part(toy,Vector3(0,.337,.176),Vector3(.12,.017,.024),"456d54")
		if i==3:part(toy,Vector3(.035,.595,0),Vector3(.1,.13,.09),coat).rotation.z=-.4
	s.destinations.append({"title":"Festival toy gallery","festival":"gallery","position":SITE+Vector3(0,0,1.28)})
	sight=Node3D.new()
	add_child(sight)
	for i in 4:
		var line:=part(sight,Vector3(cos(i*PI/2)*.064,sin(i*PI/2)*.064,0),Vector3(.064,.012,.012),"fff6c5")
		line.rotation.z=i*PI/2
	part(sight,Vector3.ZERO,Vector3.ONE*.019,"ff764c")
	launcher=Node3D.new()
	add_child(launcher)
	part(launcher,Vector3(0,-.04,.09),Vector3(.105,.14,.55),"b5774e")
	for band in [[-.13,.40,.049,"408486"],[-.33,.052,.055,"e8bd67"],[.015,.055,.055,"e8bd67"],[-.363,.032,.037,"bc8859"]]:
		var barrel:=part(launcher,Vector3(0,.03,band[0]),Vector3.ONE,band[3])
		var tube:=CylinderMesh.new()
		tube.height=band[1];tube.top_radius=band[2];tube.bottom_radius=band[2];tube.radial_segments=16
		barrel.mesh=tube
		barrel.rotation.x=PI/2
	cork=part(self,Vector3.ZERO,Vector3.ONE*.07,"eabe77")
	add_child(sound)
	end()

func begin(camera: Camera3D) -> void:
	eye=camera
	aim=Vector2(0,1.32)
	camera.global_position=SITE+Vector3(0,1.55,3.8)
	camera.look_at(SITE+Vector3(0,1.25,0))
	camera.fov=50
	launcher.position=Vector3(.32,1.33,2.94)
	launcher.show()
	sight.show()
	point(aim)

func point(p: Vector2) -> void:
	aim=p.clamp(Vector2(-1.96,.65),Vector2(1.96,2.18))
	sight.position=Vector3(aim.x,aim.y,0).lerp(to_local(eye.global_position),.075)
	launcher.look_at(to_global(Vector3(aim.x,aim.y,0)))

func pointer(camera: Camera3D, pixel: Vector2) -> void:
	var at=camera.project_ray_origin(pixel)
	var ray=camera.project_ray_normal(pixel)
	if ray.z>=-.01:return
	var hit:Vector3=to_local(at+ray*((global_position.z-at.z)/ray.z))
	point(Vector2(hit.x,hit.y))

func volley(p: Vector2, audible: bool) -> void:
	if flight:flight.kill()
	cork.position=launcher.position-launcher.transform.basis.z*.35
	cork.show()
	flight=create_tween()
	flight.tween_property(cork,"position",Vector3(p.x,p.y,.1),.11)
	flight.tween_callback(cork.hide)
	if audible:
		sound.stream=preload("res://assets/audio/metal0.wav")
		sound.pitch_scale=1.8
		sound.volume_db=-13
		sound.play()

func settle(shots: Array, audible: bool) -> void:
	restore(shots.slice(0,shots.size()-1))
	var hit:=int(shots.back().target)
	if hit<0:return
	var toy:=toys[hit]
	topple=create_tween()
	topple.tween_property(toy,"rotation:x",-.5,.12).set_trans(Tween.TRANS_SINE)
	topple.tween_property(toy,"scale",Vector3.ONE*.05,.14)
	topple.tween_callback(toy.hide)
	if audible:
		sound.stream=preload("res://assets/audio/voice3.wav")
		sound.pitch_scale=1.45
		sound.volume_db=-10
		sound.play()

func restore(attempts: Array) -> void:
	if topple:topple.kill()
	for toy in toys:
		toy.show()
		toy.scale=Vector3.ONE
		toy.rotation=Vector3.ZERO
	for shot in attempts:
		if int(shot.target)>=0:toys[int(shot.target)].hide()

func end() -> void:
	sight.hide()
	launcher.hide()
	cork.hide()
	if flight:flight.kill()
	restore([])
