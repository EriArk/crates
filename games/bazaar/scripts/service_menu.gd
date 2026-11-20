# SPDX-License-Identifier: GPL-3.0-or-later
extends PanelContainer
## In-world service surfaces. Availability comes from the host, never local saves.
signal closed
signal outfit_selected(look: Dictionary)
signal turn_model(radians: float)
const ITEM_ICONS = preload("res://scripts/market_goods.gd").ITEM_ICONS
const Population = preload("res://scripts/population.gd")
const SELLERS := ["Casual_Female","Casual_Male","Chef_Female","Kimono_Female","OldClassy_Male","Wizard","Witch","Bunny","Yeti","Dino","Frog","Birb"]
const NAMES := ["Traveller","Wayfarer","Chef","Tailor","Gentleman","Wizard","Witch","Bunny","Yeti","Dino","Frog","Birb"]
var client = preload("res://scripts/services_client.gd").new()
var world_data: Dictionary = {}
var server_items: Array = []
var goods_confirmed := false
var service := "office"
var page := "places"
var selected := 1
var seller := 0
var note: Label
var sale_price := 25
var receipt_message := ""
var status := "Connect to TrainerOS to check rentals and trading."
var square
var shelf: ScrollContainer
var inspector: ScrollContainer
var goods_summary := VBoxContainer.new()
var subtitle: Label
var pointer_attention := false
const Garment = preload("res://scripts/fitting_garment.gd")
var fitting_look := {}
var own_outfit := false
var focused_row := 0
var focus_after: Control
var title: Label
var hint: Label
var body: HBoxContainer
var tabs: HBoxContainer
var content: VBoxContainer
var detail: VBoxContainer
var preview: SubViewport
var preview_actor: Node3D
var preview_population: Node3D
var view_camera: Camera3D
var close_button: Button
var next_page := ""
var request_page := ""
var request_slot := 0
var loading := false
var refresh_clock := 0.0
var view_serial := 0
var request_view := -1
var queued_refresh := false
var seller_offers: Array = []

func text(value: String, size := 17, color := Color("f4ead6")) -> Label:
	var l := Label.new();l.text=value;l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",color);return l
func button(value: String, action: Callable, target: Node) -> Button:
	var b := Button.new();b.text=value;b.custom_minimum_size=Vector2(0,40);b.pressed.connect(action)
	b.add_theme_font_size_override("font_size",16)
	for state in ["normal","hover","pressed","focus","disabled"]:
		var box := StyleBoxFlat.new();box.bg_color=Color("384642") if state=="normal" else Color("866447")
		box.set_corner_radius_all(3);box.content_margin_left=10;box.content_margin_right=10
		if state=="focus":box.bg_color=Color.TRANSPARENT;box.border_color=Color("ffda89");box.set_border_width_all(3)
		if state=="disabled":box.bg_color=Color("35494a")
		b.add_theme_stylebox_override(state,box)
	target.add_child(b);return b
func clear(node: Node) -> void:
	for child in node.get_children():node.remove_child(child);child.queue_free()
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left=18;offset_right=-18;offset_top=18;offset_bottom=-18
	var box := StyleBoxFlat.new();box.bg_color=Color("17272aef");box.border_color=Color("c6a56a");box.set_border_width_all(2);box.set_corner_radius_all(3)
	box.content_margin_left=18;box.content_margin_right=18;box.content_margin_top=14;box.content_margin_bottom=14;add_theme_stylebox_override("panel",box)
	var column := VBoxContainer.new();column.add_theme_constant_override("separation",10);add_child(column)
	subtitle=text("",13,Color("f9bd68"));column.add_child(subtitle)
	var header := HBoxContainer.new();column.add_child(header)
	title=text("STALL OFFICE",26,Color("ffda89"));title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
	close_button=button("Back · B",close,header)
	hint=text(status,14,Color("cad9d2"))
	tabs=HBoxContainer.new();column.add_child(tabs)
	body=HBoxContainer.new();body.add_theme_constant_override("separation",18);body.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(body)
	var scroll := ScrollContainer.new();shelf=scroll;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true;scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(scroll)
	content=VBoxContainer.new();content.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(content)
	var detail_scroll := ScrollContainer.new();inspector=detail_scroll;detail_scroll.custom_minimum_size.x=240;detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(detail_scroll)
	detail=VBoxContainer.new();detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_scroll.add_child(detail)
	column.add_child(goods_summary)
	var footer := HBoxContainer.new();column.add_child(footer)
	note = text("ALPHA   /   Purchases closed",13,Color("ffda89"));note.size_flags_horizontal=Control.SIZE_EXPAND_FILL;footer.add_child(note)
	hint.autowrap_mode=TextServer.AUTOWRAP_OFF
	hint.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	hint.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	footer.add_child(hint)
	button("Retry",refresh,footer).name="Retry"
	add_child(client);client.connected.connect(on_connected)
	client.unavailable.connect(func(reason: String):world_data={};server_items=[];goods_confirmed=false;next_page="";seller_offers=[];queued_refresh=false;loading=false;status="Service offline";if_visible_render())
	client.read_failed.connect(failed);client.snapshot.connect(received)
	hide();client.connect_host()
