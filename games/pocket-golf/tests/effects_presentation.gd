# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var ui
var failed := false
var output := ""
var peak := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): output=arg.trim_prefix("--capture=")
	call_deferred("run")

func check(value: bool, label: String) -> void:
	if not value: failed=true; printerr("FAIL: "+label)

func begin(hole: int, origin: Array, angle: int, power: int, strokes: int=0) -> void:
	ui._start_local(1); ui.game.accept_turn()
	ui.game.world.hole=hole; ui.game.world._begin_hole()
	ui.game.world.balls[0]=origin; ui.game.world.strokes[0]=strokes
	ui.game.angle=angle; ui.game.power=power; ui._refresh(); ui.game.fire()

func at(time: float) -> void:
	ui.elapsed=time; ui._process(0)
	peak=maxi(peak,ui.effects.active.size())

func capture(name: String, focus: Vector3) -> void:
	if output.is_empty(): return
	ui.camera.position=focus+Vector3(3.0,2.8,4.2)
	ui.camera.look_at(focus+Vector3.UP*0.12)
	await process_frame; await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"save "+name)

func run() -> void:
	ui=load("res://main.tscn").instantiate(); root.add_child(ui)
	await process_frame; ui.set_process(false)
	begin(0,[0,6000],0,90)
	at(0.12)
	check(ui.effects.active.size()>5,"strike is visible")
	await capture("effects-strike",ui.balls[0].position)
	var saved: String = ui.game.world.digest()
	var snapshot: Array = []
	for item in ui.effects.active: snapshot.append(item.node.transform)
	ui.paused=true; var time: float = ui.effects.clock; ui._process(0.3)
	check(ui.effects.clock==time,"local pause freezes effect time")
	for i in snapshot.size(): check(ui.effects.active[i].node.transform==snapshot[i],"local pause freezes particles")
	ui.game.online=true; ui._process(0.1)
	check(ui.effects.clock>time,"online pause continues effects with ball")
	ui.game.online=false; ui.paused=false
	check(saved==ui.game.world.digest(),"effects and pause do not mutate rules")
	var trajectory: Dictionary = ui.shot
	var course: Dictionary = ui.Courses.get_course(0)
	var reference: Array = []
	for fps in [30,60,144]:
		ui.effects.begin(trajectory,course)
		for frame in range(1,fps+1): ui.effects.seek(frame/float(fps))
		var positions: Array = []
		for item in ui.effects.active: positions.append(item.node.position)
		if reference.is_empty(): reference=positions
		else:
			check(reference.size()==positions.size(),"frame rate independent live particle count")
			for i in mini(reference.size(),positions.size()): check(reference[i].is_equal_approx(positions[i]),"frame rate independent particle positions")
	check(ui.effects.events.any(func(e): return e.kind=="trail"),"fast shot has short trail")
	begin(0,[4600,0],90,75)
	check(not ui.shot.bounces.is_empty(),"real rail bounce fixture")
	var contact: Dictionary = ui.effects.events.filter(func(e): return e.kind=="wood")[0]
	check(absf(contact.pos.x-5.0)<0.035,"contact sits on rail surface")
	# Jump over contact: emit once, at its old position with its true age.
	at(contact.time+0.12)
	var cursor: int = ui.effects.cursor; ui._process(0)
	check(ui.effects.cursor==cursor,"repeated frame does not repeat contact")
	await capture("effects-bank",contact.pos)
	begin(2,[0,0],0,65)
	check(ui.effects.events.any(func(e): return e.kind=="sand"),"sand emits grains")
	at(0.2); await capture("effects-sand",ui.balls[0].position)
	begin(1,[-1000,1500],0,70)
	check(ui.effects.events.any(func(e): return e.kind=="stone"),"stone has its own impact")
	for strokes in [0,2]:
		begin(0,[0,-4600],0,20,strokes)
		check(ui.shot.sunk and not ui.shot.rims.is_empty(),"real cup/rim fixture")
		var kind := "ace" if strokes==0 else "cup"
		var win: Dictionary = ui.effects.events.filter(func(e): return e.kind==kind)[0]
		check(win.pos.y>ui.cup.position.y,"celebration originates above ground")
		at(win.time+0.25)
		check(ui.effects.active.size()>=16,"cup celebration remains visible")
		await capture("effects-"+kind,ui.cup.position)
	# A long stall skips expired events instead of releasing a burst at the endpoint.
	ui.effects.seek(100)
	check(ui.effects.active.is_empty(),"stale events are expired after a hitch")
	# Stress saturation and recycle without growing the pool.
	for repeat in 20:
		ui.effects.schedule("ace",100,ui.cup.position)
	ui.effects.seek(100)
	check(ui.effects.pool.size()<=128 and ui.effects.active.size()<=128,"hard pool bound")
	ui.effects.seek(102)
	check(ui.effects.active.is_empty(),"saturated pool expires")
	begin(0,[0,6000],0,75); ui.game.leave()
	check(ui.effects.active.is_empty() and ui.effects.events.is_empty(),"leave cancels pending effects")
	begin(0,[0,6000],0,75); ui._build_course()
	check(ui.effects.active.is_empty() and ui.effects.events.is_empty(),"course rebuild clears effects")
	print("EFFECTS PRESENTATION ","FAIL" if failed else "PASS"," contacts, materials, rim, cup/ace, stale frames, 30/60/144 Hz, local/online pause, cleanup, pool<=128; sampled peak=",peak)
	quit(1 if failed else 0)
