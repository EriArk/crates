# SPDX-License-Identifier: GPL-3.0-or-later
extends PanelContainer
## In-world service surfaces. Availability comes from the host, never local saves.
signal closed
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
var status := "Connect to TrainerOS to check rentals and trading."
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

func text(value: String, size := 17, color := Color("f4ead6")) -> Label:
	var l := Label.new();l.text=value;l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",color);return l
func button(value: String, action: Callable, target: Node) -> Button:
	var b := Button.new();b.text=value;b.custom_minimum_size=Vector2(0,40);b.pressed.connect(action)
	b.add_theme_font_size_override("font_size",16)
	for state in ["normal","hover","pressed","focus","disabled"]:
		var box := StyleBoxFlat.new();box.bg_color=Color("2c5657") if state=="normal" else Color("3c6c69")
		box.set_corner_radius_all(8);box.content_margin_left=10;box.content_margin_right=10
		if state=="focus":box.bg_color=Color.TRANSPARENT;box.border_color=Color("ffda89");box.set_border_width_all(3)
		if state=="disabled":box.bg_color=Color("35494a")
		b.add_theme_stylebox_override(state,box)
	target.add_child(b);return b
func clear(node: Node) -> void:
	for child in node.get_children():node.remove_child(child);child.queue_free()
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left=18;offset_right=-18;offset_top=18;offset_bottom=-18
	var box := StyleBoxFlat.new();box.bg_color=Color("143a40");box.border_color=Color("c6a56a");box.set_border_width_all(2);box.set_corner_radius_all(14)
	box.content_margin_left=18;box.content_margin_right=18;box.content_margin_top=14;box.content_margin_bottom=14;add_theme_stylebox_override("panel",box)
	var column := VBoxContainer.new();column.add_theme_constant_override("separation",10);add_child(column)
	var header := HBoxContainer.new();column.add_child(header)
	title=text("STALL OFFICE",26,Color("ffda89"));title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
	close_button=button("Back · B",close,header)
	hint=text(status,14,Color("cad9d2"));column.add_child(hint)
	tabs=HBoxContainer.new();column.add_child(tabs)
	body=HBoxContainer.new();body.add_theme_constant_override("separation",18);body.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(body)
	var scroll := ScrollContainer.new();scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(scroll)
	content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(content)
	var detail_scroll := ScrollContainer.new();detail_scroll.custom_minimum_size.x=275;detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(detail_scroll)
	detail=VBoxContainer.new();detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_scroll.add_child(detail)
	var footer := HBoxContainer.new();column.add_child(footer)
	var note := text("SERVICES IN DEVELOPMENT · No Sparks are spent in this build",13,Color("ffda89"));note.size_flags_horizontal=Control.SIZE_EXPAND_FILL;footer.add_child(note)
	button("Refresh",refresh,footer)
	add_child(client);client.connected.connect(func():refresh())
	client.unavailable.connect(func(reason: String):world_data={};server_items=[];goods_confirmed=false;next_page="";loading=false;status=reason;if_visible_render())
	client.read_failed.connect(failed);client.snapshot.connect(received)
	hide()
func _process(delta: float) -> void:
	# Refresh leased appearances while exploring; NPC visuals are never lease authority.
	refresh_clock+=delta
	if refresh_clock<30.0:return
	refresh_clock=0.0
	if not visible and not world_data.is_empty() and client.ready_for_reads:client.read("bazaar.world")
func open(kind: String, slot := 1) -> void:
	service=kind;page="places" if kind=="office" else "goods" if kind=="stall" else "clothes"
	selected=clampi(slot,1,12);server_items=[];goods_confirmed=false;next_page="";show();render();close_button.grab_focus()
	if not client.active:client.connect_host()
	else:refresh()
func close() -> void:
	hide();destroy_preview();closed.emit()
func if_visible_render() -> void:
	if visible:render()
func refresh(after := "") -> void:
	if not visible:return
	if not client.active:client.connect_host();return
	if not client.ready_for_reads:return
	var method := "bazaar.world";var args := {}
	if page=="goods":
		var row := place()
		if not row.has("id"):method="bazaar.world"
		else:method="bazaar.listings";args={"place_id":row.id}
	elif page=="mine":method="bazaar.own_listings"
	elif page=="clothes":method="bazaar.costumes"
	if not after.is_empty() and method in ["bazaar.listings","bazaar.own_listings"]:args["after"]=after
	if client.read(method,args):
		request_page=page;request_slot=selected;loading=true;status="Checking server…";render()
