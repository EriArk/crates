# SPDX-License-Identifier: GPL-3.0-or-later
extends Node
## Game orchestration only. Host owns credentials; Backend owns decisions/tables.
const RULESET := "pocket-golf.island.analog5.v1"
const JOURNAL := "user://scorecard-journal.json"
signal changed
signal prepared(match_key: String)
var bridge
var player := ""
var opened := false
var busy := false
var generation := 0
var waiting := Callable()
var match_id := ""
var side_order: Array = []
var expected: Dictionary = {}
var message := "Local round · outside the shared tables"
var decision := ""
var submitted := false
var poll_at := 0
var poll_until := 0
var journal_path := JOURNAL
var board: Dictionary = {}
var board_message := ""

func bind(client) -> void:
	bridge=client
	bridge.connected.connect(func():
		if waiting.is_valid():
			var callback := waiting; waiting=Callable(); _authorize(callback))
	bridge.closed.connect(reset)
	bridge.identity_revoked.connect(reset)

func reset() -> void:
	generation+=1; waiting=Callable(); busy=false; opened=false; player=""
	match_id=""; decision=""; submitted=false; poll_at=0; expected.clear()
	message="Round not recorded"; board={}; board_message="Sign in through TrainerOS to view shared tables."
	changed.emit()

func new_round(roster: Array, host_seat: int) -> void:
	generation+=1; busy=false; waiting=Callable(); match_id=""; expected.clear()
	decision=""; submitted=false; poll_at=0
	side_order=[]
	for side in roster.size():
		if roster[side].any(func(member): return int(member)==host_seat): side_order.append(side)
	for side in roster.size():
		if not side_order.has(side): side_order.append(side)
	message="Connecting shared results…"; changed.emit()

func _rpc(method: String, params: Dictionary, callback: Callable) -> void:
	var current := generation
	var done := func(result: Dictionary, error: String):
		if current==generation:
			if error in ["unauthenticated","grant_expired","play_not_open","sign_in_required"]: opened=false
			callback.call(result,error)
	if not bridge.request(method,params,done): done.call({},"unavailable")

func _ensure(callback: Callable) -> void:
	if busy: callback.call({},"busy"); return
	busy=true
	if not bridge.registered:
		waiting=callback
		bridge.connect_host()
		# Synchronous discovery failure has no pending SDK callback.
		if not bridge.active:
			waiting=Callable(); busy=false; callback.call({},"unavailable")
	else: _authorize(callback)

func _authorize(callback: Callable) -> void:
	if bridge.capabilities.get("play.scorecards")!=1:
		callback.call({},"unsupported"); return
	_rpc("account.get",{},func(result,error):
		var account: Dictionary = result.get("account",{})
		if not error.is_empty() or account.get("state")!="signed_in" or not uuid_valid(account.get("player_id")):
			callback.call({},"sign_in_required"); return
		if player!=account.player_id: opened=false
		player=account.player_id
		if opened: callback.call({},""); return
		_rpc("play.open",{"ruleset_id":RULESET},func(value,problem):
			opened=problem.is_empty() and value.get("ruleset",{}).get("id")==RULESET
			callback.call(value,problem if not problem.is_empty() else "" if opened else "wrong_rules")))

static func uuid_valid(value) -> bool:
	if not value is String or value.length()!=36: return false
	for i in value.length():
		if i in [8,13,18,23]:
			if value[i]!="-": return false
		elif not value[i] in "0123456789abcdef": return false
	return true

static func operation_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6]=(bytes[6]&15)|64; bytes[8]=(bytes[8]&63)|128
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s"%[hex.substr(0,8),hex.substr(8,4),hex.substr(12,4),hex.substr(16,4),hex.substr(20,12)]

func _journal() -> Array:
	if not FileAccess.file_exists(journal_path): return []
	var file := FileAccess.open(journal_path,FileAccess.READ)
	if file==null or file.get_length()>262144: return [{"invalid":true}]
	var data = JSON.parse_string(file.get_as_text())
	return data if data is Array else [{"invalid":true}]

func _save(entries: Array) -> bool:
	var file := FileAccess.open(journal_path+".tmp",FileAccess.WRITE)
	if file==null: return false
	file.store_string(JSON.stringify(entries)); file.flush()
	var ok := file.get_error()==OK; file.close()
	return ok and DirAccess.rename_absolute(journal_path+".tmp",journal_path)==OK

func _command(action: String, payload: Dictionary, callback: Callable, operation: String = "") -> void:
	if operation.is_empty():
		operation=operation_id()
		var entries := _journal()
		if entries.any(func(entry): return not entry is Dictionary or entry.has("invalid")):
			callback.call({},"journal_unavailable"); return
		# Never evict an unresolved scorecard to make room for a newer result.
		while entries.size()>=128:
			var removable := -1
			for i in entries.size():
				if entries[i].get("action")!="submit" or entries[i].has("decision"): removable=i; break
			if removable<0: callback.call({},"journal_full"); return
			entries.remove_at(removable)
		entries.append({"player":player,"ruleset":RULESET,"operation_id":operation,"action":action,"payload":payload})
		if not _save(entries): callback.call({},"journal_unavailable"); return
	_rpc("play."+action,{"operation_id":operation,"payload":payload},callback)

func _read_match(callback: Callable) -> void:
	_rpc("play.get",{"operation_id":operation_id(),"payload":{"match_id":match_id}},callback)

func create_round(roster: Array, callback: Callable) -> void:
	_ensure(func(_value,error):
		if not error.is_empty(): busy=false; callback.call({},error); return
		var seats: Array = side_order.map(func(side): return roster[side].size())
		_command("create",{"mode":"individual" if seats.max()==1 else "teams","seats":seats},func(result,problem):
			busy=false
			if problem.is_empty(): match_id=result.get("match",{}).get("id","")
			callback.call(result,problem)))

