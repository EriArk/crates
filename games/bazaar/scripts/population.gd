# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
## Bounded local scenery. Residents are NPCs, never connected-player occupancy.
const ACTIVE_DISTANCE := 52.0
const VISIBLE_DISTANCE := 64.0
const SPECIES := {
	"Casual_Female": preload("res://assets/residents/Casual_Female.glb"),
	"Casual_Male": preload("res://assets/residents/Casual_Male.glb"),
	"Chef_Female": preload("res://assets/residents/Chef_Female.glb"),
	"Kimono_Female": preload("res://assets/residents/Kimono_Female.glb"),
	"OldClassy_Male": preload("res://assets/residents/OldClassy_Male.glb"),
	"Wizard": preload("res://assets/residents/Wizard.glb"),
	"Witch": preload("res://assets/residents/Witch.glb"),
	"Bunny": preload("res://assets/residents/Bunny.glb"),
	"Yeti": preload("res://assets/residents/Yeti.glb"),
	"Pigeon": preload("res://assets/residents/Pigeon.glb")
}
var world: Node3D
var observer: Node3D
var residents: Array[Dictionary] = []
var birds: Array[Dictionary] = []
var ambient_paused := false
var decisions := 0.0

func figure(species: String, at: Vector3, size: float) -> Dictionary:
	var actor := Node3D.new();add_child(actor);actor.position=at
	var visual: Node3D=SPECIES[species].instantiate();actor.add_child(visual);visual.scale=Vector3.ONE*size
	var player: AnimationPlayer=visual.find_child("AnimationPlayer",true,false)
	# Share the original immutable mesh/skin resources. Only per-instance playback
	# state changes. Retargeting and SDK avatar bones are deliberately not involved.
	for clip in ["Idle","Walk","Flying_Idle","Fast_Flying"]:
		if player.has_animation(clip):player.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
	for part in visual.find_children("*","MeshInstance3D",true,false):
		if part.name=="Carrot":part.hide() # The source's optional weapon prop.
		part.visibility_range_end=VISIBLE_DISTANCE
		part.visibility_range_end_margin=5
	var result := {"node":actor,"visual":visual,"player":player,"active":true,"species":species,"clip":""}
	play(result,"Flying_Idle" if species=="Pigeon" else "Idle")
	player.advance(0)
	return result

func play(actor: Dictionary, clip: String, speed := 1.0) -> void:
	var player: AnimationPlayer=actor.player
	if actor.clip!=clip:
		actor.clip=clip;player.play(clip,0.18)
	player.speed_scale=speed

func merchant(species: String, at: Vector3, yaw: float, title: String, detail: String, approach: Vector3) -> void:
	var actor := figure(species,at,0.49 if species=="Bunny" else 0.53 if species=="Yeti" else 0.48)
	actor.node.rotation.y=yaw
	actor.merge({"route":[],"wait":0.0,"cooldown":float(residents.size())*1.7,"gesture":0.0,"home_yaw":yaw,"speed":0.0})
	residents.append(actor)
	actor.player.seek(fmod(residents.size()*0.43,actor.player.current_animation_length),true)
	world.destinations.append({"title":"Meet "+title,"detail":detail+"\nNPC merchant · Trading is still in development. No items or Sparks change.","position":approach})

func pedestrian(species: String, route: Array[Vector3], start: int, speed: float) -> void:
	var actor := figure(species,ground(route[start]),0.45 if species=="Bunny" else 0.48 if species=="Yeti" else 0.46)
	actor.merge({"route":route,"next":(start+1)%route.size(),"wait":float(residents.size()%3),"cooldown":0.0,"gesture":0.0,"speed":speed})
	var direction: Vector3=route[actor.next]-actor.node.position
	actor.node.rotation.y=atan2(direction.x,direction.z)
	residents.append(actor)

func ground(at: Vector3) -> Vector3:
	at.y=world.landscape.surface_height(at)+0.045
	return at