func on_connected() -> void:
	if visible:refresh()
	else:client.read("bazaar.world")

func _process(delta: float) -> void:
	# Refresh leased appearances while exploring; NPC visuals are never lease authority.
	refresh_clock+=delta
	if refresh_clock<8.0:return
	refresh_clock=0.0
	if not visible and client.ready_for_reads and client.pending.is_empty():
		request_view=-1;client.read("bazaar.world")
func open(kind: String, slot := 1) -> void:
	view_serial+=1;queued_refresh=false;loading=false
	pointer_attention=false
	receipt_message=""
	own_outfit=false
	fitting_look={}
	service=kind;page="places" if kind=="office" else "goods" if kind=="stall" else "clothes"
	if kind in ["tea","curios"]:page="visitor"
	focused_row=0;status="";selected=clampi(slot,1,12);server_items=[];goods_confirmed=false;next_page="";show();render()
	if page=="visitor":return
	if not client.active:client.connect_host()
	else:refresh()
func _input(event: InputEvent) -> void:
	if not visible or service!="tailor":return
	if event is InputEventMouseMotion and not event.relative.is_zero_approx():
		pointer_attention=true
	elif event is InputEventMouseButton and event.pressed:
		pointer_attention=true
	elif event is InputEventJoypadButton or event is InputEventKey or event is InputEventScreenTouch:
		pointer_attention=false
	elif event is InputEventJoypadMotion and absf(event.axis_value)>.5:
		pointer_attention=false

func attention_control() -> Control:
	var viewport := get_viewport()
	var control := viewport.gui_get_hovered_control() if pointer_attention else viewport.gui_get_focus_owner()
	if not control or not is_ancestor_of(control):return null
	if control.has_meta("pattern_tile"):control=control.get_meta("pattern_tile")
	if control is BaseButton and control.is_visible_in_tree() and not control.disabled:return control
	return null

func close() -> void:
	view_serial+=1;queued_refresh=false;loading=false;server_items=[];goods_confirmed=false
	hide();destroy_preview();closed.emit()
func if_visible_render() -> void:
	if visible:render()
func refresh(after := "") -> void:
	if not visible or page=="visitor":return
	if not client.active:client.connect_host();return
	if not client.ready_for_reads:return
	if not client.pending.is_empty():
		queued_refresh=true;loading=true;status="Checking server…";render();return
	var method := "bazaar.world";var args := {}
	if page=="goods":
		var row := place()
		if not row.has("id"):method="bazaar.world"
		else:method="bazaar.listings";args={"place_id":row.id}
	elif page=="sellers":method="bazaar.sellers"
	elif page=="mine":method="bazaar.own_listings"
	elif page=="clothes":method="bazaar.costumes"
	if not after.is_empty() and method in ["bazaar.listings","bazaar.own_listings"]:args["after"]=after
	if client.read(method,args):
		request_view=view_serial;request_page=page;request_slot=selected;loading=true;status="Checking server…";render()
func finish_queued() -> bool:
	if not queued_refresh or not visible:return false
	queued_refresh=false;refresh();return true
