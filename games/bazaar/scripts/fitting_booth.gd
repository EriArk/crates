# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D

const Garment = preload("res://scripts/fitting_garment.gd")
var fill := DirectionalLight3D.new()
var panels: Array[MeshInstance3D] = []
var visitor
var exploration_transform := Transform3D.IDENTITY
var displayed := {}
var requested := {}
var hidden_clothes: Array[MeshInstance3D]=[]
var garment: Node3D
var mannequin: Node3D
var curtain := 0.0
var reveal_delay := 0.0
var closed_frame := false
var subject_id := -1

func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color=color
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	return mat

func prop(mesh: Mesh, color: Color, at: Vector3, dimensions: Vector3, parent: Node3D) -> MeshInstance3D:
	var model := MeshInstance3D.new()
	model.mesh=mesh
	model.material_override=material(color)
	model.position=at
	model.scale=dimensions
	parent.add_child(model)
	return model

func _ready() -> void:
	var brass := Color("caa060")
	var platform := CylinderMesh.new()
	platform.top_radius=.91
	platform.bottom_radius=.96
	platform.height=.09
	prop(platform,Color("8f6e53"),Vector3.UP*.045,Vector3.ONE,self)
	for side in [-1,1]:
		prop(BoxMesh.new(),brass,Vector3(side*1.23,1.15,.63),Vector3(.05,2.3,.05),self)
	prop(BoxMesh.new(),brass,Vector3(0,2.32,.63),Vector3(2.56,.065,.07),self)
	for side in [-1,1]:
		var panel := prop(curtain_mesh(side),Color.WHITE,Vector3(side*1.23,0,.63),Vector3.ONE,self)
		panel.material_override.vertex_color_use_as_albedo=true
		panel.material_override.vertex_color_is_srgb=true
		panels.append(panel)
	# Local point lights produce black tiles on the Odin Compatibility renderer.
	# This soft, shadowless key is active only for the fitting camera.
	fill.rotation_degrees=Vector3(-24,-18,0)
	fill.light_color=Color("ffe5c9")
	fill.light_energy=.66
	fill.hide()
	add_child(fill)
	position_panels()
	set_process(false)

func curtain_mesh(side: int) -> ArrayMesh:
	var cloth := SurfaceTool.new()
	cloth.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hem := [.045,.14,.158,.19,.20,2.29]
	var velvet := Color("8a4c68")
	var piping := Color("c49b67")
	var corners := [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]
	if side<0:corners.reverse()
	for row in range(hem.size()-1):
		var dye := piping if row in [1,3] else velvet
		for i in 36:
			for corner: Vector2i in corners:
				var u := (i+corner.x)/36.0
				var fold := cos(u*TAU*6)
				var y: float=hem[row+corner.y]
				cloth.set_color(dye.darkened((1-fold)*.095))
				cloth.add_vertex(Vector3(-side*u*1.27,y+(.018*fold if y<.25 else 0.0),.049*fold))
	cloth.generate_normals()
	return cloth.commit()

func position_panels() -> void:
	for panel in panels:
		panel.scale.x=lerpf(.14,1.0,smoothstep(0,1,curtain))

func enter(walker) -> void:
	visitor=walker
	fill.show()
	visitor.fitting_pose=true
	exploration_transform=visitor.anchor.transform
	visitor.anchor.top_level=true
	visitor.anchor.global_position=global_position+Vector3.UP*.09
	displayed={}
	requested={}
	subject_id=-1
	set_process(true)

func select(outfit: Dictionary) -> void:
	requested=outfit.duplicate()

func _process(delta: float) -> void:
	if visitor==null:return
	var current_id: int=visitor.visual.get_instance_id() if is_instance_valid(visitor.visual) else 0
	if requested!=displayed or subject_id!=current_id:
		curtain=move_toward(curtain,1.0,delta*3.8)
		position_panels()
		if curtain<1.0:return
		# Present one fully closed frame before creating the replacement.
		if not closed_frame:
			closed_frame=true
			return
		closed_frame=false
		change_outfit(current_id)
		reveal_delay=.20
	elif reveal_delay>0:
		reveal_delay=maxf(0,reveal_delay-delta)
	else:
		closed_frame=false
		reveal_delay=0
		curtain=move_toward(curtain,0,delta*2.9)
		position_panels()

func clear_costume() -> void:
	if is_instance_valid(garment):garment.release()
	for part in hidden_clothes:
		if is_instance_valid(part):part.show()
	hidden_clothes.clear()
	for part in [garment,mannequin]:
		if is_instance_valid(part):
			part.hide()
			part.queue_free()
	garment=null
	mannequin=null

func change_outfit(current_id: int) -> void:
	clear_costume()
	if current_id!=subject_id and is_instance_valid(visitor.locomotion):
		visitor.locomotion.target.reset_bone_poses()
	displayed=requested
	subject_id=current_id
	var base: Node3D=visitor.visual if current_id else visitor.anchor
	if not current_id:
		visitor.fallback.hide()
		mannequin=Node3D.new()
		base.add_child(mannequin)
		prop(SphereMesh.new(),Color("b88c69"),Vector3(0,.81,0),Vector3(.27,.32,.25),mannequin)
		prop(SphereMesh.new(),Color("977151"),Vector3(0,.53,0),Vector3(.23,.34,.17),mannequin)
		prop(BoxMesh.new(),Color("94734e"),Vector3(0,.22,0),Vector3(.045,.44,.045),mannequin)
		prop(BoxMesh.new(),Color("82654a"),Vector3(0,.025,0),Vector3(.23,.05,.18),mannequin)
	if displayed.is_empty():return
	garment=Garment.new()
	base.add_child(garment)
	var skeleton: Skeleton3D
	if current_id:
		# Resolved packs use the selected item IDs for clothing nodes; the base
		# tank and sandals have legacy mesh names. Keep facial meshes and hair.
		var rigs := base.find_children("*","Skeleton3D",true,false)
		if not rigs.is_empty():skeleton=rigs[0]
		for part: MeshInstance3D in base.find_children("*","MeshInstance3D",true,false):
			if part.visible and (str(part.name) in visitor.worn_items or str(part.name) in ["shirt","shoes","racing-gloves","rose-racing-gloves"]):
				hidden_clothes.append(part)
				part.hide()
	garment.build(displayed,skeleton)

func leave() -> void:
	if visitor==null:return
	clear_costume()
	fill.hide()
	visitor.fitting_pose=false
	visitor.anchor.top_level=false
	visitor.anchor.transform=exploration_transform
	visitor.fallback.visible=not is_instance_valid(visitor.visual)
	visitor=null
	curtain=0.0
	closed_frame=false
	reveal_delay=0.0
	position_panels()
	set_process(false)
