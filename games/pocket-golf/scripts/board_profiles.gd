# SPDX-License-Identifier: GPL-3.0-or-later
extends Node
## Bounded presentation cache. Model assembly stays in the shared SDK.
const Client = preload("res://addons/traineros/avatar_client.gd")
const Portrait = preload("res://addons/traineros/avatar_portrait.gd")
signal changed
var client = Client.new()
var textures: Dictionary = {}
var wanted: Dictionary = {}
var queued: Dictionary = {}
var in_flight := ""
var generation := 0
var serial := 0
var active := false

func start(endpoint: String) -> void:
	client.app_id="art.abysstail.pocket-golf.board-portraits"
	client.endpoint_override=endpoint; add_child(client)
	client.recipe_resolved.connect(_resolved)
	client.recipe_failed.connect(func(key,_reason):
		if key==in_flight: in_flight=""; _next())
	client.appearance_changed.connect(func(_descriptor): _next())
	client.unavailable.connect(func(_reason):
		in_flight=""; queued.clear(); textures.clear(); changed.emit())

func clear() -> void:
	generation+=1; active=false; in_flight=""
	wanted.clear(); queued.clear(); textures.clear(); client.disconnect_host()
	changed.emit()

func show_profiles(profiles: Dictionary) -> void:
	active=true; wanted.clear(); queued.clear()
	for p in profiles.values():
		var recipe = p.get("avatar")
		if recipe is Dictionary and not recipe.is_empty():
			var key := JSON.stringify(recipe).sha256_text()
			wanted[key]=recipe
			if not textures.has(key): queued[key]=recipe
	# At most the displayed page (5 teams x 3 players); no growing session cache.
	for key in textures.keys():
		if not wanted.has(key): textures.erase(key)
	if not queued.is_empty() and not client.active: client.connect_host()
	_next()

func texture(profile: Dictionary) -> Texture2D:
	var recipe = profile.get("avatar")
	return textures.get(JSON.stringify(recipe).sha256_text()) if recipe is Dictionary else null

func _next() -> void:
	if not active or not in_flight.is_empty() or queued.is_empty(): return
	var key: String = queued.keys()[0]
	serial+=1
	var ticket := str(serial)+":"+key
	if client.resolve_recipe(queued[key],ticket): in_flight=ticket; queued.erase(key)

func _resolved(ticket: String, descriptor: Dictionary) -> void:
	if ticket!=in_flight: return
	var epoch := generation
	var texture_value = await Portrait.capture(self,descriptor)
	if epoch!=generation: return
	var key := ticket.get_slice(":",1)
	if wanted.has(key): textures[key]=texture_value
	in_flight=""; changed.emit(); _next()
