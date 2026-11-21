// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
uniform vec4 enamel : source_color = vec4(0.09,0.25,0.26,1.0);
uniform vec4 ink : source_color = vec4(1.0,0.89,0.63,1.0);
uniform float arrow_direction = 0.0;
varying vec3 panel;
varying vec3 face_normal;
void vertex() {
	panel=VERTEX;
	face_normal=NORMAL;
}
void fragment() {
	// BoxMesh shares an atlas between six sides. Map print in panel metres
	// so each face carries the complete mark, including the overhead camera.
	bool arrow=abs(arrow_direction)>0.5;
	vec2 size=arrow ? vec2(2.05,0.83) : vec2(14.50,1.26);
	vec2 p=panel.xy/size+0.5;
	if (abs(face_normal.y)>0.5) {
		p.y=panel.z/(arrow ? 0.10 : 0.76)+0.5;
	}
	float mark;
	if (arrow) {
		float u=arrow_direction>0.0 ? p.x : 1.0-p.x;
		float leg=abs(fract(u*2.0+abs(p.y-0.5)*0.95)-0.54);
		mark=(1.0-smoothstep(0.16,0.20,leg))*step(abs(p.y-0.5),0.36);
	} else {
		float checker=mod(floor(p.x*44.0)+floor(p.y*4.0),2.0);
		mark=checker*step(0.356,abs(p.x-0.5));
		mark=max(mark,step(0.44,abs(p.y-0.5))*0.76);
	}
	if (abs(face_normal.x)>0.5) { mark=0.0; }
	vec3 color=mix(enamel.rgb,ink.rgb,mark);
	ALBEDO=color;
	EMISSION=color*(0.06+mark*0.14);
	ROUGHNESS=0.65;
}
