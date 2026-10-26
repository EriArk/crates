# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
# Stage-owned data. A future host transmits this exact payload before Ready;
# clients must not choose weather independently or change grip through quality settings.
const VERSION = 2
const TIMES = ["day", "sunset", "night", "dawn"]
const WEATHERS = ["clear", "overcast", "rain"]
var time_of_day = "day"
var weather = "clear"
var seed_value = 38021
var timeline: Array = []

func configure(data: Dictionary) -> bool:
	var version = data.get("version")
	if not (version is int or version is float) or (version!=1 and version!=VERSION): return false
	if data.get("time") not in TIMES or data.get("weather") not in WEATHERS: return false
	if data.version==1 and data.time not in ["day","sunset"]: return false
	var seed_input = data.get("seed")
	if not (seed_input is int or seed_input is float): return false
	if not is_finite(float(seed_input)) or float(seed_input)!=floorf(float(seed_input)) or seed_input<0 or seed_input>2147483647: return false
	var events = data.get("timeline",[])
	if not events is Array or events.size()>8 or (data.version==1 and not events.is_empty()): return false
	var normalized: Array = []; var previous = 0.0
	for event in events:
		if not event is Dictionary or event.get("time") not in TIMES or event.get("weather") not in WEATHERS: return false
		var at = event.get("at")
		if not (at is int or at is float) or not is_finite(float(at)): return false
		if at<previous+30.0 or at>7200.0: return false
		normalized.append({"at":float(at),"time":event.time,"weather":event.weather}); previous=float(at)
	time_of_day=data.time; weather=data.weather; seed_value=int(seed_input); timeline=normalized
	return true

func descriptor() -> Dictionary:
	return {"version":VERSION,"time":time_of_day,"weather":weather,"seed":seed_value,"timeline":timeline.duplicate(true)}

func sample(seconds: float = 0.0) -> Dictionary:
	var before = {"at":0.0,"time":time_of_day,"weather":weather}
	var safe_time = maxf(0,seconds) if is_finite(seconds) else 0.0
	for after in timeline:
		if safe_time<after.at:
			var blend = smoothstep(0.0,1.0,(safe_time-before.at)/(after.at-before.at))
			return {"from":before,"to":after,"blend":blend}
		before=after
	return {"from":before,"to":before,"blend":0.0}

func wetness(seconds: float = 0.0) -> float:
	var s = sample(seconds)
	return lerpf(0.8 if s.from.weather=="rain" else 0.0,0.8 if s.to.weather=="rain" else 0.0,s.blend)
func grip(seconds: float = 0.0) -> float: return 1.0-wetness(seconds)*0.2
func record_key() -> String:
	var legacy = timeline.is_empty() and time_of_day in ["day","sunset"]
	var key = ("valley.v1/" if legacy else "valley.v2/")+time_of_day+"/"+weather
	if not timeline.is_empty(): key+="/flow-"+JSON.stringify(timeline).sha256_text().substr(0,16)
	return key
func time_title() -> String: return {"day":"День","sunset":"Закат","night":"Ночь","dawn":"Рассвет"}[time_of_day]
func weather_title() -> String: return {"clear":"Ясно","overcast":"Облачно","rain":"Дождь"}[weather]
func title() -> String: return time_title()+" · "+weather_title()

func scenario_title() -> String:
	if timeline.is_empty(): return "Без изменений"
	if timeline[-1].time=="night" and timeline[-1].weather=="rain": return "К ночи и дождю"
	return "Прояснение" if timeline.size()==1 and timeline[0].weather=="clear" else "По сценарию"

func next_scenario() -> Dictionary:
	var data = descriptor()
	if timeline.is_empty():
		data.timeline=[{"at":120.0,"time":"night" if time_of_day=="night" else "sunset","weather":"overcast"},{"at":300.0,"time":"night","weather":"rain"}]
	elif timeline[-1].weather=="rain":
		data.timeline=[{"at":180.0,"time":time_of_day,"weather":"clear"}]
	else: data.timeline=[]
	return data

func live_title(seconds: float) -> String:
	var s = sample(seconds)
	var current: Dictionary=s.to if s.blend>=0.5 else s.from
	var text = {"day":"День","sunset":"Закат","night":"Ночь","dawn":"Рассвет"}[current.time]+" · "+{"clear":"Ясно","overcast":"Облачно","rain":"Дождь"}[current.weather]
	return text+(" ↗" if s.from.time!=s.to.time or s.from.weather!=s.to.weather else "")
