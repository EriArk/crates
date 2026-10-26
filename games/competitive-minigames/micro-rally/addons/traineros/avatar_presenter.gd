# SPDX-License-Identifier: GPL-3.0-or-later
class_name TrainerAvatarPresenter
extends Node3D
## Portable glTF consumer. The SDK descriptor comes from avatar.get/subscribe.
## No wardrobe, model, textures or permanent profile writes belong to the game.
var profile_id := ""
var appearance_revision := ""
var eye_height := 0.8
var actions: Dictionary = {}
var animation_player: AnimationPlayer

static func from_descriptor(descriptor: Dictionary) -> TrainerAvatarPresenter:
	if descriptor.get("schema") != 1 or descriptor.get("rig") != "trainer-humanoid-54-v1": return null
	var path: String = descriptor.get("glb", "")
	if not path.is_absolute_path() or not path.ends_with(".glb"): return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 67108864: return null
	var bytes := file.get_buffer(file.get_length())
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(bytes)
	if hash_context.finish().hex_encode() != descriptor.get("sha256", ""): return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_buffer(bytes, "", state) != OK: return null
	var scene := document.generate_scene(state)
	if not scene is Node3D:
		if scene != null: scene.free()
		return null
	var presenter := TrainerAvatarPresenter.new()
	presenter.profile_id = descriptor.get("profile", "")
	presenter.appearance_revision = descriptor.get("revision", "")
	presenter.eye_height = float(descriptor.get("eyeHeight", 0.8))
	presenter.actions = descriptor.get("actions", {})
	presenter.add_child(scene)
	presenter.animation_player = scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	return presenter

func play_action(action: String) -> bool:
	# Unsupported game actions are explicit; wave is not a fabricated golf stroke.
	if animation_player == null or not actions.has(action): return false
	var clip: String = actions[action]
	if not animation_player.has_animation(clip): return false
	animation_player.play(clip, 0.15)
	return true

func clear_identity() -> void:
	profile_id = ""
	for node in get_children():
		remove_child(node)
		node.queue_free()
	animation_player = null
