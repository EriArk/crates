# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
## Presentation only. Absolute shot time keeps contacts and particle age correct
## when render frames are skipped. No RNG or writes to authoritative state.
const Surface = preload("res://scripts/green_surface.gd")
const LIMIT := 128
var grid := PackedInt32Array()
var events: Array = []
var cursor := 0
var clock := 0.0
var pool: Array = []
var active: Array = []
var meshes: Dictionary = {}

func _ready() -> void:
	var grain := SphereMesh.new()
	grain.radius=0.5; grain.height=1; grain.radial_segments=6; grain.rings=3
	var chip := BoxMesh.new(); chip.size=Vector3.ONE
	var streak := CapsuleMesh.new(); streak.radius=0.5; streak.height=2; streak.radial_segments=8; streak.rings=2
	var ring := TorusMesh.new()
	ring.inner_radius=0.96; ring.outer_radius=1.0; ring.rings=48; ring.ring_segments=6
	meshes={"grain":grain,"chip":chip,"ring":ring,"trail":streak}

func clear() -> void:
	events.clear(); cursor=0; clock=0
	for item in active: item.node.visible=false
	active.clear()

func point(shot: Dictionary, frame: int) -> Vector3:
	return Vector3(shot.path[frame][0],shot.heights[frame],shot.path[frame][1])/1000.0

func floor_at(p: Vector3) -> Vector3:
	return Vector3(p.x,Surface.sample(grid,roundi(p.x*1000),roundi(p.z*1000))[0]/1000.0+0.045,p.z)

func sandy(p: Vector3, course: Dictionary) -> bool:
	for rect in course.sand:
		if p.x*1000>=rect[0] and p.x*1000<=rect[2] and p.z*1000>=rect[1] and p.z*1000<=rect[3]: return true
	return false

func schedule(kind: String, time: float, pos: Vector3, strength: float=1.0, direction: Vector3=Vector3.ZERO) -> void:
	events.append({"kind":kind,"time":time,"pos":pos,"strength":strength,"direction":direction})

func begin(shot: Dictionary, course: Dictionary) -> void:
	clear(); grid=course.height_grid
	var start := floor_at(point(shot,0))
	var force := clampf(point(shot,mini(1,shot.path.size()-1)).distance_to(point(shot,0))*shot.hz/8.4,0.1,1)
	schedule("strike_sand" if sandy(start,course) else "strike",0,start,force)
	for frame in shot.bounces:
		var p := point(shot,frame)
		var incoming := p-point(shot,maxi(frame-1,0))
		var outgoing := point(shot,mini(frame+1,shot.path.size()-1))-p
		# The impulse normal locates the surface contact on the sphere, not its centre.
		var normal := (outgoing-incoming).normalized()
		var contact := p-normal*0.18
		var wood := absf(contact.x)>4.95 or absf(contact.z)>7.95
		schedule("wood" if wood else "stone",frame/float(shot.hz),contact,clampf(incoming.length()*shot.hz/8.4,0.15,1),normal)
	for frame in shot.rims:
		schedule("rim",frame/float(shot.hz),floor_at(point(shot,frame)),0.4)
	var end: int = shot.capture_frame if shot.capture_frame>=0 else shot.path.size()-1
	# Fixed sampling cadence; trails do not bridge collisions or continue in the cup.
	for frame in range(6,end,6):
		var p := point(shot,frame)
		var previous := point(shot,frame-6)
		var velocity: Vector3 = (p-previous)*shot.hz/6.0
		var crossed := false
		for bounce in shot.bounces:
			if bounce>frame-6 and bounce<=frame: crossed=true; break
		if crossed: continue
		if sandy(p,course) and velocity.length()>0.5:
			schedule("sand",frame/float(shot.hz),floor_at(p),clampf(velocity.length()/4,0.2,1),-velocity.normalized())
		elif velocity.length()>3.0:
			schedule("trail",frame/float(shot.hz),(p+previous)/2,velocity.length()/8.4,p-previous)
	if shot.sunk:
		var pin := floor_at(Vector3(course.cup[0]/1000.0,0,course.cup[1]/1000.0))
		var ace: bool = shot.strokes[shot.player]==1
		schedule("ace" if ace else "cup",(shot.path.size()-1)/float(shot.hz),pin)
	events.sort_custom(func(a,b): return a.time<b.time)
	seek(0)

func acquire() -> Dictionary:
	for item in pool:
		if not item.node.visible: return item
	if pool.size()>=LIMIT: return {}
	var node := MeshInstance3D.new()
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	node.material_override=mat; add_child(node)
	var item := {"node":node,"mat":mat}
	pool.append(item)
	return item

