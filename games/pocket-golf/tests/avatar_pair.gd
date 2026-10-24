# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
## Two actual Golf processes, two PlatformHosts and the real TLS record helpers.
var ui
var role := ""
var received := false
var updated := false
var failed := false
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value: failed=true; printerr("FAIL: "+message)
func run() -> void:
	role=OS.get_environment("TRAINER_GOLF_ROLE")
	ui=load("res://main.tscn").instantiate(); root.add_child(ui)
	ui.avatar_exchange.peer_changed.connect(peer_changed)
	ui.game.bridge.closed.connect(closed)
	ui.game.join()
	await create_timer(80).timeout
	printerr("Paired avatar timeout"); quit(4)
func peer_changed(description: Dictionary, member: String) -> void:
	check(member==("2" if role=="host" else "1"),"identity belongs to admitted remote member")
	check(not description.has("profile"),"render recipe does not assert an account identity")
	check(ui.avatar_binding.peer_visual!=null,"peer presenter installed")
	check(ui.avatar_binding.peer_visual.find_children("*","MeshInstance3D",true,false).size()==4,"peer loaded external shared pack")
	check(JSON.stringify(description.recipe).length()<1024,"compact recipe under 1 KiB")
	check(description.recipe.keys().size()==3,"no paths, token or local profile in network recipe")
	if not received:
		received=true
		check(description.appearance.hair==("bob" if role=="host" else "swept"),"opponents keep distinct hair")
		check(ui.avatar_binding.local_visual!=ui.avatar_binding.peer_visual,"separate local/peer visuals")
		var local_turn: bool = ui.game.world.turn==ui.game.seat
		ui.avatar_binding.select(false,true)
		check(ui.anchor.visual==ui.avatar_binding.peer_visual and ui.anchor.player_id=="session-peer:"+member,"remote turn uses remote appearance")
		ui.avatar_binding.select(local_turn,true)
		print("received" if role=="host" else "consumed")
	elif role=="guest":
		check(description.appearance.hair=="ponytail" and description.appearance.eyes=="almond","saved peer changes propagated")
		updated=true; print("peer-updated")
	if failed: quit(1)
func closed() -> void:
	check(received and (role=="host" or updated),"initial and updated peer received before disconnect")
	check(ui.avatar_binding.peer_visual==null and ui.avatar_exchange.peer_member.is_empty(),"channel revokes peer appearance")
	check(ui.avatar_binding.local_visual!=null,"local appearance survives opponent disconnect")
	print("closed"); quit(1 if failed else 0)
