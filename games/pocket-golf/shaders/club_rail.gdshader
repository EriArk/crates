// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
uniform vec4 enamel : source_color = vec4(0.085,0.32,0.31,1.0);
uniform vec4 deck : source_color = vec4(0.70,0.47,0.27,1.0);
uniform vec4 brass : source_color = vec4(0.94,0.77,0.46,1.0);
varying vec3 world;
void vertex() { world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	bool long_side=abs(world.x)>5.0 && abs(world.z)<8.1;
	float along=long_side ? world.z : world.x;
	float across=long_side ? abs(world.x)-5.12 : abs(world.z)-8.12;
	float plank=sin(along*3.4+across*52.0)*0.022;
	vec3 color=mix(enamel.rgb,deck.rgb*(1.0+plank),smoothstep(0.24,0.265,world.y));
	float trim=1.0-smoothstep(0.012,0.028,abs(abs(across)-0.084));
	float plate=1.0-smoothstep(0.035,0.065,abs(fract(along*0.5+0.5)-0.5));
	ALBEDO=mix(color,brass.rgb,max(trim*step(0.32,world.y),plate*0.93));
	ROUGHNESS=mix(0.79,0.48,plate);
}
