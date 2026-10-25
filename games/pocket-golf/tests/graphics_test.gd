# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Graphics = preload("res://scripts/graphics_settings.gd")
var failed := false
func check(value: bool, message: String) -> void:
	if not value: failed=true; printerr("FAIL: "+message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var settings = Graphics.new()
	settings.path="user://graphics-test.cfg"
	settings.quality=0; settings.fps=30; settings.scale_percent=50; settings.contrast_percent=125
	check(settings.save_settings()==OK,"save local preferences")
	var restored = Graphics.new(); restored.path=settings.path; restored.load_settings()
	check(restored.quality==0 and restored.fps==30 and restored.scale_percent==50 and restored.contrast_percent==125,"restore preferences")
	var broken := ConfigFile.new()
	broken.set_value("graphics","quality",99); broken.set_value("graphics","fps","bad"); broken.set_value("graphics","scale",-1)
	broken.set_value("graphics","contrast",999)
	broken.save(settings.path); restored.load_settings()
	check(restored.quality in [0,1,2] and restored.fps in [30,60] and restored.scale_percent in [50,75,100],"invalid settings bounded")
	check(restored.contrast_percent==100,"invalid contrast falls back to original")
	broken.erase_section_key("graphics","contrast"); broken.save(settings.path); restored.load_settings()
	check(restored.contrast_percent==100,"older config retains original contrast")
	var ui=load("res://main.tscn").instantiate(); root.add_child(ui)
	await process_frame
	ui.graphics.path=settings.path
	ui._start_local(2); ui.game.accept_turn(); ui._pause(); ui._open_graphics()
	var digest: String = ui.game.world.digest()
	var ball: Vector3 = ui.balls[0].position
	var scene_id: int = ui.course_root.get_instance_id()
	ui.graphics.quality=0; ui.graphics.scale_percent=75; ui._apply_graphics()
	await process_frame
	var point: Vector2 = root.get_final_transform()*ui.contrast_slider.get_global_transform_with_canvas()*(ui.contrast_slider.size*Vector2(0.8,0.5))
	for pressed in [true,false]:
		var pointer := InputEventMouseButton.new(); pointer.position=point; pointer.button_index=MOUSE_BUTTON_LEFT; pointer.pressed=pressed
		Input.parse_input_event(pointer); Input.flush_buffered_events()
	check(ui.graphics.contrast_percent>100,"pointer operates visible slider")
	ui.contrast_slider.value=100
	ui.contrast_slider.grab_focus(); ui._direction(1,0)
	check(ui.graphics.contrast_percent==105 and ui.contrast_slider.has_focus(),"right adjusts slider without moving focus")
	ui._primary(); check(ui.graphics.contrast_percent==100,"confirm resets contrast")
	ui._direction(0,1); check(ui.get_viewport().gui_get_focus_owner().text=="Back","down leaves slider for back")
	ui._direction(0,-1); check(ui.contrast_slider.has_focus(),"up returns to slider")
	ui.contrast_slider.value=140
	check(ui.get_node("WorldEnvironment").environment.adjustment_enabled and is_equal_approx(ui.get_node("WorldEnvironment").environment.adjustment_contrast,1.4),"slider applies scene contrast")
	ui.graphics.quality=1; ui._apply_graphics()
	check(ui.graphics.contrast_percent==140,"quality preset preserves contrast")
	ui.graphics.quality=0; ui._apply_graphics()
	# Native postprocessing must actually affect both renderer paths, not just a property.
	if DisplayServer.get_name()!="headless":
		ui.set_process(false); ui.island.set_process(false)
		ui.contrast_slider.value=100
		await process_frame; await RenderingServer.frame_post_draw
		var before: Image = root.get_texture().get_image()
		ui.contrast_slider.value=140
		await process_frame; await RenderingServer.frame_post_draw
		var after: Image = root.get_texture().get_image()
		var diff := 0.0
		for y in range(20,after.get_height()-20,20):
			var a := before.get_pixel(20,y); var b := after.get_pixel(20,y)
			diff+=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
		check(diff>0.1,"rendered world changes with contrast")
		print("Contrast pixel difference: ",diff)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(arg.trim_prefix("--capture="))
	check(not ui.get_node("Sun").shadow_enabled,"performance removes shadow rendering")
	check(root.msaa_3d==Viewport.MSAA_DISABLED and is_equal_approx(root.scaling_3d_scale,0.75),"performance applies AA and resolution")
	check(ui.island.get_node("Ocean").material_override==ui.island.simple_water,"performance uses simple water")
	var meadow=ui.island.find_children("Meadow_*","MultiMeshInstance3D",false,false)[0]
	check(meadow.multimesh.visible_instance_count<meadow.multimesh.instance_count,"less decorative geometry")
	ui.graphics.quality=2; ui._apply_graphics()
	check(ui.get_node("Sun").shadow_enabled and meadow.multimesh.visible_instance_count==meadow.multimesh.instance_count,"quality restores details without rebuild")
	check(ui.game.world.digest()==digest and ui.balls[0].position==ball and ui.course_root.get_instance_id()==scene_id,"graphics does not reset round or move ball")
	root.size=Vector2i(640,440); await process_frame; await process_frame
	check(root.get_visible_rect().encloses(ui.popup.get_global_rect()),"graphics panel fits small viewport")
	ui._pause(); check(not ui.graphics_open and ui.paused,"back returns to pause, keeps round")
	ui.paused=false; ui.game.leave(); ui._open_graphics(); ui._pause()
	check(not ui.graphics_open and ui.game.phase=="menu","back works from main menu")
	ui.graphics.quality=0; ui._start_local(1)
	check(ui.island.get_node("Ocean").material_override==ui.island.simple_water,"new course inherits settings")
	DirAccess.remove_absolute(settings.path)
	print("Graphics settings checks complete")
	ui.audio.shutdown(); await create_timer(.25).timeout
	ui.queue_free(); await process_frame; quit(1 if failed else 0)
