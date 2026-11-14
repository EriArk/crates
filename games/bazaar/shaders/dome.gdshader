// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
void fragment(){float edge=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),3.0);ALBEDO=vec3(0.32,0.66,0.80);ALPHA=0.025+edge*0.13;}
