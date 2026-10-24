# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
## Run against PlatformHostTests::realGodotAvatarConsumer, never a fake service.
var ui
var received := 0
var old_revision := ""
var old_visual: Node3D
var failed := false

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value: failed=true; printerr("FAIL: "+message)

func run() -> void:
	ui=load("res://main.tscn").instantiate()
	root.add_child(ui)
	ui._start_local(2)
	ui.game.accept_turn()
	ui.avatar_binding.client.appearance_changed.connect(receive)
	ui.avatar_binding.client.unavailable.connect(revoked)
	await create_timer(50).timeout
	printerr("Avatar integration timeout"); quit(4)

func receive(description: Dictionary) -> void:
	received+=1
	if received==1:
		check(ui.anchor.player_id=="alice","host identity installed in actual golf scene")
		old_visual=ui.anchor.visual
		old_revision=old_visual.appearance_revision
		check(old_visual.find_children("*","MeshInstance3D",true,false).size()==4,"external body/outfit/hair/shoes")
		check(old_visual.find_children("*","CollisionObject3D",true,false).is_empty(),"visual has no collision")
		ui.game.bridge.closed.emit()
		check(ui.anchor.visual==old_visual,"match connection lifecycle does not revoke local profile")
		check(old_visual.global_basis.z.dot(Vector3.FORWARD)>0.99,"SDK +Z converted to game -Z")
		check(is_equal_approx(ui.avatar_binding.eye_height(),description.eyeHeight),"SDK eye height")
		check(not old_visual.play_action("golf_putt"),"missing putting animation reported honestly")
		ui.game.world.turn=1; ui._refresh()
		check(ui.anchor.player_id.is_empty() and not old_visual.visible,"guest never borrows owner appearance")
		ui.game.world.turn=0; ui._refresh()
		check(ui.anchor.visual==old_visual,"same presenter reused on owner turn")
		ui.camera.view=2; ui.camera.initialized=false; ui._refresh(); ui._process(0)
		check(not ui.anchor.visible,"eyes view hides own head")
		ui._refresh()
		ui.camera.view=1; ui._refresh()
		await capture("owner-shoulder")
		ui.game.fire()
		check(ui.game.phase=="moving","actual shot still starts")
		# Freeze local rolling time while the host publishes the next appearance.
		ui.paused=true
		print("AVATAR_RECEIVED 1")
	else:
		check(ui.anchor.visual==old_visual and ui.anchor.visual.appearance_revision==old_revision,"no rig replacement mid-shot")
		check(not ui.avatar_binding.pending.is_empty(),"latest saved appearance queued")
		ui.paused=false; ui.elapsed=20; ui._process(0.1)
		check(ui.game.phase!="moving","shot completed normally")
		check(ui.avatar_binding.local_visual.appearance_revision==description.revision and description.revision!=old_revision,"appearance applied at safe boundary")
		ui.game.world.turn=0; ui.game.accept_turn(); ui._refresh()
		await capture("changed-shoulder")
		print("AVATAR_RECEIVED 2")

func capture(name: String) -> void:
	var path := OS.get_environment("TRAINER_AVATAR_CAPTURE")
	if path.is_empty() or DisplayServer.get_name()=="headless": return
	DirAccess.make_dir_recursive_absolute(path)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(path.path_join(name+".png"))==OK,"capture "+name)

func revoked(_reason: String) -> void:
	check(received==2,"both host revisions received")
	check(ui.anchor.player_id.is_empty() and ui.avatar_binding.local_visual==null,"owner revocation clears avatar immediately")
	check(ui.avatar_binding.pending.is_empty(),"revocation clears pending appearance")
	ui._start_local(1); ui.game.accept_turn()
	check(ui.game.can_fire() and ui.anchor.visual!=null and ui.anchor.player_id.is_empty(),"anonymous offline play survives")
	print("AVATAR_REVOKED")
	quit(1 if failed else 0)
