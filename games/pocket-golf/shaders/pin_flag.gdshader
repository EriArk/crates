// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode cull_disabled;
uniform vec4 coral : source_color = vec4(0.93,0.24,0.17,1.0);
uniform vec4 cream : source_color = vec4(1.0,0.92,0.72,1.0);
varying vec3 point;
void vertex() {
	point=VERTEX;
	float tip=smoothstep(0.04,0.34,-point.x);
	VERTEX.z+=tip*0.046*sin(TIME*2.4+point.x*10.0);
}
void fragment() {
	float line=abs(fract((point.x+point.z)*4.0+point.y*1.1)-0.5);
	vec3 cloth=mix(coral.rgb,cream.rgb,1.0-smoothstep(0.06,0.11,line));
	vec3 pole=mix(cream.rgb,coral.rgb,0.85*step(0.70,fract(point.y*3.0)));
	ALBEDO=mix(pole,cloth,smoothstep(0.025,0.045,-point.x));
	ROUGHNESS=0.93;
}
