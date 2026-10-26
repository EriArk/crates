# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
# Stage-owned data. A future host transmits this exact payload before Ready;
# clients must not choose weather independently or change grip through quality settings.
const VERSION = 1
const TIMES = ["day", "sunset"]
const WEATHERS = ["clear", "overcast", "rain"]
var time_of_day = "day"
var weather = "clear"
var seed_value = 38021

func configure(data: Dictionary) -> bool:
	if data.get("version")!=VERSION or data.get("time") not in TIMES or data.get("weather") not in WEATHERS: return false
	var seed_input = data.get("seed")
	if not (seed_input is int or seed_input is float): return false
	if not is_finite(float(seed_input)) or float(seed_input)!=floorf(float(seed_input)) or seed_input<0 or seed_input>2147483647: return false
	time_of_day=data.time; weather=data.weather; seed_value=int(seed_input)
	return true

func descriptor() -> Dictionary:
	return {"version":VERSION,"time":time_of_day,"weather":weather,"seed":seed_value}

func wetness() -> float: return 0.8 if weather=="rain" else 0.0
func grip() -> float: return 0.84 if weather=="rain" else 1.0
func record_key() -> String: return "valley.v1/"+time_of_day+"/"+weather
func time_title() -> String: return "День" if time_of_day=="day" else "Закат"
func weather_title() -> String: return {"clear":"Ясно","overcast":"Облачно","rain":"Дождь"}[weather]
func title() -> String: return time_title()+" · "+weather_title()
