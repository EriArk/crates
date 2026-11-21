# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D

const SITE := Vector3(-9,0,21.6)
const MARKS := [Vector2(-1.42,.94),Vector2(0,.94),Vector2(1.42,.94),Vector2(-.78,1.82),Vector2(.78,1.82)]
const RACK_Z := -2.4
const TRAVEL := .28
const Trim = preload("festival_trim.gd")
const Plush = preload("festival_plush.gd")
var rail_time := 0.0
var in_flight := false
var pending_result := []
var hit_sound := false
var ribbons: Array[Label3D]=[]
var toys: Array[Node3D] = []
var runners: Array[MeshInstance3D] = []
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
	var rack:=SITE+Vector3.BACK*RACK_Z
	s.block(rack+Vector3(0,1.42,-.5),Vector3(5.12,2.84,.20),"33434b")
	Trim.landscape(s,rack+Vector3(0,1.42,-.394),Vector2(4.96,2.7))
	for x in [-2.52,2.52]:
		s.block(rack+Vector3(x,1.49,.02),Vector3(.14,2.98,.64),"884e3e")
		s.lantern(rack+Vector3(x,2.52,.48),"ffc978")
	Trim.valance(s,rack+Vector3(0,2.97,0),5.36,["85434d","ad5652","85434d","dbac72"],12)
	for h in [.62,1.50]:
		s.block(rack+Vector3(0,h-.055,-.02),Vector3(4.86,.11,.61),"975f49")
		s.block(rack+Vector3(0,h-.018,.30),Vector3(4.82,.034,.038),"f2ba76",false)
	s.block(rack+Vector3(0,.28,-.04),Vector3(5.02,.57,.70),"496966")
	s.block(rack+Vector3(0,2.55,-.32),Vector3(2.34,.33,.08),"283942",false)
	s.text3d("TOY GALLERY",rack+Vector3(0,2.55,-.27),.0055)
	# The visitor aims across the lane from the counter on the promenade.
	s.block(SITE+Vector3(0,.48,.08),Vector3(4.3,.96,.52),"995849")
	s.block(SITE+Vector3(0,.98,.08),Vector3(4.42,.075,.62),"eec18c")
	for side in [-1,1]:
		s.block(SITE+Vector3(side*2.09,.57,.355),Vector3(.08,.66,.035),"e5ae70",false)
	var shoe:=CylinderMesh.new()
	shoe.top_radius=.24;shoe.bottom_radius=.215;shoe.height=.042;shoe.radial_segments=16
	var enamel:=StandardMaterial3D.new()
	enamel.albedo_color=Color("dca96f");enamel.roughness=.67;shoe.material=enamel
	for i in MARKS.size():
		var toy:=Plush.create(i)
		add_child(toy)
		var mark:Vector2=MARKS[i]
		toy.position=Vector3(mark.x,mark.y-.32,RACK_Z)
		toys.append(toy)
		var runner:=MeshInstance3D.new()
		runner.mesh=shoe;runner.position=toy.position+Vector3.UP*.008
		add_child(runner);runners.append(runner)
	var shelf:=SITE+Vector3(-3.92,.76,.18)
	s.block(shelf+Vector3(0,-.37,0),Vector3(2.87,.74,.89),"927055")
	Trim.landscape(s,shelf+Vector3(0,.43,-.42),Vector2(2.84,.92))
	s.block(shelf,Vector3(2.96,.085,.95),"eabc83")
	s.text3d("PRIZE SHELF",shelf+Vector3(0,-.26,.46),.0045)
	for i in Plush.NAMES.size():
		var plush:=Plush.create(i)
		add_child(plush)
		plush.position=to_local(shelf)+Vector3((i-2)*.53,.045,0)
		plush.scale=Vector3.ONE*.79
		var nameplate:=shelf+Vector3((i-2)*.53,-.068,.465)
		s.block(nameplate,Vector3(.50,.122,.028),"395751",false)
		var caption:Label3D=s.text3d(Plush.NAMES[i],nameplate+Vector3.BACK*.019,.0018)
		caption.visibility_range_end=5.0
		var ribbon:Label3D=s.text3d("★",shelf+Vector3((i-2)*.53,.155,.23),.004)
		ribbon.modulate=Color("ffd160")
		for side in [-1,1]:
			var tail:=MeshInstance3D.new()
			var strip:=BoxMesh.new()
			strip.size=Vector3(.046,.105,.012)
			var cloth:=StandardMaterial3D.new()
			cloth.albedo_color=Color("b84250")
			tail.mesh=strip;tail.material_override=cloth
			ribbon.add_child(tail)
			tail.position=Vector3(side*.023,-.071,-.01)
			tail.rotation.z=side*.27
		ribbon.hide()
		ribbons.append(ribbon)
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
	camera.global_position=SITE+Vector3(0,1.74,4.15)
	camera.look_at(SITE+Vector3(0,1.08,RACK_Z))
	camera.fov=38
	launcher.position=Vector3(.28,1.49,3.34)
	launcher.show()
	sight.show()
	point(aim)

