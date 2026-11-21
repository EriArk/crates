# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
const Settings = preload("bot_settings.gd")
static func locked(hud) -> bool:
	return hud.bots_parent=="cup" and not hud.game.cup.store.data.active.is_empty()
static func value(hud) -> Dictionary:
	return hud.game.cup.store.active_bots() if locked(hud) else hud.game.cup.store.bot_settings("quick" if hud.bots_parent=="quick" else "cup")
static func open(hud, parent: String) -> void:
	hud.bots_parent=parent; hud.bot_notice=""; hud.bot_axis_direction=0; hud.menu("bots")
static func option(hud, list: VBoxContainer, text: String, action: Callable) -> void:
	var button=hud.button(list,text,func(): action.call(1))
	button.gui_input.connect(func(event):
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			button.accept_event()
			var direction=-1 if event.is_action_pressed("ui_left") else 1
			if event is InputEventJoypadMotion:
				if hud.bot_axis_direction==direction: return
				hud.bot_axis_direction=direction
			hud.game.sound.play_event("ui"); action.call(direction))
static func change(hud, field: String, direction: int = 1) -> void:
	if locked(hud) or hud.game.state!="menu" or hud.game.net.online or not hud.game.cup.store.writable: return
	var settings=value(hud)
	var store=hud.game.cup.store
	var ok=false
	if field=="count":
		ok=store.set_bot_count(posmod(hud.game.bot_count+direction,16))
		if ok: hud.game.bot_count=store.quick_bot_count()
	else:
		if field=="preset": settings=Settings.preset(posmod(Settings.level(settings)+direction,3))
		elif field=="style": settings.style=Settings.STYLES[posmod(Settings.STYLES.find(settings.style)+direction,Settings.STYLES.size())]
		elif field in Settings.AXES: settings[field]=posmod(int(settings[field])+direction,3)
		else: return
		ok=store.set_bot_settings("quick" if hud.bots_parent=="quick" else "cup",settings)
	hud.bot_notice="" if ok else store.notice
	hud.menu("bots")
static func build(hud, list: VBoxContainer) -> void:
	var settings=value(hud); var readonly=locked(hud) or not hud.game.cup.store.writable
	list.add_child(hud.label("OPPONENTS",30,hud.GOLD))
	list.add_child(hud.label("Whole cup · 15 opponents" if hud.bots_parent!="quick" else "Single events · host's bots online",18))
	if readonly:
		list.add_child(hud.label("Difficulty: "+Settings.title(settings),22,hud.GOLD))
		for field in Settings.AXES: list.add_child(hud.label(Settings.LABELS[field]+": "+Settings.VALUES[field][int(settings[field])],22))
		list.add_child(hud.label(Settings.STYLE_TITLES[Settings.STYLES.find(settings.style)],22))
		list.add_child(hud.label("Settings are locked for the whole cup.\nStart a new cup to change them." if locked(hud) else hud.game.cup.store.notice,18))
	else:
		option(hud,list,"Difficulty: "+Settings.title(settings),func(step): change(hud,"preset",step))
		if hud.bots_parent=="quick": option(hud,list,"Solo opponents: "+str(hud.game.bot_count),func(step): change(hud,"count",step))
		for field in Settings.AXES: option(hud,list,Settings.LABELS[field]+": "+Settings.VALUES[field][int(settings[field])],func(step): change(hud,field,step))
		option(hud,list,"Driving style: "+Settings.STYLE_TITLES[Settings.STYLES.find(settings.style)],func(step): change(hud,"style",step))
		list.add_child(hud.label("← / → or press · changes saved automatically",17))
	if not hud.bot_notice.is_empty(): list.add_child(hud.label(hud.bot_notice,17,hud.GOLD))
	hud.button(list,"Back",func(): hud.menu(hud.bots_parent))