func failed(method: String, reason: String) -> void:
	loading=false
	if method=="bazaar.world":world_data={}
	server_items=[];goods_confirmed=false
	status={"sign_in_required":"Sign in to your TrainerOS account to use Bazaar services.","world_not_configured":"Stall rentals are not open on this island yet.","backend_unavailable":"Server unavailable. Availability and balances cannot be confirmed.","unsupported_bazaar_read":"This TrainerOS version does not support the requested service."}.get(reason,"Service unavailable · "+reason)
	if_visible_render()
func received(method: String, value: Dictionary) -> void:
	loading=false
	if method=="bazaar.world":world_data=value;status="Server directory refreshed. Payments are not enabled in this world build."
	elif request_page==page and request_slot==selected:goods_confirmed=method in ["bazaar.listings","bazaar.own_listings"];server_items=value.get("items",[]);next_page=str(value.get("next") if value.get("next")!=null else "");status="Server inventory refreshed."
	if_visible_render()
	if method=="bazaar.world" and page=="goods" and place().has("id"):refresh()
func place() -> Dictionary:
	for row in world_data.get("places",[]):
		if int(row.get("slot",0))==selected:return row
	return {}
func switch(next_page: String) -> void:
	page=next_page;server_items=[];goods_confirmed=false;self.next_page="";render();refresh()
func render() -> void:
	destroy_preview();clear(tabs);clear(content);clear(detail)
	title.text={"office":"STALL OFFICE","stall":"FESTIVAL STALL %02d"%selected,"tailor":"THREAD · AVATAR CLOTHING"}.get(service,"BAZAAR")
	hint.text=status
	if service=="office":
		for entry in [["places","Rent a stall"],["sellers","NPC sellers"],["mine","My goods"]]:
			var key: String=entry[0];var b := button(entry[1],func():switch(key),tabs);b.toggle_mode=true;b.button_pressed=page==key
	if page=="places":render_places()
	elif page=="sellers":render_sellers()
	elif page=="clothes":render_clothes()
	else:render_goods()
func render_places() -> void:
	content.add_child(text("FESTIVAL PARK",17,Color("ffda89")))
	content.add_child(text("Two festival rows · Select a numbered place",14))
	var grid := GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",6);content.add_child(grid)
	for n in range(1,13):
		var row := {}
		for r in world_data.get("places",[]):
			if int(r.get("slot",0))==n:row=r;break
		var condition := "Not connected"
		if not row.is_empty():condition="Occupied" if row.get("tenant_id")!=null else "Price not set" if row.get("weekly_price")==null else "%s Sparks / week"%row.weekly_price
		var b := button("%02d   %s\n%s"%[n,"WEST" if n<=6 else "EAST",condition],func():selected=n;render();focus_stall(n),grid)
		b.custom_minimum_size=Vector2(165,55);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.toggle_mode=true;b.button_pressed=selected==n
	var row := place()
	detail.add_child(text("STALL %02d"%selected,24,Color("ffda89")))
	detail.add_child(text("7 days from payment\nNo automatic renewal",17))
	detail.add_child(text("Weekly rent\n"+(str(row.weekly_price)+" Sparks" if row.get("weekly_price")!=null else "Set by the Bazaar owner"),17))
	detail.add_child(text("NPC seller · 100 Sparks\nPaid for each rental separately",17))
	if row.get("expires_at")!=null:detail.add_child(text("Occupied until\n"+str(row.expires_at),14))
	button("Choose a seller",func():switch("sellers"),detail)
	var rent := button("Rent for 7 days",func():pass,detail);rent.disabled=true
	detail.add_child(text("Rentals are not available yet.",14,Color("cad9d2")))
func focus_stall(n: int) -> void:
	var grid: GridContainer=content.get_child(2)
	grid.get_child(n-1).grab_focus()
func render_sellers() -> void:
	content.add_child(text("YOUR STALL'S SELLER",17,Color("ffda89")))
	content.add_child(text("100 Sparks for the current rental. Choose before paying.",14))
	var grid := GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",6);content.add_child(grid)
	for i in SELLERS.size():
		var b := button(NAMES[i],func():seller=i;render();content.get_child(2).get_child(i).grab_focus(),grid)
		b.custom_minimum_size=Vector2(165,55);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.toggle_mode=true;b.button_pressed=seller==i
	detail.add_child(text(NAMES[seller].to_upper(),24,Color("ffda89")))
	make_preview(SELLERS[seller])
	detail.add_child(text("100 Sparks · Until rental ends",15))
	var hire := button("Hire this seller",func():pass,detail);hire.disabled=true
	detail.add_child(text("Preview only. Hiring is not available yet.",14,Color("cad9d2")))
