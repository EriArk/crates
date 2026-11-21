# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
const PIGEON := preload("res://assets/gallery/Pigeon.glb")
const CAST := [
	preload("res://assets/gallery/Bunny.glb"), preload("res://assets/gallery/OldClassy_Male.glb"),
	preload("res://assets/gallery/Frog.glb"), preload("res://assets/gallery/Casual_Female.glb")]
const SPOTS := [
	Vector2(-1.6,-8.65), Vector2(-2.65,-8.73), Vector2(5.86,1.9),
	Vector2(-5.62,-1.4), Vector2(2.4,-8.62), Vector2(5.68,0.65)]
var fans: Array[Node3D] = []
var birds: Array[Node3D] = []
var players: Array[AnimationPlayer] = []
var bird_call := AudioStreamPlayer3D.new()
var until_call := 4.0
var score_clock := 0.0
var course := 0

func build(island: Node3D, hole: int) -> void:
	course=hole
	for i in SPOTS.size():
		var spot: Vector2=SPOTS[i]
		var root := Node3D.new()
		add_child(root)
		root.position=Vector3(spot.x,0,spot.y)
		root.position.y=island.surface_height(root.position)
		root.rotation.y=atan2(-spot.x,-spot.y)
		var visual: Node3D=CAST[(i+hole)%CAST.size()].instantiate()
		root.add_child(visual)
		var bounds:=AABB()
		var first:=true
		for part: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
			if part.name=="Carrot":
				part.hide()
				continue
			var box: AABB=(root.global_transform.affine_inverse()*part.global_transform)*part.get_aabb()
			bounds=box if first else bounds.merge(box)
			first=false
			for surface in part.mesh.get_surface_count():
				var material=part.mesh.surface_get_material(surface)
				if material is StandardMaterial3D and material.resource_name in ["Skin","Face"]:
					var paint: StandardMaterial3D=material.duplicate()
					paint.albedo_color=Color("29201e") if material.resource_name=="Face" else [Color("bb805a"),Color("efc5a5"),Color("925d40")][(i+hole)%3]
					part.set_surface_override_material(surface,paint)
		var size: float=(0.84+0.05*(i%3))/maxf(bounds.size.y,0.01)
		visual.scale=Vector3.ONE*size
		visual.position.y=-bounds.position.y*size
		var anim: AnimationPlayer=visual.find_child("AnimationPlayer",true,false)
		anim.get_animation("Idle").loop_mode=Animation.LOOP_LINEAR
		anim.play("Idle")
		anim.seek(fmod(i*.37,anim.current_animation_length),true)
		players.append(anim)
		fans.append(root)
	for i in 4:
		var bird: Node3D=PIGEON.instantiate()
		add_child(bird)
		bird.scale=Vector3.ONE*(0.17+0.015*(i%2))
		var anim: AnimationPlayer=bird.find_child("AnimationPlayer",true,false)
		anim.get_animation("Flying_Idle").loop_mode=Animation.LOOP_LINEAR
		anim.play("Flying_Idle",-1,0.87+i*.08)
		players.append(anim)
		birds.append(bird)
	bird_call.stream=preload("res://assets/audio/pigeon.wav")
	bird_call.unit_size=7
	bird_call.max_distance=48
	# Keep audio coordinates independent of the model's imported scale.
	add_child(bird_call)
	update_flight(0)

func set_quality(level: int) -> void:
	for i in fans.size():
		fans[i].visible=i<[3,5,6][level]
		players[i].active=fans[i].visible
	for i in birds.size():
		birds[i].visible=i<[2,3,4][level]
		players[fans.size()+i].active=birds[i].visible

func cheer() -> void:
	for i in fans.size():
		if not fans[i].visible: continue
		var anim:=players[i]
		var clip: String="Wave" if anim.has_animation("Wave") else "Victory"
		anim.get_animation(clip).loop_mode=Animation.LOOP_NONE
		anim.play(clip,0.16,0.73+i*.035)
		anim.queue("Idle")

func update_flight(delta: float) -> void:
	score_clock+=delta
	for i in birds.size():
		if not birds[i].visible: continue
		var bird:=birds[i]
		var phase:=score_clock*.24+i*.53+course*.8
		bird.position=Vector3(0.3+cos(phase)*8.7,2.9+i*.32+sin(phase*2.0)*.46,-10.3+sin(phase)*2.8)
		bird.rotation=Vector3(0,atan2(-8.7*sin(phase),2.8*cos(phase)),.11*cos(phase))
	bird_call.position=birds[0].position

func tick(delta: float, volume: float, audible: bool) -> void:
	update_flight(delta)
	bird_call.volume_linear=volume*.32
	bird_call.stream_paused=not audible
	if not audible or volume==0: return
	until_call-=delta
	if until_call<=0:
		bird_call.play()
		until_call=11.0+2.4*cos(score_clock*.17)

func _exit_tree() -> void:
	bird_call.stop()
	bird_call.stream=null
