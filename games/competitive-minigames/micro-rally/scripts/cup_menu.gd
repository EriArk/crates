# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
const Rules = preload("cup_rules.gd")
const Preview = preload("garage_preview.gd")
static func build(hud, list: VBoxContainer, mode: String) -> void:
	var flow=hud.game.cup; var store=flow.store; var active: Dictionary=store.data.active
	if mode=="cup":
		list.add_child(hud.label(Rules.TITLE.to_upper(),40,hud.GOLD))
		var completed: int=0 if active.is_empty() else active.results.size()
		var columns=HBoxContainer.new(); columns.add_theme_constant_override("separation",26); list.add_child(columns)
		var actions=VBoxContainer.new(); actions.add_theme_constant_override("separation",8); actions.custom_minimum_size.x=360; columns.add_child(actions)
		var stages=VBoxContainer.new(); stages.add_theme_constant_override("separation",10); stages.size_flags_horizontal=Control.SIZE_EXPAND_FILL; columns.add_child(stages)
		for i in Rules.STAGES.size():
			var stage: Dictionary=Rules.STAGES[i]
			var suffix="ПРОЙДЕН" if i<completed else "ГОТОВИТСЯ" if not stage.available else "СЛЕДУЮЩИЙ" if i==completed else "ДАЛЕЕ"
			var tile=PanelContainer.new(); tile.add_theme_stylebox_override("panel",hud.MenuSkin.plate(Color("343b35") if i==completed else Color("182121"),16,i==completed)); stages.add_child(tile)
			var lines=VBoxContainer.new(); tile.add_child(lines)
			lines.add_child(hud.label("%02d  %s" % [i+1,stage.title],20,hud.GOLD if i==completed else hud.PAPER))
			lines.add_child(hud.label("ГОНКИ / %s / %s" % [stage.target,suffix],15,Color("c3cabc")))
		var status=hud.label(flow.status(),22,hud.GOLD); status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; status.custom_minimum_size.x=340; actions.add_child(status)
		actions.add_child(hud.label("ПРИЗ: VORTEX\nЗатем — новые окраски\nФинал: очки ×1,5",20))
		if completed<Rules.STAGES.size() and Rules.STAGES[completed].available and store.writable: hud.button(actions,"Начать кубок" if active.is_empty() else "Продолжить этап",flow.start_stage)
		hud.button(actions,"Боты: "+store.Bots.title(store.active_bots() if not active.is_empty() else store.bot_settings("cup")),func(): hud.BotMenu.open(hud,"cup"))
		if completed>0: hud.button(actions,"Общий зачёт",func(): hud.menu("standings"))
		if not active.is_empty() and store.writable: hud.button(actions,"Новый кубок",func(): hud.menu("cup_replace"))
		hud.button(actions,"Все кубки",func(): hud.menu("cups"))
	elif mode=="cup_replace":
		list.add_child(hud.label("НОВЫЙ КУБОК?",30,hud.GOLD))
		list.add_child(hud.label("Текущий зачёт будет заменён.\nОткрытые машины и окраски сохранятся.",20))
		hud.button(list,"Сохранить текущий кубок",func(): hud.menu("cup"))
		hud.button(list,"Боты нового кубка: "+store.Bots.title(store.bot_settings("cup")),func(): hud.BotMenu.open(hud,"cup_replace"))
		hud.button(list,"Начать новый",flow.begin_new)
	elif mode=="standings":
		list.add_child(hud.label("ОБЩИЙ ЗАЧЁТ",32,hud.GOLD))
		if not active.is_empty():
			list.add_child(hud.label("Этапов: %d / 4 · %s" % [active.results.size(),store.Bots.title(store.active_bots())],20))
			var columns=HBoxContainer.new(); columns.add_theme_constant_override("separation",32); list.add_child(columns)
			var left=VBoxContainer.new(); var right=VBoxContainer.new(); columns.add_child(left); columns.add_child(right)
			var table=Rules.table(active.results)
			for i in 16:
				var entry: Dictionary=table[i]; var column=left if i<8 else right
				column.add_child(hud.label("%d  %s   %s" % [entry.place,flow.driver_title(entry.slot),Rules.points(entry.points2)],20,hud.GOLD if entry.slot==0 else hud.PAPER))
		list.add_child(hud.label("Очки → лучшие места → место в финале.\nНе финишировал: 0 очков. Финал: ×1,5.",18))
		hud.button(list,"К этапам",func(): hud.menu("cup"))
	elif mode=="garage":
		var id: String=Rules.CARS[flow.garage_index]
		list.add_child(hud.label("ГАРАЖ · "+Rules.title(id).to_upper(),32,hud.GOLD))
		var preview=Preview.new(); preview.model_id=Rules.model(id); preview.tint=store.color(); list.add_child(preview)
		list.add_child(hud.label("Открыта" if store.owned(id) else "Награда за победу в «Лесном вызове»",20))
		list.add_child(hud.label("Общая физика · без преимущества от открытия",17,Color("bed0c6")))
		var browse=HBoxContainer.new(); browse.add_theme_constant_override("separation",12); list.add_child(browse)
		var prev=hud.button(browse,"← Машина",func(): flow.browse_car(-1)); prev.custom_minimum_size.x=250
		var next=hud.button(browse,"Машина →",func(): flow.browse_car(1)); next.custom_minimum_size.x=250
		if store.owned(id) and store.writable:
			if id!=store.data.selected: hud.button(list,"Выбрать для нового кубка",flow.select_car)
			else: list.add_child(hud.label("Выбрана для нового кубка",20,hud.GOLD))
		if store.paint_count()>1: hud.button(list,"Окраска: "+["Стандарт","Золото","Лес","Фиолетовая"][flow.Store.PAINTS.find(store.data.paint)],flow.next_paint)
		if not store.notice.is_empty(): list.add_child(hud.label(store.notice,17))
		hud.button(list,"Назад",func(): hud.menu("main"))