func point(p: Vector2) -> void:
	aim=p.clamp(Vector2(-2.34,.49),Vector2(2.34,2.34))
	sight.position=Vector3(aim.x,aim.y,RACK_Z).lerp(to_local(eye.global_position),.075)
	launcher.look_at(to_global(Vector3(aim.x,aim.y,RACK_Z)))

func pointer(camera: Camera3D, pixel: Vector2) -> void:
	var at=camera.project_ray_origin(pixel)
	var ray=camera.project_ray_normal(pixel)
	if ray.z>=-.01:return
	var hit:Vector3=to_local(at+ray*((global_position.z+RACK_Z-at.z)/ray.z))
	point(Vector2(hit.x,hit.y))

func rail_offset(row: int, time: float) -> float:
	return .52*sin(time*2.70) if row==0 else .60*sin(time*2.20+1.25)

func _process(delta: float) -> void:
	if not sight or not sight.visible:return
	rail_time=fmod(rail_time+delta,TAU*20)
	for i in toys.size():
		toys[i].position.x=MARKS[i].x+rail_offset(0 if i<3 else 1,rail_time)
		runners[i].position.x=toys[i].position.x

func ticket_impact() -> Vector2:
	# SDK coordinates are measured on the moving rack at the instant of impact.
	var row:=0 if aim.y<1.38 else 1
	return Vector2(aim.x-rail_offset(row,rail_time+TRAVEL),aim.y)

func volley(p: Vector2, audible: bool) -> void:
	if in_flight:return
	in_flight=true
	pending_result.clear()
	var start:=launcher.position-launcher.transform.basis.z*.35
	var finish:=Vector3(p.x,p.y,RACK_Z+.11)
	cork.position=start
	cork.show()
	flight=create_tween()
	flight.tween_method(func(t:float):
		cork.position=start.lerp(finish,t)+Vector3.UP*(4.9*TRAVEL*TRAVEL*t*(1.0-t)),0.0,1.0,TRAVEL)
	flight.tween_callback(func():
		cork.hide()
		in_flight=false
		if not pending_result.is_empty():settle(pending_result,hit_sound))
	if audible:
		sound.stream=preload("res://assets/audio/metal0.wav")
		sound.pitch_scale=1.8
		sound.volume_db=-13
		sound.play()

func settle(shots: Array, audible: bool) -> void:
	if in_flight:
		pending_result=shots.duplicate();hit_sound=audible;return
	restore(shots.slice(0,shots.size()-1))
	var hit:=int(shots.back().target)
	if hit<0:return
	var toy:=toys[hit]
	topple=create_tween()
	topple.tween_property(toy,"rotation:x",-1.35,.14).set_trans(Tween.TRANS_SINE)
	topple.parallel().tween_property(toy,"position:z",RACK_Z-.26,.14)
	topple.tween_property(toy,"position:y",toy.position.y-.30,.12)
	topple.tween_callback(toy.hide)
	if audible:
		sound.stream=preload("res://assets/audio/voice3.wav")
		sound.pitch_scale=1.45
		sound.volume_db=-10
		sound.play()

func restore(attempts: Array) -> void:
	if topple:topple.kill()
	for i in toys.size():
		var toy:=toys[i]
		toy.position=Vector3(MARKS[i].x+rail_offset(0 if i<3 else 1,rail_time),MARKS[i].y-.32,RACK_Z)
		runners[i].position.x=toy.position.x
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
	in_flight=false;pending_result.clear()
	restore([])

func show_collection(won: Array) -> void:
	for i in ribbons.size():ribbons[i].visible=Plush.NAMES[i] in won
