# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
## Each authored mesh is one fitting slot in the SDK standing pose.
const STYLES := ["traveller","mage","merchant"]
const SLOTS := ["Top","Bottom","Boots","Hat"]
const MODELS := {
	"traveller":preload("res://assets/outfits/traveller.glb"),
	"mage":preload("res://assets/outfits/mage.glb"),
	"merchant":preload("res://assets/outfits/merchant.glb")
}
const NAMES := {
	"traveller":["Trail cloak","Trail trousers","Ranger boots","Feather cap"],
	"mage":["Starweave coat","Indigo leggings","Rune boots","Astral hat"],
	"merchant":["Apron & vest","Market breeches","Guild shoes","Market beret"]
}
var head_attachment: BoneAttachment3D

static func full_set(style: String) -> Dictionary:
	var look := {}
	if style in STYLES:
		for slot in SLOTS:look[slot]=style
	return look

func build(look: Dictionary, skeleton: Skeleton3D) -> void:
	for style in STYLES:
		if style not in look.values():continue
		var model: Node3D=MODELS[style].instantiate()
		for slot in SLOTS:
			if look.get(slot)!=style:continue
			var piece := model.get_node(NodePath(slot)) as MeshInstance3D
			piece.owner=null
			model.remove_child(piece)
			add_child(piece)
			if slot=="Hat" and skeleton!=null:
				var head := skeleton.find_bone("head")
				if head>=0:
					head_attachment=BoneAttachment3D.new()
					skeleton.add_child(head_attachment)
					head_attachment.bone_idx=head
					var rest := skeleton.global_transform*skeleton.get_bone_global_rest(head)
					var offset := rest.affine_inverse()*piece.global_transform
					piece.reparent(head_attachment,false)
					piece.transform=offset
		model.free()

func release() -> void:
	if is_instance_valid(head_attachment):
		head_attachment.hide()
		head_attachment.queue_free()
		head_attachment=null
