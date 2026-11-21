# SPDX-License-Identifier: GPL-3.0-or-later
extends Node
## Game roster only. Appearance assembly and wardrobe remain in the SDK.
const Portrait = preload("res://addons/traineros/avatar_portrait.gd")
const Client = preload("res://addons/traineros/avatar_client.gd")
const NAMESPACE := "traineros.avatar.v1"
var binding: Node
var game: Node
var local_recipe: Dictionary = {}
var recipes: Dictionary = {}
var descriptions: Dictionary = {}
var portraits: Dictionary = {}
var queue: Dictionary = {}
var revisions: Dictionary = {}
var in_flight := ""
var resolving_member := ""
var serial := 0
var generation := 0
var sent := ""
var selected := ""
var npc_round := -1
var npc_recipe: Dictionary = {}
var rng := RandomNumberGenerator.new()
var retry_at := 0
var group_active := false
var resolvers: Dictionary = {}
signal changed

func start(avatar_binding: Node, match_node: Node) -> void:
	binding=avatar_binding; game=match_node; rng.randomize()
	binding.client.appearance_changed.connect(func(d):
		local_recipe=d.get("recipe",{}).duplicate(true); sent=""
		if game.solo_bot: _stock())
	binding.client.unavailable.connect(func(_reason):
		local_recipe={}; sent=""; _clear())
	game.bridge.session_ready.connect(func(_host): group_active=true; _clear(); sent="")
	game.bridge.closed.connect(func():
		if group_active: group_active=false; _clear())
	game.bridge.member_record.connect(_receive)
	game.round_started.connect(func():
		if game.solo_bot: _clear(); _stock()
		elif not game.online: _clear())

func _clear() -> void:
	generation+=1; queue.clear(); descriptions.clear(); portraits.clear(); recipes.clear(); revisions.clear()
	in_flight=""; resolving_member=""
	for resolver in resolvers.values():
		resolver.disconnect_host(); resolver.queue_free()
	resolvers.clear()
	selected=""; npc_round=-1; binding.clear_peer(); changed.emit()

func _stock() -> void:
	if local_recipe.is_empty() or npc_round==game.round_id: return
	npc_round=game.round_id
	# Standard SDK pack recipe, resolved in its shared cache. No game-owned GLB.
	var appearance := {"schema":1,"pack":"trainer-avatar-1",
		"hair":["swept","ponytail","crop","bob"][rng.randi_range(0,3)],
		"eyes":["round","almond"][rng.randi_range(0,1)],
		"skinColor":["#f7d8bf","#f0c4a5","#d9ab86","#ba8764","#8c5e43","#614132"][rng.randi_range(0,5)],
		"hairColor":["#302a2d","#62402c","#975743","#d1ab68","#e9dcd0","#a35a69","#64888c"][rng.randi_range(0,6)],
		"eyeColor":["#98602d","#779486","#547d9a","#9794ae","#bb8b47","#6b6269"][rng.randi_range(0,5)],
		"shirtColor":["#ec9e8d","#a8c9bc","#aabddd","#d4b5d6","#f0d58d","#f4eee6"][rng.randi_range(0,5)],
		"shortsColor":["#577c87","#aebdd5","#8d799f","#b98e7c","#536274","#e0cba9"][rng.randi_range(0,5)]}
	if npc_recipe.get("appearance")==appearance:
		appearance.hair="bob" if appearance.hair!="bob" else "crop"
	npc_recipe={"schema":1,"packRevision":local_recipe.get("packRevision"),"appearance":appearance}
	_enqueue("bot",npc_recipe)

func _enqueue(member: String, recipe: Dictionary) -> void:
	var revision := JSON.stringify(recipe).sha256_text()
	if revisions.get(member)==revision: return
	revisions[member]=revision; recipes[member]=recipe.duplicate(true)
	descriptions.erase(member); portraits.erase(member)
	if recipe.is_empty(): queue.erase(member)
	else: queue[member]=recipe.duplicate(true)
	if selected==member: selected="" # Replace/revoke only at a safe turn boundary.
	changed.emit()

