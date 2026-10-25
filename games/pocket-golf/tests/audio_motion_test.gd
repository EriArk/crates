# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failed := false
var ui
var played: Array[String] = []
var output := ""
func _initialize() -> void:
	output=OS.get_environment("GOLF_MOTION_CAPTURE")
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failed=true; printerr("FAIL: "+label)
func picture(name: String) -> void:
	if output.is_empty() or DisplayServer.get_name()=="headless": return
	ui.camera.position=ui.anchor.position+ui.anchor.basis*Vector3(1.4,0.98,1.5)
	ui.camera.look_at(ui.anchor.position+Vector3.UP*0.46)
	await process_frame; await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"capture "+name)
func fresh_shot(origin: Array, power: float, prior: int=0) -> void:
	ui._start_local(1); ui.game.accept_turn()
	ui.game.world.balls[0]=origin; ui.game.world.strokes[0]=prior
	ui.game.angle=0; ui.game.power=power; ui._refresh(); ui.game.fire()
func run() -> void:
	ui=load("res://main.tscn").instantiate(); root.add_child(ui)
	await process_frame; ui.set_process(false); ui.game.set_process(false)
	ui.audio.path="user://audio-motion-test.cfg"
	ui.audio.music_percent=35; ui.audio.effects_percent=70
	check(ui.audio.save_settings()==OK,"save independent sound settings")
	ui.audio.music_percent=0; ui.audio.load_settings()
	check(ui.audio.music_percent==35 and ui.audio.effects_percent==70,"restore audio preferences")
	var config := ConfigFile.new(); config.set_value("audio","music",200); config.set_value("audio","effects","bad"); config.save(ui.audio.path)
	ui.audio.load_settings()
	check(ui.audio.music_percent==45 and ui.audio.effects_percent==75,"invalid preferences use safe defaults")
	ui.audio.cue_played.connect(func(kind): played.append(kind))
	ui.audio_focused=true
	ui._open_audio(); ui.audio_sliders[0].grab_focus(); ui._direction(-1,0)
	check(ui.audio.music_percent==40,"controller/keyboard adjusts music slider")
	ui.audio_sliders[1].value=0
	check(ui.audio.effects_percent==0,"effect slider supports true mute")
	ui.audio.cue("cup"); check(played.is_empty(),"muted cue is not queued")
	ui.audio.effects_percent=75; ui.audio.apply_levels(); ui._close_audio()
	fresh_shot([0,6000],50)
	ui._process(0.54); check(played.is_empty(),"putt audio waits for club contact")
	ui._process(0.02); check(played.count("strike")==1,"one strike at contact")
	ui._process(0); check(played.count("strike")==1,"same frame cannot replay strike")
	var clock: float = ui.audio.clock
	ui.paused=true; ui._process(.4)
	check(ui.audio.clock==clock and ui.audio.rolling.stream_paused,"local pause freezes cue timeline")
	ui.game.online=true; ui._process(.4)
	check(ui.audio.clock>clock,"online timeline continues while local sound is paused")
	ui.game.online=false; ui.paused=false
	ui.audio_focused=false; ui._process(.1)
	check(ui.audio.music.stream_paused,"focus loss silences music without changing system volume")
	ui.audio_focused=true; ui._process(0)
	check(not ui.audio.music.stream_paused,"focus return resumes music")
	ui.audio.begin([{"kind":"wood","time":0.2,"strength":1.0}])
	var before := played.size(); ui.audio.seek(9)
	check(played.size()==before and ui.audio.cursor==1,"hitch skips expired impact, no catch-up burst")
	fresh_shot([0,-4600],20)
	check(ui.shot.sunk,"real cup fixture")
	var end: float = (ui.shot.path.size()-1)/float(ui.shot.hz)+ui.Stroke.CONTACT
	ui.elapsed=end; ui._process(0)
	check(played.count("cup")==1 and played.count("ace-jingle")==1,"cup and ace cadence fire exactly once")
	ui._process(0); check(played.count("ace-jingle")==1,"celebration cadence not repeated")
	ui.audio._process(.2)
	check(ui.audio.duck>0 and ui.audio.jingle.playing,"jingle ducks the music")
	ui.elapsed=end+2.9; ui._process(0)
	check(ui.game.phase!="moving","celebration returns to turn flow")
	ui.game.leave()
	check(ui.audio.events.is_empty() and not ui.audio.jingle.playing and not ui.audio.rolling.playing,"leave clears all pending shot sounds")
	check(ui.audio.voices.size()==8,"fixed sound voice pool")
	# External SDK model, never embedded in this game or its source package.
	var path := OS.get_environment("TRAINER_AVATAR_TEST_GLB")
	if path.is_empty():
		check(false,"set TRAINER_AVATAR_TEST_GLB for the real SDK skeleton checks")
	else:
		var model=load("res://addons/traineros/avatar_presenter.gd").from_descriptor({"schema":1,"rig":"trainer-humanoid-54-v1","glb":path,"sha256":FileAccess.get_sha256(path)})
		check(model!=null,"official descriptor loads external rig")
		if model!=null:
			# This is a descriptor/rig test, not a live SDK-host test. Disable the
			# unrelated discovery callback before manually installing its fixture.
			ui.avatar_binding.client.disconnect_host()
			for connection in ui.avatar_binding.client.unavailable.get_connections():
				ui.avatar_binding.client.unavailable.disconnect(connection.callable)
			model.rotation.y=PI/2
			ui._start_local(1); ui.game.accept_turn(); ui.anchor.install_visual(model,"test-owner")
			check(ui.anchor.motion!=null,"turn/celebration controller bound to actual rig")
			var motion=ui.anchor.motion; var skeleton: Skeleton3D = motion.skeleton
			ui.anchor.step_turn(0)
			var initial_left: Vector3 = motion.feet.L
			var initial_right: Vector3 = motion.feet.R
			ui.game.angle=12; ui._refresh(); ui.anchor.step_turn(.08)
			check(not motion.step_side.is_empty(),"changing aim starts a real footstep")
			var planted := "R" if motion.step_side=="L" else "L"
			check(motion.feet[planted].is_equal_approx(initial_right if planted=="R" else initial_left),"opposite foot stays planted")
			check(motion.feet[motion.step_side].y>motion._target(motion.step_side).y+.01,"swinging foot lifts off ground")
			await picture("turn-step")
			for tick in 120: ui.anchor.step_turn(1.0/60)
			check(motion.step_side.is_empty(),"feet settle after turning stops")
			for side in ["L","R"]:
				check(motion.feet[side].distance_to(motion._target(side))<.025,"foot settles beside body "+side)
				var foot := skeleton.find_bone("foot."+side)
				check(skeleton.to_global(skeleton.get_bone_global_pose(foot).origin).distance_to(motion.feet[side])<.025,"IK ankle reaches planted target "+side)
			var digest: String = ui.game.world.digest()
			var maximum_error := 0.0
			for fps in [30,60,120]:
				ui.anchor.reset_motion(); ui.anchor.step_turn(0)
				for tick in fps*4:
					ui.game.angle=fmod(ui.game.angle+90.0/fps,360); ui._refresh(); ui.anchor.step_turn(1.0/fps)
					for side in ["L","R"]:
						var foot := skeleton.find_bone("foot."+side)
						maximum_error=maxf(maximum_error,skeleton.to_global(skeleton.get_bone_global_pose(foot).origin).distance_to(motion.feet[side]))
			check(maximum_error<.03,"continuous full-speed turning keeps foot targets reachable")
			print("TURN max ankle target error m=",maximum_error)
			var poses: Array = []
			for variant in 3:
				ui.anchor.celebrate(.7,variant)
				check(not ui.anchor.stroke.club.visible,"club hidden during reaction")
				poses.append(skeleton.get_bone_pose_rotation(skeleton.find_bone("upper_arm.R")))
				await picture("celebration-"+str(variant))
			check(not poses[0].is_equal_approx(poses[1]) and not poses[1].is_equal_approx(poses[2]),"three distinct victory poses")
			check(ui.game.world.digest()==digest,"animation cannot mutate authoritative rules")
			ui.anchor.reset_motion()
			check(ui.anchor.stroke.club.visible and model.position.is_equal_approx(motion.base_visual),"restore putter and root after celebration")
			fresh_shot([0,-4600],20,2)
			end=(ui.shot.path.size()-1)/float(ui.shot.hz)+ui.Stroke.CONTACT
			ui.elapsed=end+.1; ui._process(0.01)
			check(ui.anchor.motion.celebration>=0 and played.count("cup-jingle")==1,"actual scored shot drives rig and ordinary cup cadence")
			var pose: Quaternion = skeleton.get_bone_pose_rotation(skeleton.find_bone("upper_arm.R"))
			ui.paused=true; ui._process(.4)
			check(skeleton.get_bone_pose_rotation(skeleton.find_bone("upper_arm.R")).is_equal_approx(pose),"local pause freezes celebration pose")
			ui.paused=false; ui.elapsed=end+2.9; ui._process(0)
			check(ui.game.phase!="moving" and ui.anchor.motion.celebration==-1,"actual cup reaction restores normal turn presentation")
			ui.anchor.clear_identity(); ui._placeholder()
			check(ui.anchor.motion==null and ui.anchor.player_id.is_empty(),"revocation releases animation and rig")
	DirAccess.remove_absolute(ui.audio.path)
	print("AUDIO/MOTION ","FAIL" if failed else "PASS"," contact, cue dedup, mute, pause/focus, hitch, ace, settings, bounded pool, real rig foot planting, three celebrations, revocation")
	ui.audio.shutdown()
	# Let the audio mixer release its stopped playback references before shutdown.
	await create_timer(.25).timeout
	ui.queue_free(); await process_frame
	quit(1 if failed else 0)