func setup(owner_world: Node3D, visitor: Node3D) -> void:
	world=owner_world;observer=visitor
	var names := ["Pip","Moru","Nim","Bram","Tavi","Oru"]
	var descriptions := ["Pip is getting a small produce stall ready.","Moru is sorting cloth for the festival.","Nim hopes to open a garden stall.","Bram is preparing a place for travelling merchants.","Tavi is looking after this corner of the market.","Oru is waiting for the festival to open."]
	var n := 0
	for side in [-1,1]:
		for z in [-12.0,7.0,17.0]:
			merchant(["Chef_Female","Yeti","Bunny","Kimono_Female","OldClassy_Male","Witch"][n],ground(Vector3(side*7.65,0,z)), -side*PI/2,names[n],descriptions[n],Vector3(side*5.9,0,z))
			n+=1
	for i in 3:
		merchant(["Chef_Female","Kimono_Female","Wizard"][i],Vector3(210+i*20,0.055,-3.45),0,["Moss","Wisp","Rook"][i],["Moss will welcome visitors to the tea shop.","Wisp is preparing the tailor's workbench.","Rook is arranging curious finds."][i],Vector3(210+i*20,0,-1.65))
	var park: Array[Vector3]=[Vector3(-4.8,0,19),Vector3(-4.8,0,-19),Vector3(4.8,0,-19),Vector3(4.8,0,19)]
	for i in 4:pedestrian(["Casual_Female","Bunny","Casual_Male","Yeti"][i],park,i,0.68)
	var town: Array[Vector3]=[Vector3(42,0,-27),Vector3(51,0,-27),Vector3(51,0,-13),Vector3(42,0,-13)]
	for i in 2:pedestrian(["OldClassy_Male","Witch"][i],town,i*2,0.62)
	for i in 6:
		var center: Vector3=[Vector3(-10,0,0),Vector3(11,0,12),Vector3(0,0,-9),Vector3(-39,0,-25),Vector3(0,0,56),Vector3(46,0,-20)][i]
		var bird := figure("Pigeon",center,0.21+(i%2)*0.025)
		bird.merge({"center":center,"phase":i*1.63,"alarm":0.0,"height":2.8 if i<2 else 9.0,"radius":2.2 if i<2 else 7.0})
		# Source mesh floats above its origin; offset it once, preserving its rig.
		bird.visual.position.y=-0.42
		birds.append(bird)
		update_bird(bird,0.0)
	update_activity()

func update_activity() -> void:
	for actor in residents+birds:
		var distance: float=actor.node.global_position.distance_to(observer.global_position)
		actor.active=distance<ACTIVE_DISTANCE
		actor.node.visible=distance<VISIBLE_DISTANCE
		actor.player.active=actor.active and not ambient_paused

func _physics_process(delta: float) -> void:
	if not is_instance_valid(observer):return
	decisions-=delta
	if decisions<=0:
		decisions=0.25;update_activity()
	if ambient_paused:return
	for actor in residents:
		if actor.active:update_resident(actor,delta)
	for bird in birds:
		if bird.active:update_bird(bird,delta)

func update_resident(actor: Dictionary, delta: float) -> void:
	actor.cooldown=maxf(0.0,actor.cooldown-delta)
	actor.gesture=maxf(0.0,actor.gesture-delta)
	var node: Node3D=actor.node
	var to_player := observer.global_position-node.global_position
	if actor.route.is_empty():
		# A greeting has a cooldown, then returns to the stall-facing idle.
		if to_player.length()<3.6 and actor.cooldown<=0:
			actor.cooldown=14.0;actor.gesture=2.0
			if actor.player.has_animation("Wave"):
				actor.gesture=actor.player.get_animation("Wave").length;play(actor,"Wave")
		elif actor.gesture<=0:play(actor,"Idle")
		var facing: float=actor.home_yaw
		if to_player.length()<3.6:
			facing+=clampf(angle_difference(facing,atan2(to_player.x,to_player.z)),-0.65,0.65)
		node.rotation.y=lerp_angle(node.rotation.y,facing,minf(1.0,delta*2.0))
		return
	var target: Vector3=ground(actor.route[actor.next])
	var direction := target-node.position;direction.y=0
	actor.wait=maxf(0.0,actor.wait-delta)
	# Stop for the real visitor. No collision body means NPCs cannot trap a player
	# at an entrance; paths themselves are checked against the static world.
	if to_player.length()<1.35 or actor.wait>0:
		play(actor,"Idle");return
	if direction.length()<0.06:
		actor.next=(actor.next+1)%actor.route.size();actor.wait=1.7+(actor.next%3)*0.6
		play(actor,"Idle");return
	var yaw := atan2(direction.x,direction.z)
	node.rotation.y=lerp_angle(node.rotation.y,yaw,minf(1.0,delta*4.0))
	# Turn in place before moving to avoid sideways skating around corners.
	if absf(angle_difference(node.rotation.y,yaw))>0.25:
		play(actor,"Idle");return
	node.position=ground(node.position+direction.normalized()*minf(actor.speed*delta,direction.length()))
	play(actor,"Walk",actor.speed/0.68)

func update_bird(bird: Dictionary, delta: float) -> void:
	bird.alarm=maxf(0.0,bird.alarm-delta)
	if bird.node.global_position.distance_to(observer.global_position)<4.0:bird.alarm=7.0
	bird.phase+=delta*(0.7 if bird.alarm>0 else 0.24)
	var a: float=bird.phase
	var radius: float=bird.radius
	var target: Vector3=bird.center+Vector3(cos(a)*radius,bird.height+sin(a*2)*0.35,sin(a)*radius*0.65)
	target.y+=4.0 if bird.alarm>0 else 0.0
	bird.node.position=bird.node.position.lerp(target,1.0-exp(-delta*2.0)) if delta>0 else target
	bird.node.rotation.y=atan2(-sin(a),cos(a)*0.65)
	bird.node.rotation.z=sin(a)*0.10
	play(bird,"Fast_Flying" if bird.alarm>0 else "Flying_Idle")

func set_paused(value: bool) -> void:
	ambient_paused=value
	if is_instance_valid(observer):update_activity()
