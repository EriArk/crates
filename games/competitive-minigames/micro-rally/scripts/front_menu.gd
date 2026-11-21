# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
const Catalog = preload("event_catalog.gd")
const Preview = preload("garage_preview.gd")

static func subtitle(hud, list: Node, text: String) -> void:
	var line=hud.label(text,19,Color("cad1c5")); line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x=280; list.add_child(line)

static func build(hud, list: VBoxContainer, mode: String) -> void:
	var game=hud.game
	if mode=="main":
		list.add_child(hud.label("MICRO RALLY",52))
		subtitle(hud,list,"ALPHA  /  DIRT. SPEED. METAL.")
		var columns=HBoxContainer.new(); columns.add_theme_constant_override("separation",52); list.add_child(columns)
		var actions=VBoxContainer.new(); actions.add_theme_constant_override("separation",8); actions.custom_minimum_size.x=410; columns.add_child(actions)
		var active: Dictionary=game.cup.store.data.active
		if not active.is_empty() and active.results.size()<Catalog.Rules.STAGES.size():
			hud.button(actions,"Continue cup  →",func(): hud.menu("cup"))
		hud.button(actions,"CUPS",func(): hud.menu("cups"))
		hud.button(actions,"QUICK PLAY",func(): hud.menu("modes"))
		hud.button(actions,"LOBBY",hud.open_lobby)
		hud.button(actions,"GARAGE",game.cup.open_garage)
		hud.button(actions,"SETTINGS",func(): hud.menu("settings"))
		hud.button(actions,"QUIT",func(): hud.confirm("QUIT GAME?","Completed stages and your garage are saved.","Quit",game.quit_game))
		for item in actions.get_children(): item.add_theme_font_size_override("font_size",26)
		var hero=VBoxContainer.new(); hero.size_flags_horizontal=Control.SIZE_EXPAND_FILL; columns.add_child(hero)
		var preview=Preview.new(); preview.model_id=Catalog.Rules.model(game.cup.store.data.selected); preview.tint=game.cup.store.color(); preview.preview_size=Vector2(500,250); hero.add_child(preview)
		hero.add_child(hud.label(game.car_title().to_upper(),36,hud.GOLD))
		subtitle(hud,hero,"YOUR CAR / YOUR CUP")
		hero.add_child(hud.label("WOODLAND CHALLENGE",24))
		subtitle(hud,hero,game.cup.status())
	elif mode=="cups":
		list.add_child(hud.label("CUPS",42))
		var filters=HBoxContainer.new(); filters.add_theme_constant_override("separation",10); list.add_child(filters)
		for i in Catalog.FILTERS.size():
			var b=hud.button(filters,Catalog.FILTERS[i],func(): hud.cup_filter=i; hud.cup_page=0; hud.menu("cups"))
			b.custom_minimum_size.x=166; b.add_theme_font_size_override("font_size",19)
			if i==hud.cup_filter: b.add_theme_stylebox_override("normal",hud.MenuSkin.plate(Color("69552b"),18,true))
		var entries=Catalog.cups(hud.cup_filter,hud.cup_entries)
		if entries.is_empty():
			subtitle(hud,list,"Cups of this type are coming soon.")
		else:
			hud.cup_page=clampi(hud.cup_page,0,(entries.size()-1)/4)
			var grid=GridContainer.new(); grid.columns=2; grid.add_theme_constant_override("h_separation",20); grid.add_theme_constant_override("v_separation",14); list.add_child(grid)
			for entry in entries.slice(hud.cup_page*4,hud.cup_page*4+4):
				var text="%s\n%d stages  /  %s\nReward: %s" % [entry.title.to_upper(),entry.stages.size(),entry.duration,entry.reward]
				var b=hud.button(grid,text,func(): hud.select_cup(entry.id)); b.custom_minimum_size=Vector2(470,120)
				b.disabled=not Catalog.can_start(entry.id)
			if entries.size()>4:
				var pages=HBoxContainer.new(); list.add_child(pages)
				hud.button(pages,"←",func(): hud.cup_page-=1; hud.menu("cups")).custom_minimum_size.x=80
				pages.add_child(hud.label("%d / %d" % [hud.cup_page+1,ceili(entries.size()/4.0)],22))
				hud.button(pages,"→",func(): hud.cup_page+=1; hud.menu("cups")).custom_minimum_size.x=80
			subtitle(hud,list,"Win cups to unlock cars and new paint jobs.")
		hud.button(list,"Back",func(): hud.menu("main"))
	elif mode=="modes":
		list.add_child(hud.label("QUICK PLAY",40))
		subtitle(hud,list,"CHOOSE A MODE")
		for entry in Catalog.MODES:
			var b=hud.button(list,entry.title.to_upper()+"\n"+entry.description+("" if entry.available else "  ·  coming soon"),func(): game.select_mode(entry.id))
			b.custom_minimum_size.y=86; b.disabled=not entry.available
		hud.button(list,"Back",func(): hud.menu("main"))
	elif mode=="settings":
		list.add_child(hud.label("SETTINGS",40))
		subtitle(hud,list,"MAKE IT YOURS")
		hud.button(list,"Audio",func(): hud.menu("audio"))
		hud.button(list,"Controls",func(): hud.menu("controls"))
		hud.button(list,"Credits and data",func(): hud.menu("credits"))
		hud.button(list,"Back",func(): hud.menu(hud.settings_parent))
	elif mode=="audio":
		list.add_child(hud.label("AUDIO",40))
		subtitle(hud,list,"GARAGE ROCK / DIRT / METAL")
		for kind in ["music","effects"]:
			var row=HBoxContainer.new(); list.add_child(row)
			var name_label=hud.label("Music" if kind=="music" else "Effects",24); name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(name_label)
			var current=game.sound.music_volume if kind=="music" else game.sound.effects_volume
			var value=hud.label("%d%%" % roundi(current*100),24,hud.GOLD); row.add_child(value)
			var slider=HSlider.new(); slider.name=kind; slider.min_value=0; slider.max_value=100; slider.step=5; slider.value=current*100
			slider.custom_minimum_size=Vector2(500,48); slider.scrollable=false; hud.MenuSkin.style_slider(slider); list.add_child(slider); hud.focus_controls.append(slider)
			slider.focus_entered.connect(func():
				name_label.add_theme_color_override("font_color",hud.GOLD)
				value.text="◀ %d%% ▶" % roundi(slider.value))
			slider.focus_exited.connect(func():
				name_label.add_theme_color_override("font_color",hud.PAPER)
				value.text="%d%%" % roundi(slider.value))
			slider.value_changed.connect(func(amount):
				value.text=("◀ %d%% ▶" if slider.has_focus() else "%d%%") % roundi(amount)
				hud.audio_notice="" if game.sound.set_volume(kind,amount/100) else "Could not save this setting."
				hud.audio_status.text=hud.audio_notice)
		subtitle(hud,list,"← / → — volume   ·   0% — muted")
		hud.audio_status=hud.label(hud.audio_notice,18,hud.GOLD); list.add_child(hud.audio_status)
		hud.button(list,"Back",func(): hud.menu(hud.audio_parent))
	elif mode=="confirm":
		list.add_child(hud.label(hud.confirm_title,32,hud.GOLD))
		subtitle(hud,list,hud.confirm_body)
		hud.button(list,"Cancel",hud.back)
		hud.button(list,hud.confirm_action_title,hud.execute_confirm)
	elif mode=="lobby":
		list.add_child(hud.label("TRAINEROS LOBBY",36,hud.GOLD))
		subtitle(hud,list,"Meet your friends in a TrainerOS lobby.\nLaunch the game from Crates to open it.")
		hud.button(list,"Back",func(): hud.menu("main"))
