# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
# Local presentation only: never sent to peers or used by the trajectory rules.
const TITLES := ["Performance", "Balanced", "Quality"]
const DESCRIPTIONS := ["Lighter grass and water, no shadows or blur.", "Soft shadows and lighter scenery.", "Full grass, detailed water and soft shadows."]
var quality := 1
var fps := 60
var scale_percent := 100
var path := "user://graphics.cfg"

func load_settings() -> void:
	quality=0 if OS.get_environment("POCKET_GOLF_DEFAULT_QUALITY")=="performance" else 1
	scale_percent=75 if quality==0 else 100
	var config := ConfigFile.new()
	if config.load(path)!=OK: return
	var q = config.get_value("graphics","quality",quality)
	var f = config.get_value("graphics","fps",60)
	var s = config.get_value("graphics","scale",scale_percent)
	if q is int and q in [0,1,2]: quality=q
	if f is int and f in [30,60]: fps=f
	if s is int and s in [50,75,100]: scale_percent=s

func save_settings() -> Error:
	var config := ConfigFile.new()
	config.set_value("graphics","quality",quality)
	config.set_value("graphics","fps",fps)
	config.set_value("graphics","scale",scale_percent)
	return config.save(path)

func apply(scene: Node3D) -> void:
	Engine.max_fps=fps
	var viewport := scene.get_viewport()
	viewport.msaa_3d=[Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X][quality]
	viewport.scaling_3d_mode=Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale=scale_percent/100.0
	var sun: DirectionalLight3D = scene.get_node("Sun")
	sun.shadow_enabled=quality>0
	sun.directional_shadow_max_distance=65.0 if quality==1 else 125.0
	RenderingServer.directional_shadow_atlas_set_size(4096 if quality==2 else 1024,true)
	if scene.camera.optics!=null: scene.camera.optics.dof_blur_far_enabled=quality==2
	if scene.island!=null: scene.island.set_quality(quality)
