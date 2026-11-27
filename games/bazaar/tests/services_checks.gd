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
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--descriptor="):scene.visitor.appearance(JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--descriptor="))))
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
	var map=menu.content.get_child(0)
	await process_frame
	for marker in map.markers.values():check(menu.shelf.get_global_rect().encloses(marker.get_global_rect()),"All numbered markers fit the map without scrolling")
	for tag in map.labels:check(menu.shelf.get_global_rect().encloses(tag.get_global_rect()),"All landmarks fit the map")
	check(map.markers.size()==12,"All actual stalls are selectable")
	check(map.markers[1].position.x<map.markers[7].position.x and map.markers[1].position.y<map.markers[6].position.y,"Map corresponds to west/east and north/south")
	map.markers[3].grab_focus()
	check(menu.selected==3 and menu.detail.get_child(0).text.contains("03"),"D-pad focus updates rental terms directly")
	await capture("office-places")
	menu.switch("sellers");await create_timer(0.3).timeout
	check(menu.preview_actor!=null,"Seller preview uses actual native model")
	await capture("office-sellers")
	for i in menu.SELLERS.size():
		menu.content.get_child(1).get_child(i).grab_focus();await process_frame
		check(menu.preview_actor!=null,"Preview "+menu.SELLERS[i])
	menu.content.get_child(1).get_child(10).grab_focus();await create_timer(0.2).timeout
	await capture("office-frog")
	# Isolated data exercises projection only; no HTTP payment or player possession.
	menu.world_data={"player_id":"fixture","places":[{"slot":4,"id":"fixture-place","weekly_price":350,"tenant_id":null}]}
	menu.selected=4;menu.page="places";menu.render()
	check("350" in menu.detail.get_child(2).text,"Server weekly price is shown")
	menu.switch("sellers")
	check(menu.detail.get_child(-1).disabled,"Unconnected financial bridge disables staffed checkout")
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
	var booth=scene.square.fitting_booth
	check(booth.visitor==scene.visitor,"Clerk uses the in-world fitting booth")
	var platform_position: Vector3=scene.visitor.anchor.global_position
	scene.visitor.position.y+=.22
	check(scene.visitor.anchor.global_position.is_equal_approx(platform_position),"Feet stay on the fitting platform while the exploration body settles")
	await create_timer(1.1).timeout
	check(booth.displayed==booth.Garment.full_set("traveller") and is_instance_valid(booth.garment),"First costume fitted")
	var patterns=menu.content.get_child(1)
	patterns.get_child(1).get_child(1).grab_focus()
	patterns.get_child(2).get_child(1).grab_focus()
	for frame in 150:
		await process_frame
		if booth.displayed==booth.Garment.full_set("merchant"):break
	check(booth.displayed==booth.Garment.full_set("merchant") and is_equal_approx(booth.curtain,1.0),"Latest outfit installed behind closed curtains")
	await capture("fitting-closed")
	for index in 3:
		var choice: String=["traveller","mage","merchant"][index]
		patterns.get_child(index).get_child(1).grab_focus()
		await create_timer(1.25).timeout
		check(booth.displayed==booth.Garment.full_set(choice) and booth.curtain<.05 and is_instance_valid(booth.garment),"Revealed "+choice)
		await capture("fitting-"+choice)
	var boots_button=menu.content.get_child(4).get_child(2)
	boots_button.grab_focus()
	boots_button.pressed.emit()
	await create_timer(1.1).timeout
	check(booth.displayed.Boots=="traveller" and booth.displayed.Top=="merchant","Boots change independently behind the curtain")
	menu.render()
	check(menu.fitting_look==booth.displayed,"Refresh preserves mixed pieces")
	var facing: float=scene.visitor.anchor.rotation.y
	var controls=menu.content.get_child(3)
	controls.get_child(0).pressed.emit()
	check(not is_equal_approx(facing,scene.visitor.anchor.rotation.y),"Rotation control turns model")
	controls.get_child(2).grab_focus()
	controls.get_child(2).pressed.emit()
	menu.render()
	await create_timer(1.1).timeout
	check(not is_instance_valid(booth.garment),"Original outfit comparison")
	booth.select(booth.Garment.full_set("mage"))
	booth._process(.1)
	check(booth.curtain>0 and booth.curtain<1 and not is_instance_valid(booth.garment),"Old appearance stays in place until the curtain closes")
	scene._unhandled_input(back)
	check(booth.visitor==null and not scene.visitor.fitting_pose and scene.visitor.anchor.position.is_zero_approx(),"Leaving midway restores exploration")
	scene.visitor.position=booth.global_position+Vector3(0,0,.95)
	scene._process(0);scene.inspect_spot()
	check(booth.visitor==scene.visitor,"Walk-up booth opens the same fitting room")
	scene.hide_menu()
	scene.visitor.position=scene.square.stall_layout(2).approach;scene._process(0);scene.inspect_spot()
	check(menu.service=="stall" and menu.selected==2,"Stall interaction opens its own goods")
	check(not menu.goods_confirmed,"Unavailable goods are not a confirmed empty shop")
	await capture("stall-goods")
	menu.request_view=menu.view_serial;menu.request_page=menu.page;menu.request_slot=menu.selected;menu.received("bazaar.listings",{"items":[{"id":"gem","price":8,"presentation":{"title":"Oran Berry","game":"Pokémon Emerald","icon":"star"}},{"id":"leaf","price":12,"presentation":{"title":"Pecha Berry","game":"Pokémon Emerald","icon":"star"}}],"next":null})
	var tiles=menu.content.get_child(1)
	check(tiles.get_child(0).face != tiles.get_child(1).face,"Adapter catalogue gives each berry its own art")
	tiles.get_child(1).grab_focus()
	check(menu.focused_row==1,"Moving focus inspects the next item")
	await capture("stall-stock")
	menu.received("bazaar.listings",{"items":[],"next":null})
	check(menu.goods_confirmed and menu.content.find_child("ShelfStatus",true,false).text=="No items listed.","Confirmed empty storefront is distinct from disconnected")
	# A reply from a closed/reopened page cannot populate the next visit.
	menu.request_view=menu.view_serial;menu.request_page=menu.page;menu.request_slot=menu.selected
	menu.close();menu.view_serial+=1;menu.show();menu.server_items=[];menu.goods_confirmed=false
	menu.received("bazaar.listings",{"items":[{"id":"old","price":999,"presentation":{"title":"Old reply"}}]})
	check(menu.server_items.is_empty() and not menu.goods_confirmed,"Late response after close/reopen is ignored")
	# Switch while one bounded transport request is outstanding: latest page is
	# fetched after completion rather than silently losing the user's selection.
	menu.client.active=true;menu.client.ready_for_reads=true
	menu.client.pending={"fixture":{"method":"bazaar.world","deadline":Time.get_ticks_msec()+20000}}
	menu.switch("sellers")
	check(menu.queued_refresh,"Busy transport queues the new page")
	menu.client.pending.clear()
	menu.received("bazaar.world",{"places":[],"seller_price":275})
	check(not menu.queued_refresh and menu.client.pending.values()[0].method=="bazaar.sellers","Completion fetches authoritative seller offers")
	menu.client.pending.clear();menu.client.outgoing.clear()
	menu.received("bazaar.sellers",{"items":[{"id":"Frog","price":275,"revision":2}]})
	menu.content.get_child(1).get_child(10).grab_focus()
	check("275 Sparks" in menu.detail.get_child(2).text,"Seller price uses server offer rather than local 100")
	menu.failed("bazaar.sellers","backend_unavailable")
	check(menu.seller_offers.is_empty() and "Price unavailable" in menu.detail.get_child(2).text,"Failed seller refresh clears stale price")
	menu.client.disconnect_host()

	scene.hide_menu()
	# The fourth interior retains an unblocked exit trigger.
	scene.visitor.position=Vector3(270,0,4);scene._process(0);scene.inspect_spot()
	check(scene.visitor.position.x<100,"Office exit returns to town")
	menu.show();menu.queued_refresh=false
	var offered=[{"id":"cap","kind":"garment","title":"Market beret","price":35},
		{"id":"case","kind":"material","title":"Empty cartridge","price":12},
		{"id":"profile.aurora","kind":"scene","title":"Aurora","owned":true,"price":250}]
	menu.client.has_checkout=true
	for key in ["tailor","curios","decorator"]:
		menu.service="tailor" if key=="tailor" else "curios"
		menu.page="decorator" if key=="decorator" else "store"
		menu.request_view=menu.view_serial;menu.request_page=menu.page;menu.request_slot=menu.selected
		menu.received("bazaar.store",{"items":offered,"payments_available":true})
		check(menu.content.get_child_count()==1,"Only appropriate inventory at "+key)
		var tile=menu.content.get_child(0)
		check(tile.disabled==(key=="decorator"),"Owned scene cannot be bought twice")
		menu.received("bazaar.store",{"items":offered,"payments_available":false})
		check(menu.content.get_child(0).disabled,"Closed market blocks checkout at "+key)
	var result := {"pass":failures.is_empty(),"failures":failures,"seller_previews":12,"stalls":12,"rooms":4}
	var file := FileAccess.open(output+"/services.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "))
	print(JSON.stringify(result));scene.audio.stop_all();await create_timer(.2).timeout;scene.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