func checkout(args: Dictionary) -> void:
	if loading or not client.checkout(args):return
	receipt_message = "";status="Review in TrainerOS…";loading=true
	render()

func can_trade() -> bool:
	return client.has_checkout and world_data.get("payments_available",false) and not loading

func failed(method: String, reason: String) -> void:
	if method=="bazaar.checkout":
		loading=false
		receipt_message={"review_cancelled":"Cancelled","checkout_busy":"Another checkout is open","checkout_pending":"Purchase pending · resolve at the office","insufficient_sparks":"Not enough Sparks","place_changed":"Rental terms changed","listing_changed":"This item is no longer offered at that price"}.get(reason,reason.replace("_"," ").capitalize())
		if visible:refresh()
		return
	if method=="bazaar.world":world_data={}
	if method=="bazaar.sellers":seller_offers=[]
	if finish_queued():return
	if not visible or request_view!=view_serial:return
	loading=false;server_items=[];goods_confirmed=false;next_page=""
	status={"sign_in_required":"Sign in to your TrainerOS account to use Bazaar services.","world_not_configured":"Stall rentals are not open on this island yet.","backend_unavailable":"Server unavailable. Availability and balances cannot be confirmed.","unsupported_bazaar_read":"This TrainerOS version does not support the requested service."}.get(reason,"Service unavailable · "+reason)
	if_visible_render()
func received(method: String, value: Dictionary) -> void:
	# World and offers belong to this connection; per-page replies also need the
	# exact open/switch generation, not just the same page name after reopening.
	if method=="bazaar.checkout":
		loading=false
		receipt_message={"rent":"Stall and keeper are ready","list":"Item listed","buy":"Item delivered to your profile"}.get(value.get("action",""),"Purchase resolved")
		request_view=view_serial;request_page=page;request_slot=selected
		client.read("bazaar.world")
		return
	if method=="bazaar.world":world_data=value
	if method=="bazaar.sellers":seller_offers=value.get("items",[])
	if finish_queued():return
	if not visible or request_view!=view_serial:return
	loading=false
	if method=="bazaar.world":status=""
	elif method=="bazaar.sellers":status=""
	elif request_page==page and request_slot==selected:
		goods_confirmed=method in ["bazaar.listings","bazaar.own_listings"];server_items=value.get("items",[])
		next_page=str(value.get("next") if value.get("next")!=null else "");status=""
	if_visible_render()
	if method=="bazaar.world" and page=="goods" and place().has("id"):refresh()
func place() -> Dictionary:
	for row in world_data.get("places",[]):
		if int(row.get("slot",0))==selected:return row
	return {}
func switch(next_page: String) -> void:
	view_serial+=1;loading=false
	page=next_page;focused_row=0;server_items=[];goods_confirmed=false;self.next_page="";render();refresh()
func render() -> void:
	var previous := get_viewport().gui_get_focus_owner()
	var focus_key: String = previous.get_meta("service_key","") if previous and is_ancestor_of(previous) else ""
	destroy_preview()
	for section in [tabs,content,detail,goods_summary]:clear(section)
	var office := service=="office"
	anchor_left=0.0 if office else .46
	offset_left=18 if office else 0
	subtitle.text={"office":"FESTIVAL PARK   /   VALE","stall":"FESTIVAL MARKET   /   COUNTER %02d" % selected,"tailor":"THREAD   /   WISP","tea":"MOSS   /   TEA HOUSE","curios":"ROOK   /   CURIOS"}.get(service,"")
	title.text={"office":"Rental office","stall":"Market wares","tailor":"Fitting room","tea":"Moss & Tea","curios":"Curio shop"}.get(service,"Bazaar")
	note.text = "Review in TrainerOS" if can_trade() or world_data.get("payments_available",false) and client.has_checkout else "ALPHA   /   Purchases closed"
	if "--test-market" in OS.get_cmdline_user_args():note.text="Test Sparks · "+note.text
	if not receipt_message.is_empty() and not loading:note.text=receipt_message
	hint.text=status
	hint.tooltip_text=status
	hint.visible=not status.is_empty() and page!="visitor"
	find_child("Retry",true,false).visible=hint.visible and not loading
	inspector.visible=office
	inspector.custom_minimum_size.x=250
	goods_summary.visible=page=="goods" and not server_items.is_empty()
	tabs.visible=office
	focus_after=null
	if office:
		for entry in [["places","Park map"],["sellers","Sellers"],["mine","My goods"]]:
			var key: String=entry[0]
			var tab := button(entry[1],func():switch(key),tabs)
			tab.set_meta("service_key",key)
			tab.toggle_mode=true
			tab.button_pressed=page==key
	match page:
		"places":render_places()
		"sellers":render_sellers()
		"clothes":render_clothes()
		"visitor":content.add_child(text("The tea house is opening soon." if service=="tea" else "The curios collection is coming soon.",20))
		_:render_goods()
	for node in find_children("*","Button",true,false):
		if not focus_key.is_empty() and node.get_meta("service_key","")==focus_key:
			focus_after=node
			break
	if focus_after:focus_after.grab_focus()
	else:close_button.grab_focus()

