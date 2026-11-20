# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
## Run against the isolated two-wallet TrainerOS host. The real shell owns confirmation.
var world
var menu
var directory := OS.get_environment("BAZAAR_TRADE_EVIDENCE")
var phase := OS.get_environment("BAZAAR_TRADE_PHASE")

func _initialize() -> void:run.call_deferred()

func until(predicate: Callable, reason: String) -> bool:
	var deadline := Time.get_ticks_msec()+35000
	while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
	if not predicate.call():
		push_error("Market journey: "+reason+" / "+menu.status+" / "+menu.receipt_message)
		quit(1)
		return false
	return true

func press(prefix: String) -> bool:
	for b in menu.find_children("*","Button",true,false):
		if b.is_visible_in_tree() and not b.disabled and b.text.begins_with(prefix):
			b.pressed.emit()
			return true
	push_error("Missing enabled action: "+prefix)
	quit(1)
	return false

func approach(at: Vector3) -> void:
	if world.modal:world.hide_menu()
	world.visitor.enter_space(at+Vector3.UP*.09,0)
	world._process(0)
	world.inspect_spot()

func capture(name: String) -> void:
	if directory.is_empty() or DisplayServer.get_name()=="headless":return
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory+"/"+name+".png")

func run() -> void:
	if not "--test-market" in OS.get_cmdline_user_args() or phase not in ["list","buy","resolve","return"]:
		quit(2);return
	world=load("res://main.tscn").instantiate();root.add_child(world)
	world.smoke_mode=true;menu=world.services
	world.visitor.set_physics_process(false)
	if not await until(func():return menu.world_data.has("places") and menu.client.has_checkout,"test SDK handshake"):return
	var desk := Vector3(270,0,-1.65)
	var layout: Dictionary=world.square.stall_layout(2)
	if phase=="list":
		approach(desk)
		if not await until(func():return not menu.loading and menu.page=="places","office map"):return
		menu.select_place(2)
		if not press("Choose seller"):return
		if not await until(func():return menu.page=="sellers" and not menu.seller_offers.is_empty() and not menu.loading,"keeper catalogue"):return
		menu.select_seller(menu.SELLERS.find("Frog"))
		await capture("office")
		if not press("Rent with keeper · 250"):return
		if not await until(func():return menu.receipt_message=="Cancelled" and not menu.loading,"cancelled host review"):return
		if not press("Rent with keeper · 250"):return
		if not await until(func():return menu.place().get("species")=="Frog" and not menu.loading,"staffed rental"):return
		approach(layout.approach)
		if not await until(func():return menu.goods_confirmed and not menu.loading,"own counter"):return
		var price: SpinBox=menu.find_children("*","SpinBox",true,false).front()
		price.value=65
		if not press("List profile item"):return
		if not await until(func():return menu.server_items.size()==1 and menu.goods_confirmed and not menu.loading,"listed item"):return
		await capture("listed")
	elif phase=="resolve":
		approach(desk)
		if not await until(func():return menu.world_data.get("checkout_pending",false) and not menu.loading,"durable pending operation after restart"):return
		menu.select_place(2)
		if not press("Resolve last checkout"):return
		if not await until(func():return not menu.world_data.get("checkout_pending",true) and not menu.loading,"original receipt"):return
	elif phase=="buy":
		if not await until(func():return world.square.display_rows.has(2) and world.square.display_rows[2].items.size()==1,"visible seller and showcase"):return
		var shelf: Dictionary=world.square.display_rows[2]
		if shelf.tenant!="Mika" or shelf.items[0].title!="Oran Berry" or shelf.items[0].price!=65:
			push_error("Wrong public merchandise");quit(1);return
		var camera=world.service_camera
		camera.global_position=layout.approach+Vector3(2.4,1.5,.7)
		camera.look_at(layout.seller+Vector3.UP*1.22);camera.fov=42;camera.make_current()
		await capture("mika-counter")
		approach(layout.approach)
		if not await until(func():return menu.goods_confirmed and menu.server_items.size()==1 and not menu.loading,"buyer's goods view"):return
		if not press("Buy"):return
		if not await until(func():return menu.receipt_message.begins_with("Purchase pending") and not menu.loading,"committed purchase with lost reply"):return
	else:
		approach(layout.approach)
		if not await until(func():return menu.goods_confirmed and menu.server_items.is_empty() and not menu.loading,"empty shelf after reopening"):return
		if not press("Profile inventory"):return
		if not await until(func():return FileAccess.file_exists(directory+"/received-item.png") and not menu.loading,"received item in the native profile inventory"):return
	print("BAZAAR_TRADE_PASS ", phase)
	await world.leave_bazaar()
