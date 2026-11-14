# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var scene: Node3D
var failures: Array[String]=[]
var output := "user://services-checks"
func check(value: bool, message: String) -> void:
	if not value:failures.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+name+".png")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.smoke_mode=true
	scene.visitor.set_physics_process(false);scene.square.life.stop_sound()
	await physics_frame;await physics_frame
	check(scene.square.shop_exits.size()==4,"Four enterable buildings including rental office")
	var slots := []
	for spot in scene.square.destinations:
		if spot.get("service")=="stall":slots.append(spot.slot)
	check(slots.size()==12 and slots[0]==1 and slots[11]==12,"Twelve stable physical stall numbers")
	var review_camera := Camera3D.new();scene.add_child(review_camera)
	scene.visitor.position=Vector3(38,0,-12);scene._process(0)
	review_camera.global_position=Vector3(33,4.5,-17);review_camera.look_at(Vector3(38,1.3,-5));review_camera.make_current()
	await capture("office-building")
	scene.visitor.camera.make_current();review_camera.queue_free()
	var door: Vector3=scene.square.shop_exits[3].door
	scene.visitor.position=door;scene._process(0);scene.inspect_spot()
	check(scene.visitor.position.x>260,"Office door enters the correct room")
	scene.visitor.position=Vector3(270,0,-1.65);scene._process(0)
	check(scene.nearest.get("service")=="office","Clerk service wins over ambient NPC greeting")
	scene.inspect_spot();var menu=scene.services
	check(menu.visible and scene.modal and scene.population.ambient_paused,"Service opens and pauses world input")
	await create_timer(0.2).timeout
	check(menu.get_global_rect().end.y<=root.get_visible_rect().end.y,"Service panel fits viewport height")
	await capture("office-places")
	menu.switch("sellers");await create_timer(0.3).timeout
	check(menu.preview_actor!=null,"Seller preview uses actual native model")
	await capture("office-sellers")
	for i in menu.SELLERS.size():
		menu.seller=i;menu.render();await process_frame
		check(menu.preview_actor!=null,"Preview "+menu.SELLERS[i])
	menu.seller=10;menu.render();await create_timer(0.2).timeout
	await capture("office-frog")
	# Isolated data exercises projection only; no HTTP payment or player possession.
	menu.world_data={"player_id":"fixture","places":[{"slot":4,"id":"fixture-place","weekly_price":350,"tenant_id":null}]}
	menu.selected=4;menu.page="places";menu.render()
	check("350" in menu.detail.get_child(2).text,"Server weekly price is shown")
	check(menu.detail.get_child(5).disabled,"Unconnected financial bridge never offers a fake checkout")
	scene.population.apply_stall_sellers([{ "slot":2,"species":"Frog","rental_id":"fixture"}])
	check(scene.population.hired_sellers.size()==1 and scene.population.residents[0].get("covered_by_seller",false),"Authoritative seller replaces ambient appearance without duplicate NPC")
	menu.client._fail("Connection lost")
	check(scene.population.hired_sellers.is_empty() and not scene.population.residents[0].get("covered_by_seller",false),"Revocation removes rented sellers and restores ambient scenery")
	check(menu.world_data.is_empty(),"Disconnect clears server ownership and prices")
	var back := InputEventJoypadButton.new();back.button_index=JOY_BUTTON_B;back.pressed=true
	scene._unhandled_input(back)
	check(not menu.visible and not scene.modal and not scene.population.ambient_paused,"Controller Back restores exploration")
	scene.visitor.position=Vector3(230,0,-1.65);scene._process(0);scene.inspect_spot()
	check(menu.service=="tailor" and menu.visible,"THREAD opens clothing interface")
	await capture("thread-clothing");scene.hide_menu()
	scene.visitor.position=Vector3(-5.9,0,-12);scene._process(0);scene.inspect_spot()
	check(menu.service=="stall" and menu.selected==2,"Stall interaction opens its own goods")
	check(not menu.goods_confirmed,"Unavailable goods are not a confirmed empty shop")
	await capture("stall-goods")
	menu.request_page=menu.page;menu.request_slot=menu.selected;menu.received("bazaar.listings",{"items":[],"next":null})
	check(menu.goods_confirmed and menu.content.get_child(1).text=="No items listed.","Confirmed empty storefront is distinct from disconnected")
	scene.hide_menu()
	# The fourth interior retains an unblocked exit trigger.
	scene.visitor.position=Vector3(270,0,4);scene._process(0);scene.inspect_spot()
	check(scene.visitor.position.x<100,"Office exit returns to town")
	var result := {"pass":failures.is_empty(),"failures":failures,"seller_previews":12,"stalls":12,"rooms":4}
	var file := FileAccess.open(output+"/services.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "))
	print(JSON.stringify(result));scene.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
