# SPDX-License-Identifier: GPL-3.0-or-later
extends PanelContainer
## The counter's printed display board, behind the actual item illustration.
func _draw() -> void:
	var center:=size*0.5
	var radius:=minf(size.x,size.y)*0.41
	draw_circle(center,radius,Color("4b6260"))
	draw_arc(center,radius-4,0,TAU,80,Color("809184"),1,true)
	for corner in [Vector2.ZERO,Vector2(size.x,0),size,Vector2(0,size.y)]:
		var towards: Vector2=(center-corner).sign()
		var a: Vector2=corner+towards*6.0
		draw_line(a,a+Vector2(towards.x*14,0),Color("bd9f72"),1.5)
		draw_line(a,a+Vector2(0,towards.y*14),Color("bd9f72"),1.5)
