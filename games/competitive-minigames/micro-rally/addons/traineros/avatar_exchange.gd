# SPDX-License-Identifier: GPL-3.0-or-later
class_name TrainerAvatarExchange
extends Node
## Adapter over an already admitted reliable game channel. No new transport.
## Bridge exposes session, channel, session_ready, closed, sdk_record and send().
signal peer_changed(descriptor: Dictionary, member: String)
signal peer_unavailable
const NAMESPACE := "traineros.avatar.v1"
var client: Node
var bridge: Node
var local_recipe: Dictionary = {}
var queued: Dictionary = {}
var generation := 0
var serial := 0
var in_flight := ""
var peer_member := ""
var sent_revision := ""
var received_revision := ""
var retry_at := 0
var send_pending := false
var can_resolve: Callable

func start(avatar_client: Node, record_bridge: Node) -> void:
	client=avatar_client; bridge=record_bridge
	client.appearance_changed.connect(func(d):
		local_recipe=d.get("recipe",{})
		send_pending=true)
	client.unavailable.connect(func(_reason):
		local_recipe={}; in_flight=""; clear_peer(); send_pending=true)
	client.recipe_resolved.connect(_resolved)
	client.recipe_failed.connect(_failed)
	bridge.session_ready.connect(func(_host):
		clear_peer()
		peer_member=bridge.session.get("peer","")
		send_pending=true)
	bridge.closed.connect(clear_peer)
	bridge.sdk_record.connect(_receive)

func clear_peer() -> void:
	generation+=1
	peer_member=""; queued={}; sent_revision=""; received_revision=""
	peer_unavailable.emit()

func _process(_delta: float) -> void:
	if bridge.channel.is_empty():
		if not peer_member.is_empty(): clear_peer()
		return
	if send_pending:
		var revision := JSON.stringify(local_recipe).sha256_text()
		if revision==sent_revision or bridge.send({"namespace":NAMESPACE,"recipe":local_recipe}):
			sent_revision=revision; send_pending=false
	if not queued.is_empty() and in_flight.is_empty() and Time.get_ticks_msec()>=retry_at and (not can_resolve.is_valid() or can_resolve.call()):
		serial+=1
		var key := str(generation)+":"+str(serial)
		if client.resolve_recipe(queued,key):
			in_flight=key; queued={}
			retry_at=Time.get_ticks_msec()+1000

func _receive(data: Dictionary) -> void:
	if data.get("namespace")!=NAMESPACE or peer_member.is_empty(): return
	var recipe = data.get("recipe")
	if not recipe is Dictionary or JSON.stringify(data).length()>2048: return
	var revision := JSON.stringify(recipe).sha256_text()
	if revision==received_revision: return
	received_revision=revision
	# Fence any already-running result when a newer recipe/withdrawal arrives.
	generation+=1
	queued=recipe.duplicate(true)
	if queued.is_empty(): peer_unavailable.emit()

func _resolved(key: String, descriptor: Dictionary) -> void:
	if key!=in_flight: return
	in_flight=""
	if key.get_slice(":",0)!=str(generation) or peer_member.is_empty() or bridge.channel.is_empty(): return
	peer_changed.emit(descriptor,peer_member)

func _failed(key: String, _reason: String) -> void:
	if key!=in_flight: return
	in_flight=""
	if key.get_slice(":",0)==str(generation): peer_unavailable.emit()