func render_goods() -> void:
	content.add_child(text("MY LISTINGS" if page=="mine" else "GOODS FOR SALE",20,Color("ffda89")))
	if server_items.is_empty():
		content.add_child(text("Checking goods…" if loading else "No items listed." if goods_confirmed else "Goods are unavailable.",20))
		content.add_child(text("Players sell items from their profile inventory." if goods_confirmed else "Connect to TrainerOS to view the goods.",16))
	else:
		for row in server_items:
			var b := button(str(row.get("presentation",{}).get("title","Item"))+" · "+str(row.get("price","?"))+" Sparks",func():show_item(row),content)
			b.custom_minimum_size.y=52
		if not next_page.is_empty():button("Next page",func():refresh(next_page),content).disabled=loading
	detail.add_child(text("PROFILE INVENTORY",20,Color("ffda89")))
	detail.add_child(text("Rent a place at the Stall Office, hire an NPC and list your stored game loot. Unsold goods stay yours after the lease expires.",17))
	var add := button("List an inventory item",func():pass,detail);add.disabled=true
	detail.add_child(text("Trading will open once item transfers are ready.",14,Color("cad9d2")))
func show_item(row: Dictionary) -> void:
	clear(detail)
	var info: Dictionary=row.get("presentation",{})
	detail.add_child(text(str(info.get("title","Item")),24,Color("ffda89")))
	detail.add_child(text(str(info.get("game","")),16))
	for fact in info.get("facts",[]):detail.add_child(text(str(fact.label)+": "+str(fact.value),15))
	detail.add_child(text(str(row.get("price","?"))+" Sparks",22))
	var buy := button("Withdraw listing" if page=="mine" else "Buy item",func():pass,detail);buy.disabled=true
	detail.add_child(text("Trading is not available yet. No Sparks are spent.",14))
func render_clothes() -> void:
	content.add_child(text("CLOTHING FOR YOUR TRAINER",24,Color("ffda89")))
	content.add_child(text("New fantasy outfits for your TrainerOS avatar.",18))
	content.add_child(text("COSTUMES ARE IN DEVELOPMENT",22,Color("ffda89")))
	var cards: Array=server_items if not server_items.is_empty() else [{"title":"Traveller","price":50},{"title":"Mage","price":50},{"title":"Merchant","price":50}]
	for row in cards:
		var card := button(str(row.title)+" · "+str(row.price)+" Sparks"+(" (planned)" if server_items.is_empty() else ""),func():pass,content)
		card.disabled=true;card.custom_minimum_size.y=48

	content.add_child(text("There are no purchasable costumes in this build. The existing free avatar editor stays free.",17))
	detail.add_child(text("FITTING ROOM",22,Color("ffda89")))
	detail.add_child(text("New costumes are being made. You will be able to try them on before buying them here.",17))
func destroy_preview() -> void:
	if is_instance_valid(preview_population):preview_population.queue_free()
	preview_population=null;preview_actor=null;preview=null
func make_preview(species: String) -> void:
	var container := SubViewportContainer.new();container.custom_minimum_size=Vector2(275,205);container.stretch=true;container.mouse_filter=Control.MOUSE_FILTER_IGNORE;detail.add_child(container)
	preview=SubViewport.new();preview.size=Vector2i(275,205);preview.own_world_3d=true;preview.transparent_bg=true;container.add_child(preview)
	preview_population=Population.new();preview.add_child(preview_population);preview_population.set_process(false)
	var actor: Dictionary=preview_population.figure(species,Vector3.ZERO,0.48,seller%5);preview_actor=actor.node
	var light := DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-30,0);light.light_energy=1.5;preview.add_child(light)
	var env := WorldEnvironment.new();env.environment=Environment.new();env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("d9e7e0");env.environment.ambient_light_energy=0.8;preview.add_child(env)
	view_camera=Camera3D.new();preview.add_child(view_camera);view_camera.position=Vector3(0,1.3,3);view_camera.look_at(Vector3(0,0.9,0));view_camera.fov=38
