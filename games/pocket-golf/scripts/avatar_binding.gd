# SPDX-License-Identifier: GPL-3.0-or-later
extends Node
## Local SDK identity only. Guest/remote seats keep the anonymous game marker.
const Client = preload("res://addons/traineros/avatar_client.gd")
const Presenter = preload("res://addons/traineros/avatar_presenter.gd")
var client = Client.new()
var anchor: Node3D
var fallback: Callable
var local_visual: Node3D
var peer_visual: Node3D
var peer_pending: Dictionary = {}
var peer_id := ""
var pending: Dictionary = {}
var local_turn := true
var safe_boundary := true

func start(target: Node3D, make_fallback: Callable, endpoint: String) -> void:
	anchor=target
	fallback=make_fallback
	client.app_id="art.abysstail.pocket-golf.avatar"
	client.endpoint_override=endpoint
	add_child(client)
	client.appearance_changed.connect(_received)
	client.unavailable.connect(func(_reason): revoke())
	client.connect_host()

func _received(descriptor: Dictionary) -> void:
	# Keep only the latest saved appearance; never replace a rig during a shot.
	pending=descriptor.duplicate(true)
	select(local_turn,safe_boundary)

func _park(visual: Node3D) -> void:
	if is_instance_valid(visual) and anchor.visual==visual:
		anchor.remove_child(visual)
		anchor.visual=null
		anchor.player_id=""
		add_child(visual)
		visual.visible=false

func receive_peer(description: Dictionary, member: String) -> void:
	peer_id=member
	peer_pending=description.duplicate(true)
	select(local_turn,safe_boundary)

func clear_peer() -> void:
	peer_pending={}; peer_id=""
	if is_instance_valid(peer_visual):
		if anchor.visual==peer_visual: anchor.clear_identity()
		else: peer_visual.queue_free()
	peer_visual=null
	if anchor.visual==null: fallback.call()

func select(is_local: bool, can_replace: bool) -> void:
	local_turn=is_local
	safe_boundary=can_replace
	if can_replace and not pending.is_empty():
		var description := pending
		pending={}
		var replacement = Presenter.from_descriptor(description)
		# Invalid revisions revoke the old visual rather than misrepresenting it.
		if replacement==null:
			revoke()
			return
		_park(local_visual)
		if is_instance_valid(local_visual): local_visual.queue_free()
		local_visual=replacement
		# Stand side-on to the putting line, facing the ball on the right.
		local_visual.rotation.y=PI/2
		add_child(local_visual)
		local_visual.visible=false
	if can_replace and not peer_pending.is_empty():
		var replacement = Presenter.from_descriptor(peer_pending)
		peer_pending={}
		if replacement==null: clear_peer()
		else:
			_park(peer_visual)
			if is_instance_valid(peer_visual): peer_visual.queue_free()
			peer_visual=replacement
			peer_visual.rotation.y=PI/2
			add_child(peer_visual); peer_visual.visible=false
	_park(peer_visual if local_turn else local_visual)
	var selected: Node3D = local_visual if local_turn else peer_visual
	if is_instance_valid(selected) and anchor.visual!=selected:
		selected.get_parent().remove_child(selected)
		anchor.install_visual(selected,local_visual.profile_id if local_turn else "session-peer:"+peer_id)
		selected.visible=true
	if anchor.visual==null: fallback.call()

func eye_height() -> float:
	if is_instance_valid(anchor.visual) and (anchor.visual==local_visual or anchor.visual==peer_visual):
		return anchor.visual.eye_height
	return 1.05

func revoke() -> void:
	clear_peer()
	pending.clear()
	if is_instance_valid(local_visual):
		if anchor.visual==local_visual: anchor.clear_identity()
		else: local_visual.queue_free()
	local_visual=null
	# This also clears any identity installed by a previous game integration.
	if not anchor.player_id.is_empty(): anchor.clear_identity()
	if anchor.visual==null: fallback.call()

func disconnect_identity() -> void:
	client.disconnect_host()
	revoke()