func render_places() -> void:
	var map = preload("res://scripts/rental_map.gd").new()
	map.clip_contents=true
	content.add_child(map)
	var markers := {}
	for slot in range(1,13):
		var marker := button("%02d"%slot,func():select_place(slot),map)
		marker.custom_minimum_size=Vector2(48,0)
		marker.add_theme_constant_override("h_separation",0)
		marker.add_theme_font_size_override("font_size",14)
		marker.toggle_mode=true
		marker.set_meta("service_key","slot-%d"%slot)
		marker.focus_entered.connect(select_place.bind(slot))
		markers[slot]=marker
		if slot==selected:focus_after=marker
	map.configure(square,markers)
	select_place(selected)

func select_place(slot: int) -> void:
	selected=slot
	for child in content.get_child(0).markers.values():
		child.set_pressed_no_signal(int(child.text)==slot)
	clear(detail)
	var row := place()
	detail.add_child(text("STALL   %02d"%selected,25,Color("ffcf83")))
	detail.add_child(text("West row" if selected<=6 else "East row",16))
	var terms := "Weekly rent unconfirmed"
	if row.get("weekly_price")!=null:terms="%s Sparks / 7 days"%row.weekly_price
	detail.add_child(text(terms,19))
	if not row.is_empty():
		detail.add_child(text("Occupied" if row.get("tenant_id")!=null else "Available" if row.get("weekly_price")!=null else "Rent not set",15))
	if row.get("expires_at")!=null:detail.add_child(text("Until "+str(row.expires_at),14))
	detail.add_child(text("%s Sparks per seller, per rental"%world_data.seller_price if world_data.has("seller_price") else "Seller fee unconfirmed",15))
	button("Choose seller  ›",func():switch("sellers"),detail)
	if world_data.get("checkout_pending",false):
		button("Resolve last checkout",func():checkout({"action":"resolve"}),detail).disabled=not client.has_checkout or loading

func render_sellers() -> void:
	content.add_child(text("Choose a keeper for stall %02d"%selected,20))
	var grid := GridContainer.new()
	grid.columns=3
	content.add_child(grid)
	for i in SELLERS.size():
		var tile := button(NAMES[i],func():select_seller(i),grid)
		tile.set_meta("service_key","keeper-%d"%i)
		tile.focus_entered.connect(select_seller.bind(i))
		if i==seller:focus_after=tile
	select_seller(seller)

func select_seller(index: int) -> void:
	if index==seller and is_instance_valid(preview_actor):return
	seller=index
	destroy_preview()
	clear(detail)
	detail.add_child(text(NAMES[seller],23,Color("ffcf83")))
	make_preview(SELLERS[seller])
	var price := "Price unavailable"
	for row in seller_offers:
		if row.get("id")==SELLERS[seller]:price="%s Sparks"%row.price;break
	detail.add_child(text(price+"  /  one rental",16))
	var row := place()
	var weekly = row.get("weekly_price")
	var fee = world_data.get("seller_price")
	var offered := not price.begins_with("Price unavailable") and weekly != null and fee != null
	var caption := "Rent with keeper" if not offered else "Rent with keeper · %d Sparks"%(int(weekly)+int(fee))
	button(caption,func():checkout({"action":"rent","slot":selected,"revision":row.revision,"price":weekly,"species":SELLERS[seller],"seller_price":fee}),detail).disabled=not can_trade() or not offered or row.get("tenant_id")!=null or world_data.get("owner_id")==world_data.get("player_id")

