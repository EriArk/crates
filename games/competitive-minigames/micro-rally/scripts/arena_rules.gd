# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
const DURATION=480.0
var rows: Array=[]
var ledger: Array=[]
var death_time: Array=[]
var feed=""
var feed_time=0.0
func reset(count: int) -> void:
	rows.clear(); ledger.clear(); death_time.clear(); feed=""; feed_time=0
	for i in count:
		rows.append({"slot":i,"score":0,"kills":0,"assists":0,"deaths":0,"life":0})
		ledger.append([]); death_time.append(-1.0)
func damage(victim: int, attacker: int, amount: float, now: float) -> void:
	if victim<0 or victim>=rows.size() or amount<=0 or death_time[victim]>=0: return
	ledger[victim].append({"source":attacker,"amount":amount,"at":now})
	ledger[victim]=ledger[victim].filter(func(e): return now-e.at<=8)
func repair(victim: int, amount: float) -> void:
	for hit in ledger[victim]:
		var restored=minf(amount,hit.amount); hit.amount-=restored; amount-=restored
		if amount<=0: break
func wreck(victim: int, now: float) -> bool:
	if death_time[victim]>=0: return false
	death_time[victim]=now; rows[victim].deaths+=1
	var killer=-1; var totals={}
	for hit in ledger[victim]:
		if now-hit.at>8 or hit.amount<=0: continue
		if hit.source>=0 and hit.source!=victim:
			killer=hit.source; totals[killer]=totals.get(killer,0.0)+hit.amount
	if killer>=0:
		rows[killer].score+=3; rows[killer].kills+=1
		var assistant=-1; var best=29.999
		for source in totals:
			if source!=killer and totals[source]>best: best=totals[source]; assistant=source
		if assistant>=0: rows[assistant].score+=1; rows[assistant].assists+=1
	else: rows[victim].score-=1
	feed=("CAR %d  >  CAR %d" % [killer+1,victim+1]) if killer>=0 else "CAR %d WRECKED" % (victim+1)
	feed_time=now+3.5
	return true
func revived(slot: int) -> void:
	rows[slot].life+=1; death_time[slot]=-1.0; ledger[slot].clear()
static func better(a: Dictionary,b: Dictionary) -> bool:
	if a.score!=b.score: return a.score>b.score
	if a.kills!=b.kills: return a.kills>b.kills
	return a.deaths<b.deaths
func ranked() -> Array:
	var result=rows.duplicate(true)
	result.sort_custom(func(a,b): return better(a,b) if better(a,b) or better(b,a) else a.slot<b.slot)
	for i in result.size(): result[i].place=i+1 if i==0 or better(result[i-1],result[i]) else result[i-1].place
	return result
func place(slot: int) -> int:
	for row in ranked():
		if row.slot==slot: return row.place
	return 0
