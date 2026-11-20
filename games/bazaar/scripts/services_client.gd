# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://addons/traineros/avatar_client.gd"
## Reuse the SDK's bounded transport; checkout opens the host-owned review.
signal snapshot(method: String, value: Dictionary)
signal read_failed(method: String, reason: String)
signal connected
var has_checkout := false
var ready_for_reads := false

func _init() -> void:
	app_id="org.traineros.bazaar.services"
	if "--test-market" in OS.get_cmdline_user_args():
		endpoint_override=OS.get_environment("TRAINEROS_TEST_MARKET_ENDPOINT")
		if endpoint_override.is_empty():endpoint_override="user://market-lab/sdk/endpoint.json"
func disconnect_host() -> void:
	has_checkout=false
	ready_for_reads=false
	super.disconnect_host()
func checkout(args: Dictionary) -> bool:
	if not has_checkout or not ready_for_reads or not pending.is_empty():return false
	_request("bazaar.checkout",args)
	pending[str(serial)].deadline=Time.get_ticks_msec()+180000
	return true

func read(method: String, args: Dictionary={}) -> bool:
	if not ready_for_reads or not pending.is_empty():return false
	if method not in ["bazaar.world","bazaar.sellers","bazaar.costumes","bazaar.listings","bazaar.own_listings"]:return false
	_request(method,args);pending[str(serial)].deadline=Time.get_ticks_msec()+20000;return true
func _packet(packet: Dictionary) -> void:
	if packet.has("event"):
		if packet.event in ["host.stopping","context.revoked"]:_fail("TrainerOS account changed. Reconnect to refresh services.")
		return
	var id: String=packet.get("id","")
	if not pending.has(id):_fail("Unexpected service response");return
	var method: String=pending[id].method;pending.erase(id)
	if packet.has("error"):
		if method=="hello":_fail(str(packet.error.get("code","backend_unavailable")));return
		read_failed.emit(method,str(packet.error.get("code","backend_unavailable")));return
	var result=packet.get("result")
	if not result is Dictionary:_fail("Invalid service response");return
	if method=="hello":
		if result.get("capabilities",{}).get("bazaar.read")!=1:_fail("This TrainerOS build has no Bazaar services yet.");return
		has_checkout=result.get("capabilities",{}).get("bazaar.checkout")==1
		profile_id=result.get("context",{}).get("profile","")
		if profile_id.is_empty():_fail("Choose a TrainerOS profile first.");return
		ready_for_reads=true;connected.emit()
	else:snapshot.emit(method,result)