func render_goods() -> void:
	var mine := page=="mine"
	content.add_child(text("Your listings" if mine else "On the counter",20,Color("ffcf83")))
	var counter := place()
	if page=="goods" and can_trade() and counter.get("tenant_id")!=null and counter.get("tenant_id")==world_data.get("player_id") and counter.get("species")!=null:
		var pricing := HBoxContainer.new()
		content.add_child(pricing)
		var amount := SpinBox.new()
		amount.min_value=1;amount.max_value=2147483647;amount.value=sale_price
		amount.suffix=" Sparks";amount.value_changed.connect(func(value: float):sale_price=int(value))
		pricing.add_child(amount)
		button("List profile item",func():checkout({"action":"list","slot":selected,"price":sale_price}),pricing)
	if server_items.is_empty():
		content.add_child(text("Checking wares…" if loading else "No items listed." if goods_confirmed else "Stock unavailable",22))
		if goods_confirmed:content.add_child(text("Nothing on this counter today.",15))
		return
	var grid := GridContainer.new()
	grid.columns=2
	content.add_child(grid)
	var description := detail if mine else goods_summary
	var item_detail := VBoxContainer.new()
	description.add_child(item_detail)
	focused_row=clampi(focused_row,0,server_items.size()-1)
	for i in server_items.size():
		var row: Dictionary=server_items[i]
		var tile := button(str(row.get("presentation",{}).get("title","Item"))+"\n%s Sparks"%row.get("price","?"),func():inspect_good(i,item_detail),grid)
		tile.icon=ITEM_ICONS.get(row.get("presentation",{}).get("icon","inventory"),ITEM_ICONS.inventory)
		tile.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		tile.custom_minimum_size=Vector2(132,62)
		tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		tile.set_meta("service_key","listing-%s"%row.get("id",i))
		tile.focus_entered.connect(inspect_good.bind(i,item_detail))
		if i==focused_row:focus_after=tile
	inspect_good(focused_row,item_detail)
	if not next_page.is_empty():
		button("More wares  ›",func():refresh(next_page),content).disabled=loading

func inspect_good(index: int, target: Control) -> void:
	focused_row=index
	clear(target)
	var row: Dictionary=server_items[index]
	var info: Dictionary=row.get("presentation",{})
	target.add_child(text(str(info.get("title","Item")),22,Color("ffcf83")))
	target.add_child(text(str(info.get("game","")),15))
	var facts := PackedStringArray()
	for fact in info.get("facts",[]):facts.append("%s %s"%[fact.label,fact.value])
	if not facts.is_empty():
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size.y=46
		scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		scroll.focus_mode=Control.FOCUS_ALL
		target.add_child(scroll)
		var description:=text("   ·   ".join(facts),14)
		description.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		scroll.add_child(description)
	target.add_child(text("%s Sparks"%row.get("price","?"),18))
	if page=="mine":return
	button("Buy",func():checkout({"action":"buy","slot":selected,"listing_id":row.id,"revision":row.revision,"price":row.price}),target).disabled=not can_trade() or row.get("seller_id")==world_data.get("player_id")

