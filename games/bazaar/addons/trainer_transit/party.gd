# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## Optional pose field in a regular lobby heartbeat. Older games ignore it.
## Only the host publishes a formation. A client can move only its admitted seat.
var bridge: Node
var match_node: Node
var roster: Array = []
var own := ""
var poses := {}
var clock := 0.0
var relay_until := 0
const WIRE := "egregore_v1"

func bind(session: Node) -> void:
	match_node=session
	bridge=session.bridge
	bridge.member_record.connect(receive)
	bridge.closed.connect(clear)

func clear() -> void:
	roster.clear()
	poses.clear()
	own=""
	relay_until=0

func admit() -> void:
	clear()
	for member in bridge.session.get("members",[]):roster.append(member.id)
	own=bridge.session.get("self","")

func receive(sender: String, message: Dictionary) -> void:
	if message.get("type")!="ping" or not message.has(WIRE) or sender not in roster:return
	var values=message[WIRE]
	if not values is Array:return
	var host:bool=bridge.session.get("host",false)
	if not host and sender!=bridge.session.get("hostMember"):return
	var count:=1 if host else roster.size()
	if values.size()!=2*count:return
	for n in values:
		if typeof(n) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(n)) or absf(n)>100 or n!=int(n):return
	for i in count:
		var id:String=sender if host else roster[i]
		if id!=own:poses[id]=Vector2(values[2*i],values[2*i+1])/100.0
	if host:relay_until=Time.get_ticks_msec()+800

func tick(delta: float, visible: bool, stick: Vector2) -> void:
	if own.is_empty():return
	var host:bool=bridge.session.get("host",false)
	if not visible and (not host or Time.get_ticks_msec()>relay_until):return
	poses[own]=stick if visible else Vector2.ZERO
	clock+=delta
	if clock<.125:return
	clock=0.0
	if bridge.records.size()>8 or bridge.pending.size()>16:return
	var packet:={"type":"ping","round":match_node.round_id}
	var values:=[]
	if host:
		for id in roster:
			var v:Vector2=poses.get(id,Vector2.ZERO)
			values.append(roundi(v.x*100))
			values.append(roundi(v.y*100))
	else:values=[roundi(stick.x*100),roundi(stick.y*100)]
	packet[WIRE]=values
	bridge.send(packet)
