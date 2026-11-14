# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
## Bounded local scenery. Residents are NPCs, never connected-player occupancy.
const ACTIVE_DISTANCE := 52.0
const GREETING_SPEED := 0.65
const VISIBLE_DISTANCE := 64.0
const HUMAN_SPECIES := ["Casual_Female","Casual_Male","Chef_Female","Kimono_Female","OldClassy_Male","Wizard","Witch"]
const SKIN_TONES := [Color("efc5a5"),Color("dba47d"),Color("bb805a"),Color("925d40"),Color("68432f")]
const SPECIES := {
	"Dino": preload("res://assets/residents/Dino.glb"),
	"Frog": preload("res://assets/residents/Frog.glb"),
	"Birb": preload("res://assets/residents/Birb.glb"),
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
var hired_sellers: Array[Dictionary] = []
var ambient_paused := false
var decisions := 0.0
var complexion_materials: Dictionary = {}
var figure_bounds: Dictionary = {}

func complexion(visual: Node3D, tone: int) -> void:
	# Surface overrides belong to the instance; vendor materials, mesh/skin data,
	# clothes and hair are untouched. A small cache bounds material variants.
	for part in visual.find_children("*","MeshInstance3D",true,false):
		for surface in part.mesh.get_surface_count():
			var source = part.mesh.surface_get_material(surface)
			if not source is StandardMaterial3D or source.resource_name not in ["Skin","Face"]:continue
			var key := str(source.get_instance_id())+":"+str(tone)
			if not complexion_materials.has(key):
				var material: StandardMaterial3D=source.duplicate()
				material.albedo_color=SKIN_TONES[tone] if source.resource_name=="Skin" else Color("29201e")
				material.roughness=0.82
				complexion_materials[key]=material
			part.set_surface_override_material(surface,complexion_materials[key])

func figure(species: String, at: Vector3, size: float, tone := -1) -> Dictionary:
	var actor := Node3D.new();add_child(actor);actor.position=at
	var visual: Node3D=SPECIES[species].instantiate();actor.add_child(visual)
	if species!="Pigeon":
		if not figure_bounds.has(species):
			var bounds := AABB();var first := true
			for part in visual.find_children("*","MeshInstance3D",true,false):
				if part.name=="Carrot":continue
				var box: AABB=(visual.global_transform.affine_inverse()*part.global_transform)*part.get_aabb()
				bounds=box if first else bounds.merge(box);first=false
			figure_bounds[species]=bounds
		var bounds: AABB=figure_bounds[species]
		# size retains caller variation; 0.48 means a 1.50 m resident.
		var uniform := (1.50*size/0.48)/maxf(bounds.size.y,0.01)
		visual.scale=Vector3.ONE*uniform;visual.position.y=-bounds.position.y*uniform
	else:visual.scale=Vector3.ONE*size
	var player: AnimationPlayer=visual.find_child("AnimationPlayer",true,false)
	if species in HUMAN_SPECIES:
		if tone<0:tone=residents.size()%SKIN_TONES.size()
		complexion(visual,posmod(tone,SKIN_TONES.size()))
	# Share the original immutable mesh/skin resources. Only per-instance playback
	# state changes. Retargeting and SDK avatar bones are deliberately not involved.
	for clip in ["Idle","Walk","Flying_Idle","Fast_Flying"]:
		if player.has_animation(clip):player.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
	for part in visual.find_children("*","MeshInstance3D",true,false):
		if part.name=="Carrot":part.hide() # The source's optional weapon prop.
		part.visibility_range_end=VISIBLE_DISTANCE
		part.visibility_range_end_margin=5
	var result := {"node":actor,"visual":visual,"player":player,"active":true,"species":species,"clip":"","tone":tone}
	play(result,"Flying_Idle" if species=="Pigeon" else "Idle")
	player.advance(0)
	return result

func play(actor: Dictionary, clip: String, speed := 1.0) -> void:
	var player: AnimationPlayer=actor.player
	if actor.clip!=clip:
		var blend := 0.0 if actor.clip.is_empty() else 0.18
		actor.clip=clip;player.play(clip,blend)
	player.speed_scale=speed*(GREETING_SPEED if clip=="Wave" else 1.0)

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
	for slot in [2,4,6,8,10,12]:
		var layout: Dictionary=world.stall_layout(slot)
		merchant(["Chef_Female","Yeti","Bunny","Kimono_Female","OldClassy_Male","Witch"][n],ground(layout.seller),layout.yaw,names[n],descriptions[n],layout.approach)
		n+=1
	for i in 3:
		merchant(["Chef_Female","Kimono_Female","Wizard"][i],Vector3(210+i*20,0.055,-3.45),0,["Moss","Wisp","Rook"][i],["Moss will welcome visitors to the tea shop.","Wisp is preparing the tailor's workbench.","Rook is arranging curious finds."][i],Vector3(210+i*20,0,-1.65))
	var park: Array[Vector3]=[Vector3(-3.6,0,19),Vector3(-3.6,0,-19),Vector3(3.6,0,-19),Vector3(3.6,0,19)]
	for i in 4:pedestrian(["Casual_Female","Bunny","Casual_Male","Yeti"][i],park,i,0.68)
	var town: Array[Vector3]=[Vector3(42,0,-27),Vector3(51,0,-27),Vector3(51,0,-13),Vector3(42,0,-13)]
	for i in 2:pedestrian(["OldClassy_Male","Witch"][i],town,i*2,0.62)
	# Three further animal folk use spare stalls and the clear garden center.
	merchant("Dino",ground(world.stall_layout(3).seller),PI/2,"Kip","Kip is preparing a travelling trader's stall.",world.stall_layout(3).approach)
	merchant("Birb",ground(world.stall_layout(7).seller),-PI/2,"Sora","Sora is looking after the northern festival stalls.",world.stall_layout(7).approach)
	var garden: Array[Vector3]=[Vector3(-41,0,-29),Vector3(-37,0,-29),Vector3(-37,0,-21),Vector3(-41,0,-21)]
	pedestrian("Frog",garden,2,0.60)
	for i in 6:
		var center: Vector3=[Vector3(-10,0,0),Vector3(11,0,12),Vector3(0,0,-9),Vector3(-39,0,-25),Vector3(0,0,56),Vector3(46,0,-20)][i]
		var bird := figure("Pigeon",center,0.21+(i%2)*0.025)
		bird.merge({"center":center,"phase":i*1.63,"alarm":0.0,"height":2.8 if i<2 else 9.0,"radius":2.2 if i<2 else 7.0})
		# Source mesh floats above its origin; offset it once, preserving its rig.
		bird.visual.position.y=-0.42
		birds.append(bird)
		update_bird(bird,0.0)
	merchant("OldClassy_Male",Vector3(270,0.055,-3.45),0,"Vale","Vale handles stall rentals and NPC sellers.",Vector3(270,0,-1.65))
	update_activity()

func apply_stall_sellers(places: Array) -> void:
	# Server projection only. Losing the account clears this layer; ambient NPCs
	# never become evidence that a player rented or owns a place.
	for actor in hired_sellers:actor.node.queue_free()
	hired_sellers.clear()
	for actor in residents:actor["covered_by_seller"]=false
	var seen := {}
	for row in places:
		var slot := int(row.get("slot",0));var species := str(row.get("species", ""))
		if slot<1 or slot>12 or seen.has(slot) or species not in SPECIES or species=="Pigeon" or row.get("rental_id")==null:continue
		seen[slot]=true
		var layout: Dictionary=world.stall_layout(slot)
		var at := ground(layout.seller)
		for ambient in residents:
			if ambient.route.is_empty() and ambient.node.position.distance_to(at)<0.5:ambient.covered_by_seller=true
		var actor := figure(species,at,0.49 if species=="Bunny" else 0.53 if species=="Yeti" else 0.48,slot%5)
		actor.node.rotation.y=layout.yaw
		actor.merge({"route":[],"wait":0.0,"cooldown":1.0,"gesture":0.0,"home_yaw":layout.yaw,"speed":0.0})
		hired_sellers.append(actor)
	update_activity()

func update_activity() -> void:
	for actor in residents+birds+hired_sellers:
		var distance: float=actor.node.global_position.distance_to(observer.global_position)
		actor.active=distance<ACTIVE_DISTANCE and not actor.get("covered_by_seller",false)
		actor.node.visible=distance<VISIBLE_DISTANCE and not actor.get("covered_by_seller",false)
		actor.player.active=actor.active and not ambient_paused

func _physics_process(delta: float) -> void:
	if not is_instance_valid(observer):return
	decisions-=delta
	if decisions<=0:
		decisions=0.25;update_activity()
	if ambient_paused:return
	for actor in residents+hired_sellers:
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
				actor.gesture=actor.player.get_animation("Wave").length/GREETING_SPEED;play(actor,"Wave")
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