func _process(_delta: float) -> void:
	if game.online and not game.bridge.channel.is_empty():
		var revision := JSON.stringify(local_recipe).sha256_text()
		if sent!=revision and game.bridge.pending.size()<8:
			if game.bridge.send({"namespace":NAMESPACE,"member":game.bridge.session.self,"recipe":local_recipe}): sent=revision
	if queue.is_empty() or not in_flight.is_empty() or game.phase=="moving" or Time.get_ticks_msec()<retry_at: return
	var member: String = queue.keys()[0]
	# SDK resolve grants last until the next resolve on THAT connection. Keep
	# one read-only connection per admitted appearance, bounded to seven + bot.
	if not resolvers.has(member):
		var resolver = Client.new()
		resolver.app_id="art.abysstail.pocket-golf.roster%d"%resolvers.size()
		resolver.endpoint_override=binding.client.endpoint_override
		add_child(resolver); resolvers[member]=resolver
		resolver.recipe_resolved.connect(_resolved)
		resolver.recipe_failed.connect(func(key,reason):
			if key!=in_flight: return
			in_flight=""; resolving_member=""
			if reason=="avatar_busy" and recipes.has(member): queue[member]=recipes[member]; retry_at=Time.get_ticks_msec()+1000)
		resolver.unavailable.connect(func(_reason):
			if not is_instance_valid(resolver) or resolvers.get(member)!=resolver: return
			if resolving_member==member: in_flight=""; resolving_member=""
			descriptions.erase(member); portraits.erase(member); queue.erase(member)
			resolvers.erase(member); resolver.queue_free()
			selected=""; changed.emit())
		resolver.connect_host()
	if not queue.has(member) or not resolvers.has(member): return
	serial+=1
	var key := "%d:%d:%s:%s"%[generation,serial,member,revisions[member]]
	if resolvers[member].resolve_recipe(queue[member],key):
		in_flight=key; resolving_member=member; queue.erase(member); retry_at=Time.get_ticks_msec()+250

func _receive(sender: String, data: Dictionary) -> void:
	if not game.online or data.get("namespace")!=NAMESPACE: return
	var member = data.get("member")
	var recipe = data.get("recipe")
	if not member is String or not game.members.has(member) or not recipe is Dictionary or JSON.stringify(data).length()>2048: return
	if game.host:
		if member!=sender: return
		for peer in game.bridge.channels:
			if peer!=sender: game.bridge.send_to(peer,data)
	elif sender!=game.bridge.session.get("hostMember"): return
	if member!=game.bridge.session.get("self"): _enqueue(member,recipe)

func _resolved(key: String, descriptor: Dictionary) -> void:
	if key!=in_flight: return
	in_flight=""; resolving_member=""
	# Member IDs can contain separators; retain them by using the stored suffix boundaries.
	var prefix := key.find(":",key.find(":")+1)
	var suffix := key.rfind(":")
	var member := key.substr(prefix+1,suffix-prefix-1)
	if int(key.get_slice(":",0))!=generation or revisions.get(member)!=key.substr(suffix+1): return
	descriptions[member]=descriptor
	var revision = revisions[member]
	var epoch := generation
	var texture = await Portrait.capture(self,descriptor)
	if epoch!=generation or revisions.get(member)!=revision: return
	portraits[member]=texture; changed.emit()

func select_actor(actor: int, safe: bool) -> void:
	var own: bool = actor==(game.seat if game.online else 0)
	var member: String = game.members[actor] if game.online and actor<game.members.size() else "bot" if game.solo_bot and actor==1 else "guest:%d"%actor
	if safe and not own and selected!=member:
		binding.clear_peer(); selected=member
		if descriptions.has(member): binding.receive_peer(descriptions[member],member)
	elif safe and not own and descriptions.has(member) and not is_instance_valid(binding.peer_visual):
		binding.receive_peer(descriptions[member],member)
	binding.select(own,safe)

func portrait(actor: int) -> Texture2D:
	if actor==(game.seat if game.online else 0): return binding.local_portrait
	var member: String = game.members[actor] if game.online and actor<game.members.size() else "bot" if game.solo_bot and actor==1 else "guest:%d"%actor
	return portraits.get(member)
