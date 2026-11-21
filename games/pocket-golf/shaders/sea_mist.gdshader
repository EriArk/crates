// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.85,0.90,0.88,1.0);
uniform float phase = 0.0;
void fragment() {
	float x = UV.x;
	float v = UV.y + 0.065*sin(x*13.0+phase+TIME*0.12);
	float wisp = smoothstep(0.08,0.47,v)*(1.0-smoothstep(0.52,0.91,v));
	float banks = 0.62+0.28*cos(17.0*x+phase+TIME*0.08)+0.10*cos(29.0*x-TIME*0.13);
	ALBEDO=tint.rgb;
	ALPHA=0.36*wisp*banks*smoothstep(0.0,0.17,x)*(1.0-smoothstep(0.8,1.0,x));
}