func render_clothes() -> void:
	content.add_child(text("Outfit sets",21,Color("ffcf83")))
	var patterns: Array=server_items if not server_items.is_empty() else [{"id":"costume.traveller","title":"Traveller","price":50},{"id":"costume.mage","title":"Mage","price":50},{"id":"costume.merchant","title":"Merchant","price":50}]
	var grid := GridContainer.new()
	grid.columns=3
	content.add_child(grid)
	var caption := text("",16)
	content.add_child(caption)
	var controls := HBoxContainer.new()
	content.add_child(controls)
	var pieces := GridContainer.new()
	pieces.columns=2
	content.add_child(pieces)
	var refresh_labels := func():
		for index in pieces.get_child_count():
			var slot: String=Garment.SLOTS[index]
			var style: String=fitting_look.get(slot,"")
			var part_button := pieces.get_child(index) as Button
			part_button.visible=not style.is_empty()
			if part_button.visible:part_button.text="%s  ›"%Garment.NAMES[style][index]
	var available_styles: Array[String]=[]
	for row in patterns:
		var style:=str(row.get("id","")).trim_prefix("costume.")
		if style in Garment.STYLES:available_styles.append(style)
	for slot: String in Garment.SLOTS:
		var cycle := func():
			if fitting_look.is_empty() or available_styles.is_empty():return
			var index := available_styles.find(fitting_look[slot])
			fitting_look[slot]=available_styles[(index+1)%available_styles.size()]
			outfit_selected.emit(fitting_look)
			caption.text="Custom fitting"
			refresh_labels.call()
		var part := button("",cycle,pieces)
		part.tooltip_text="Change "+slot.to_lower()
		part.set_meta("service_key","piece-"+slot)
	var first_render := fitting_look.is_empty() and not own_outfit
	for i in patterns.size():
		var row: Dictionary=patterns[i]
		var key:=str(row.get("id","")).trim_prefix("costume.")
		var card := VBoxContainer.new()
		grid.add_child(card)
		var sketch = preload("res://scripts/catalogue_art.gd").new()
		sketch.design=key
		sketch.custom_minimum_size=Vector2(78,100)
		sketch.mouse_filter=Control.MOUSE_FILTER_STOP
		card.add_child(sketch)
		var price := "%s set  ·  %s Sparks%s"%[row.title,str(int(row.price)) if row.has("price") else "?"," planned" if server_items.is_empty() else ""]
		var choose := func():
			focused_row=i
			own_outfit=false
			fitting_look=Garment.full_set(key)
			outfit_selected.emit(fitting_look)
			caption.text=price if not fitting_look.is_empty() else "Sample unavailable"
			refresh_labels.call()
		var tile := button(str(row.title),choose,card)
		tile.set_meta("service_key","pattern-"+key)
		sketch.set_meta("pattern_tile",tile)
		tile.focus_entered.connect(choose)
		sketch.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:tile.grab_focus();choose.call())
		if first_render and i==0:
			focus_after=tile
			choose.call()
		elif fitting_look==Garment.full_set(key) and not fitting_look.is_empty():
			caption.text=price
			focus_after=tile
	if caption.text.is_empty():caption.text="Custom fitting"
	button("↶  Turn",func():turn_model.emit(PI/4),controls).set_meta("service_key","turn-left")
	button("Turn  ↷",func():turn_model.emit(-PI/4),controls).set_meta("service_key","turn-right")
	var compare := func():
		own_outfit=true
		fitting_look={}
		outfit_selected.emit(fitting_look)
		caption.text="Your current outfit"
		refresh_labels.call()
	var own_button := button("Own outfit",compare,controls)
	own_button.set_meta("service_key","own-outfit")
	if own_outfit:
		focus_after=own_button
		compare.call()
	refresh_labels.call()

func destroy_preview() -> void:
	if is_instance_valid(preview_population):preview_population.queue_free()
	preview_population=null;preview_actor=null;preview=null
func make_preview(species: String) -> void:
	var container := SubViewportContainer.new();container.custom_minimum_size=Vector2(220,170);container.stretch=true;container.mouse_filter=Control.MOUSE_FILTER_IGNORE;detail.add_child(container)
	preview=SubViewport.new();preview.size=Vector2i(220,170);preview.own_world_3d=true;preview.transparent_bg=true;container.add_child(preview)
	preview_population=Population.new();preview.add_child(preview_population);preview_population.set_process(false)
	var actor: Dictionary=preview_population.figure(species,Vector3.ZERO,0.48,seller%5);preview_actor=actor.node
	var light := DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-30,0);light.light_energy=1.5;preview.add_child(light)
	var env := WorldEnvironment.new();env.environment=Environment.new();env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("d9e7e0");env.environment.ambient_light_energy=0.8;preview.add_child(env)
	view_camera=Camera3D.new();preview.add_child(view_camera);view_camera.position=Vector3(0,1.3,3);view_camera.look_at(Vector3(0,0.9,0));view_camera.fov=38
