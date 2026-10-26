# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Rules = preload("res://scripts/cup_rules.gd")
const Store = preload("res://scripts/career_store.gd")
var failures = 0
func check(ok: bool, label: String) -> void:
	if not ok: failures+=1; push_error(label)
func result(winner: int = 0) -> Array:
	var rows: Array=[]
	for i in 16: rows.append({"slot":i,"ms":100000+posmod(i-winner,16)*1000,"progress":1600})
	return rows
func _initialize() -> void:
	var a=result(); a[15].ms=-1
	var table=Rules.table([a,a,a,a])
	check(table[0].points2==225 and Rules.points(225)=="112,5","Final awards exactly 1.5x without floating drift")
	check(table[15].points2==0,"DNF earns no points")
	var tied=result(); tied[1].ms=tied[0].ms
	check(Rules.table([tied])[0].place==Rules.table([tied])[1].place,"Equal finish times share points and place")
	check(Rules.won([tied,tied,tied,tied],0) and Rules.won([tied,tied,tied,tied],1),"Exact cup tie shares victory")
	for row in tied: row.ms=-1
	check(not Rules.won([tied,tied,tied,tied]),"All-DNF cup awards no winner")
	check(not Rules.won([a]),"Single stage cannot award cup prize")
	check(not Rules.valid_result([a[0]]) and not Rules.valid_result(a.slice(0,15)+[a[0]]),"Partial and duplicate rosters rejected")
	var broken=result(); broken[0].ms=NAN; check(not Rules.valid_result(broken),"Nonfinite results rejected")
	var path="user://cup-tests/"+str(Time.get_ticks_usec())
	var store=Store.new(); store.load_profile("one",path)
	check(store.begin(),"New cup persists before first stage")
	var run_id=store.data.active.id
	check(store.finish(0,a) and not store.finish(0,a),"Each stage contributes once")
	check(store.data.wins==0 and not store.owned("vortex"),"First stage does not unlock reward")
	var loaded=Store.new(); loaded.load_profile("one",path)
	check(loaded.data.active.id==run_id and loaded.data.active.results.size()==1,"Restart resumes exact roster and score")
	for i in range(1,4): check(loaded.finish(i,a),"Prepared scoring supports all four stage contracts")
	check(loaded.data.wins==1 and loaded.owned("vortex") and not loaded.finish(3,a),"Final win and car unlock commit once")
	check(loaded.select_car("vortex"),"Unlocked prize is selectable")
	check(loaded.begin(),"New cup keeps earned garage")
	for i in 4: check(loaded.finish(i,a),"Repeat cup fixture")
	check(loaded.data.wins==2 and loaded.paint_count()==2 and loaded.select_paint(1),"Repeat victory unlocks cosmetic paint")
	var other=Store.new(); other.load_profile("two",path)
	check(other.data.wins==0 and not other.owned("vortex"),"Local profiles do not share career rewards")
	var before=loaded.data.duplicate(true); var generation=loaded.generation
	loaded.fault="write"; check(not loaded.begin() and loaded.data==before and loaded.generation==generation,"Failed write cannot advance live career")
	loaded.fault="rename"; check(not loaded.begin() and loaded.data==before,"Failed rename cannot grant progress")
	var recovered=Store.new(); recovered.load_profile("one",path)
	check(recovered.data==JSON.parse_string(JSON.stringify(before)) and recovered.generation==generation,"Pending save is not promoted after interrupted write")
	var newest=loaded.base_path+"."+str(generation%2)+".json"
	var file=FileAccess.open(newest,FileAccess.WRITE); file.store_string("broken"); file.close()
	recovered.load_profile("one",path)
	check(recovered.writable and recovered.generation==generation-1 and not recovered.notice.is_empty(),"Corrupt latest save recovers previous checkpoint")
	file=FileAccess.open(loaded.base_path+"."+str((generation+1)%2)+".json",FileAccess.WRITE); file.store_string("broken"); file.close()
	recovered.load_profile("one",path)
	check(not recovered.writable and not recovered.begin(),"Two corrupt slots remain untouched")
	file=FileAccess.open(newest,FileAccess.WRITE); file.store_string('{"schema":2}'); file.close()
	recovered.load_profile("one",path)
	check(not recovered.writable,"Future save version is never overwritten")
	print("CUP TEST failures=",failures); quit(1 if failures else 0)
