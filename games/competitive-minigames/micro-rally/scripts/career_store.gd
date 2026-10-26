# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
const Rules = preload("cup_rules.gd")
const PAINTS = ["standard","gold","forest","violet"]
const COLORS = [Color("ff8a28"),Color("e8bd45"),Color("45a478"),Color("aa79dd")]
var data = fresh()
var base_path = ""
var generation = 0
var writable = true
var notice = ""
var fault = "" # Test-only I/O failure injection; no gameplay setting.
static func fresh() -> Dictionary: return {"selected":"swift","paint":"standard","wins":0,"active":{}}
static func decode(text: String):
	var parser=JSON.new()
	return parser.data if parser.parse(text)==OK else null
func owned(id: String) -> bool: return id in Rules.CARS.slice(0,3) or (id=="vortex" and data.wins>0)
func paint_count() -> int: return mini(4,maxi(1,int(data.wins)))
func load_profile(owner: String, directory: String = "user://career") -> void:
	data=fresh(); generation=0; writable=true; notice=""
	base_path=directory+"/"+(owner if not owner.is_empty() else "standalone").sha256_text().substr(0,32)
	var exists = false; var damaged = false
	for slot in 2:
		var path=base_path+"."+str(slot)+".json"
		if not FileAccess.file_exists(path): continue
		exists=true
		var file=FileAccess.open(path,FileAccess.READ)
		if file==null or file.get_length()>262144: damaged=true; continue
		var envelope=decode(file.get_as_text())
		if envelope is Dictionary and envelope.get("schema")!=1:
			writable=false; notice="Сохранение создано другой версией игры."; return
		if not envelope is Dictionary or not Rules.whole(envelope.get("generation"),1,2147483647) or not envelope.get("payload") is String:
			damaged=true; continue
		if envelope.get("sha256")!=envelope.payload.sha256_text(): damaged=true; continue
		var candidate=decode(envelope.payload)
		if candidate is Dictionary and candidate.get("active") is Dictionary and not candidate.active.is_empty() and candidate.active.get("version")!=Rules.VERSION:
			writable=false; notice="Кубок создан другой версией игры. Сохранение не изменено."; return
		if not valid(candidate): damaged=true; continue
		if envelope.generation>generation: data=candidate; generation=int(envelope.generation)
	if exists and generation==0:
		writable=false; notice="Сохранение повреждено. Исходные файлы сохранены."; return
	if damaged: notice="Прогресс восстановлен из резервной записи."
static func valid(value) -> bool:
	if not value is Dictionary or value.get("selected") not in Rules.CARS or value.get("paint") not in PAINTS or not Rules.whole(value.get("wins"),0,1000000): return false
	if value.selected=="vortex" and value.wins<1: return false
	if PAINTS.find(value.paint)>=mini(4,maxi(1,int(value.wins))): return false
	var run=value.get("active")
	if not run is Dictionary: return false
	if run.is_empty(): return true
	if run.get("cup")!=Rules.ID or run.get("version")!=Rules.VERSION or not run.get("id") is String or run.id.length()!=32: return false
	if not run.get("roster") is Array or run.roster.size()!=16 or not run.get("results") is Array or run.results.size()>4 or not run.get("settled") is bool: return false
	for car in run.roster:
		if car not in Rules.CARS: return false
	for result in run.results:
		if not Rules.valid_result(result): return false
	return run.settled==(run.results.size()==4)
func commit(next: Dictionary) -> bool:
	if not writable or not valid(next) or base_path.is_empty(): return false
	var path=base_path+"."+str((generation+1)%2)+".json"
	if fault=="write" or DirAccess.make_dir_recursive_absolute(base_path.get_base_dir())!=OK:
		notice="Не удалось сохранить прогресс. Повторите попытку."; return false
	var payload=JSON.stringify(next)
	var file=FileAccess.open(path+".pending",FileAccess.WRITE)
	if file==null: notice="Нет доступа к сохранению. Повторите попытку."; return false
	file.store_string(JSON.stringify({"schema":1,"generation":generation+1,"payload":payload,"sha256":payload.sha256_text()})); file.flush()
	var error=file.get_error(); file.close()
	if error!=OK or fault=="rename" or DirAccess.rename_absolute(path+".pending",path)!=OK:
		notice="Не удалось завершить сохранение. Повторите попытку."; return false
	data=next.duplicate(true); generation+=1; notice=""; return true
func begin() -> bool:
	var next=data.duplicate(true); var roster: Array=[data.selected]
	for i in range(1,16): roster.append(["swift","trail","comet","vortex"][i%4])
	next.active={"id":Crypto.new().generate_random_bytes(16).hex_encode(),"cup":Rules.ID,"version":Rules.VERSION,"roster":roster,"results":[],"settled":false}
	return commit(next)
func finish(stage: int, rows: Array) -> bool:
	if data.active.is_empty() or stage!=data.active.results.size() or stage>=Rules.STAGES.size() or not Rules.valid_result(rows): return false
	var next=data.duplicate(true); next.active.results.append(rows.duplicate(true))
	if next.active.results.size()==4:
		next.active.settled=true
		if Rules.won(next.active.results): next.wins+=1
	return commit(next)
func select_car(id: String) -> bool:
	if not owned(id): return false
	var next=data.duplicate(true); next.selected=id; return commit(next)
func select_paint(index: int) -> bool:
	if index<0 or index>=paint_count(): return false
	var next=data.duplicate(true); next.paint=PAINTS[index]; return commit(next)
func color() -> Color: return COLORS[PAINTS.find(data.paint)]
