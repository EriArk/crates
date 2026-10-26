# SPDX-License-Identifier: GPL-3.0-or-later
extends Node
const Rules = preload("cup_rules.gd")
const Store = preload("career_store.gd")
var game: Node3D
var store = Store.new()
var profile_key = "standalone"
var running = false
var stage = 0
var pending_result: Array=[]
var recorded = false
var garage_index = 0

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	store.load_profile(profile_key)
	game.net.bridge.profile_available.connect(_profile)
	game.net.bridge.identity_revoked.connect(_revoked)
	game.net.bridge.connected.connect(func():
		if game.state=="menu" and game.hud.menu_mode=="main": game.hud.menu("main"))
func _profile(id: String) -> void:
	var next="profile:"+id if not id.is_empty() else "standalone"
	if next==profile_key: return
	var was_cup=running
	running=false; pending_result.clear(); profile_key=next; store.load_profile(profile_key)
	if was_cup and not game.net.online: game.return_menu()
	if game.state=="menu": game.hud.menu("main")
func _revoked() -> void:
	if profile_key=="standalone": return
	running=false; pending_result.clear(); store.writable=false
	store.notice="Профиль изменился. Перезапустите игру из TrainerOS."
	if not game.net.online: game.return_menu()
func begin_new() -> void:
	store.begin(); game.hud.menu("cup")
func start_stage() -> void:
	if game.net.online or not store.writable: return
	if not pending_result.is_empty(): retry_save(); return
	if store.data.active.is_empty() and not store.begin(): game.hud.menu("cup"); return
	stage=store.data.active.results.size()
	if stage>=Rules.STAGES.size() or not Rules.STAGES[stage].available: game.hud.menu("cup"); return
	# A new stage must supply its actual track loader before becoming playable.
	if Rules.STAGES[stage].track!=game.net.Wire.TRACK: game.hud.menu("cup"); return
	running=true; recorded=false; game.bot_count=15; game.laps=Rules.STAGES[stage].laps
	game.conditions.configure(Rules.conditions(stage)); game.start_race()
func finish() -> void:
	if not running or game.net.online or recorded: return
	if not pending_result.is_empty(): return
	pending_result=game.cars.map(func(car): return {"slot":car.index,"ms":roundi(car.finish_time*1000) if car.finish_time>=0 else -1,"progress":car.passed})
	_save_result()
func _save_result() -> bool:
	if not store.finish(stage,pending_result): return false
	pending_result.clear(); recorded=true; return true
func retry_save() -> void:
	if not pending_result.is_empty(): _save_result()
	game.hud.menu("results")
func leave_stage() -> void:
	if not pending_result.is_empty(): game.hud.menu("results"); return
	game.return_menu(); game.hud.menu("cup")
func open_garage() -> void:
	garage_index=Rules.CARS.find(store.data.selected); game.hud.menu("garage")
func browse_car(step: int) -> void:
	garage_index=posmod(garage_index+step,Rules.CARS.size()); game.hud.menu("garage")
func select_car() -> void:
	store.select_car(Rules.CARS[garage_index]); game.hud.menu("garage")
func next_paint() -> void:
	store.select_paint((Store.PAINTS.find(store.data.paint)+1)%store.paint_count()); game.hud.menu("garage")
func status() -> String:
	if not store.notice.is_empty(): return store.notice
	if store.data.active.is_empty(): return "16 участников · состав сохраняется между этапами"
	var count=store.data.active.results.size()
	if count==4: return "Победа в кубке!" if Rules.won(store.data.active.results) else "Кубок завершён"
	if not Rules.STAGES[count].available: return "Зачёт сохранён. Следующая трасса готовится."
	return "Этап %d / 4 · можно продолжить после выхода" % (count+1)
func driver_title(slot: int) -> String:
	return "Вы" if slot==0 else game.Car.BotDriver.STYLES[slot%4]+" "+str(slot)
