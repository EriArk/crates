# SPDX-License-Identifier: GPL-3.0-or-later
extends "services_client.gd"

signal changed
signal recorded(game: String, value: Dictionary)
var game := ""
var offer := {}
var message := ""
var needs_refresh := false

func _init() -> void:
	super()
	app_id="org.traineros.bazaar.tickets"

func _ready() -> void:
	connected.connect(refresh)
	unavailable.connect(func(reason):
		offer={}
		message=reason
		changed.emit())
	snapshot.connect(_received)
	read_failed.connect(_failed)

func select(value: String) -> void:
	game=value
	offer={}
	message=""
	if game.is_empty():return
	if not active:connect_host()
	elif ready_for_reads:refresh()
	changed.emit()

func refresh() -> void:
	if game.is_empty():return
	if not has_festival or not has_checkout:
		message="Festival tickets need an updated TrainerOS host."
	elif not read("bazaar.festival",{"game":game}):
		needs_refresh=true
	changed.emit()

func _received(method: String, value: Dictionary) -> void:
	if game.is_empty():return
	if method=="bazaar.checkout" or value.get("game")!=game or needs_refresh:
		needs_refresh=false
		refresh()
		return
	offer=value
	if method=="bazaar.festival.attempt":recorded.emit(game,value)
	changed.emit()

func _failed(method: String, reason: String) -> void:
	message={"insufficient_sparks":"Not enough Sparks for this ticket.","review_cancelled":"Purchase cancelled.","market_closed":"Ticket sales are closed.","sign_in_required":"Sign in to use your Sparks."}.get(reason,reason.replace("_"," ").capitalize())
	offer={}
	if method!="bazaar.festival" or needs_refresh:
		needs_refresh=false
		refresh()
	changed.emit()

func ticket() -> Dictionary:
	var item=offer.get("round")
	return item if item is Dictionary else {}

func playable() -> bool:
	return not ticket().is_empty() and not ticket().complete and pending.is_empty() and ready_for_reads

func buy() -> void:
	if offer.is_empty() or not pending.is_empty():return
	message=""
	if offer.get("checkout_pending",false):checkout({"action":"resolve"})
	elif offer.get("payments_available",false):checkout({"action":"festival","game":game,"price":offer.price})
	changed.emit()

func submit(p: Vector2) -> bool:
	if not playable():return false
	var sent:=read("bazaar.festival.attempt",{"game":game,"ticket":ticket().id,"index":ticket().attempts.size(),"x":roundi(p.x*100),"y":roundi(p.y*100)})
	if sent:message="";changed.emit()
	return sent