func join_round(key: String, roster: Array, seat: int, callback: Callable) -> void:
	_ensure(func(_value,error):
		if not error.is_empty(): busy=false; callback.call({},error); return
		var side := -1
		for i in side_order.size():
			if roster[side_order[i]].any(func(member): return int(member)==seat): side=i
		_command("join",{"match_id":key,"side":side},func(result,problem):
			busy=false
			var row: Dictionary = result.get("match",{})
			var seats: Array = side_order.map(func(index): return roster[index].size())
			var admitted: Array = row.get("seats",[]).map(func(value): return int(value))
			if problem.is_empty() and admitted==seats and row.get("state")=="waiting" and row.get("ruleset_id")==RULESET:
				match_id=key
			else:
				problem=problem if not problem.is_empty() else "wrong_roster"
			callback.call(result,problem)))

func start_round(roster: Array, identities: Dictionary, callback: Callable) -> void:
	busy=true
	_read_match(func(row,error):
		var wanted: Dictionary = {}
		for side in side_order.size():
			for seat in roster[side_order[side]]:
				var id: String = identities.get(int(seat),"")
				if not uuid_valid(id) or wanted.has(id): busy=false; callback.call({},"duplicate_identity"); return
				wanted[id]=side
		var actual: Dictionary = {}
		for person in row.get("participants",[]): actual[person.player_id]=int(person.side)
		if not error.is_empty() or wanted!=actual: busy=false; callback.call({},"wrong_roster"); return
		_command("start",{"match_id":match_id},func(result,problem): busy=false; callback.call(result,problem)))

func activate(key: String) -> void:
	if key.is_empty() or key!=match_id:
		generation+=1; busy=false; waiting=Callable()
		match_id=""; message="Casual round · outside the shared tables"
	else: message="Shared result · every player confirms the score"
	changed.emit()

func cancel_waiting() -> void:
	if not busy and opened and not match_id.is_empty():
		_command("cancel",{"match_id":match_id},func(_result,_error): pass)

func finish(scores: Array) -> void:
	if submitted or match_id.is_empty(): return
	submitted=true; busy=true; message="Sending your scorecard…"; changed.emit()
	var values: Array = []
	for side in side_order.size(): values.append({"side":side,"values":scores[side_order[side]].duplicate()})
	_command("submit",{"match_id":match_id,"scores":values},_submitted)

func _submitted(_result: Dictionary, error: String) -> void:
	busy=false
	if error.is_empty() or error in ["match_closed","match_expired"]:
		message="Waiting for every player's confirmation…"
		poll_at=Time.get_ticks_msec()+500; poll_until=Time.get_ticks_msec()+60000
	else: message="Result pending · open Shared tables to retry"
	changed.emit()

func _process(_delta: float) -> void:
	if busy or poll_at==0 or Time.get_ticks_msec()<poll_at: return
	poll_at=0; busy=true
	_read_match(func(result,error):
		busy=false
		if not error.is_empty(): message="Result pending · open Shared tables to retry"
		else:
			decision=result.get("state","")
			if decision=="confirmed": message="Confirmed by all players · added to shared tables"
			elif decision=="disputed": message="Scores disagree · excluded from shared tables"
			elif decision in ["voided","cancelled","rejected"] or result.get("expired",false): message="Result not counted"
			else:
				message="Waiting for every player's confirmation…"
				if Time.get_ticks_msec()<poll_until: poll_at=Time.get_ticks_msec()+3000
			if decision in ["confirmed","disputed","voided","cancelled","rejected"] or result.get("expired",false):
				var entries := _journal()
				for entry in entries:
					if entry.get("player")==player and entry.get("payload",{}).get("match_id")==match_id: entry["decision"]=decision
				_save(entries)
		if board_message=="Checking your pending result…": board_message=message
		changed.emit())

func retry_result() -> void:
	_ensure(func(_result,error):
		if not error.is_empty(): busy=false; board_message="Sign in through TrainerOS, then try again."; changed.emit(); return
		var entries := _journal(); entries.reverse()
		for entry in entries:
			if entry.get("player")==player and entry.get("ruleset")==RULESET and entry.get("action")=="submit" and not entry.has("decision"):
				var payload: Dictionary = entry.payload.duplicate(true)
				for side in payload.scores:
					side.side=int(side.side); side.values=side.values.map(func(v): return int(v))
				match_id=payload.match_id
				_command("submit",payload,_submitted,entry.operation_id)
				board_message="Checking your pending result…"; changed.emit(); return
		busy=false; board_message="No pending scorecard for this account."; changed.emit())

func fetch_board(mode: String, kind: String, offset: int = 0, revision: String = "") -> void:
	if busy: return
	board={}; board_message="Loading shared table…"; changed.emit()
	_ensure(func(_result,error):
		if not error.is_empty():
			busy=false; board={}; board_message="Sign in through TrainerOS to view shared tables." if error=="sign_in_required" else "Shared tables unavailable. Try again shortly."
			changed.emit(); return
		var params := {"mode":mode,"kind":kind,"limit":5,"offset":offset}
		if not revision.is_empty(): params["revision"]=revision
		_rpc("play.board",params,func(result,problem):
			busy=false
			if problem=="stale_revision": fetch_board(mode,kind); return
			board=result if problem.is_empty() else {}
			board_message="Confirmed by every participant" if problem.is_empty() else "Shared tables unavailable. Try again shortly."
			changed.emit()))