func particle(shape: String, time: float, pos: Vector3, velocity: Vector3, color: Color, size: Vector3, life: float, gravity: float=3.0, basis: Basis=Basis.IDENTITY) -> void:
	if clock-time>=life: return # A stale contact never flashes at the current ball.
	var item := acquire()
	if item.is_empty(): return
	item.merge({"born":time,"pos":pos,"velocity":velocity,"color":color,"size":size,"life":life,"gravity":gravity,"basis":basis,"shape":shape},true)
	item.node.mesh=meshes[shape]; item.node.visible=true
	active.append(item)

func halo(event: Dictionary, color: Color, radius: float, life: float) -> void:
	var p: Vector3 = event.pos
	var normal := Surface.normal(grid,roundi(p.x*1000),roundi(p.z*1000))
	particle("ring",event.time,p,Vector3.ZERO,color,Vector3.ONE*radius,life,0,Basis(Quaternion(Vector3.UP,normal)))

func emit_event(event: Dictionary) -> void:
	var kind: String = event.kind
	if kind=="trail":
		var direction: Vector3 = event.direction
		var orientation := Basis(Quaternion(Vector3.UP,direction.normalized()))
		particle("trail",event.time,event.pos,Vector3.ZERO,Color(0.87,0.97,0.87,0.18),Vector3(0.035,(direction.length()+0.035)/2,0.035),0.16,0,orientation)
		return
	var color := Color("9ecb77")
	var count := 5+roundi(event.strength*7)
	var life := 0.48
	var shape := "chip"
	if kind in ["sand","strike_sand","wood","stone"]:
		color=Color("e9c786") if kind!="stone" else Color("c9d5cb")
		shape="grain" if kind in ["sand","strike_sand"] else "chip"
	if kind=="sand": count=2; life=0.32
	if kind in ["strike","strike_sand"]: halo(event,Color("ffe9ad"),0.48,0.22)
	if kind=="rim":
		halo(event,Color("fff2c5"),0.22,0.24); return
	if kind in ["cup","ace"]:
		color=Color("f8d375"); life=0.78; count=28 if kind=="ace" else 16
		halo(event,Color("ffdf86"),1.0 if kind=="ace" else 0.72,0.75)
		if kind=="ace":
			var second := event.duplicate(); second.pos+=Vector3.UP*0.10
			halo(second,Color("b6e9be"),0.70,0.65)
	for i in count:
		var a: float = i*2.399963+event.time*3
		var outward := Vector3(cos(a),0,sin(a))
		var velocity: Vector3 = outward*(0.35+0.65*event.strength)+Vector3.UP*(0.65+0.13*(i%4))
		var size := Vector3(0.035,0.10,0.018) if shape=="chip" else Vector3.ONE*0.055
		if kind in ["wood","stone"]: velocity=outward*0.35+event.direction*0.8+Vector3.UP*0.7
		if kind=="sand": velocity=outward*0.25+event.direction*0.4+Vector3.UP*0.35
		if kind in ["cup","ace"]:
			velocity=outward*(0.7 if kind=="cup" else 1.2)+Vector3.UP*(1.3+0.16*(i%5))
			size=Vector3(0.065,0.11,0.025)
		var tint := color.lerp(Color("fff2c9"),(i%3)*0.15)
		particle(shape,event.time,event.pos,velocity,tint,size,life,3.0,Basis.from_euler(Vector3(a,a*0.7,a*0.3)))

func seek(time: float) -> void:
	clock=maxf(clock,time)
	# Reclaim first so old particles cannot starve a fresh cup effect after a hitch.
	for i in range(active.size()-1,-1,-1):
		if clock-active[i].born>=active[i].life:
			active[i].node.visible=false; active.remove_at(i)
	while cursor<events.size() and events[cursor].time<=clock:
		emit_event(events[cursor]); cursor+=1
	for item in active:
		var age: float = clock-item.born
		var progress: float = age/item.life
		var pos: Vector3 = item.pos+item.velocity*age-Vector3.UP*item.gravity*age*age/2
		if item.gravity>0: pos.y=maxf(pos.y,floor_at(pos).y)
		var size: Vector3 = item.size*(1-progress*0.65)
		if item.shape=="ring": size=item.size*(0.35+progress*0.85)
		item.node.transform=Transform3D(item.basis*Basis.from_scale(size),pos)
		var color: Color = item.color; color.a*=pow(1-progress,1.5)
		item.mat.albedo_color=color
