// SPDX-License-Identifier: GPL-3.0-or-later
shader_type sky;
uniform sampler2D panorama : source_color, filter_linear, repeat_disable;
uniform vec4 horizon_color : source_color = vec4(0.62,0.72,0.74,1.0);
uniform float twilight;
uniform float night;
uniform float cover;
void sky() {
	float azimuth=atan(EYEDIR.z,EYEDIR.x)/TAU;
	float elevation=asin(clamp(EYEDIR.y,-1.0,1.0));
	float u=abs(fract(azimuth+0.19)*2.0-1.0);
	vec3 art=texture(panorama,vec2(u,clamp(0.89-elevation*1.9,0.0,1.0))).rgb;
	float value=dot(art,vec3(0.25,0.62,0.13));
	vec3 sunset=mix(vec3(0.16,0.15,0.28),vec3(1.00,0.70,0.46),smoothstep(0.06,0.95,value));
	vec3 dusk=mix(art,sunset,twilight*0.78);
	vec3 evening=mix(dusk,vec3(0.022,0.045,0.09)+vec3(0.13,0.17,0.23)*value,night);
	vec3 storm=horizon_color.rgb*(0.57+value*0.65);
	vec3 painted=mix(evening,storm,cover*0.84);
	// Distant features lose contrast through the same air that colours the terrain.
	float low_air=1.0-smoothstep(0.0,0.20,elevation);
	vec3 air=horizon_color.rgb;
	if (LIGHT0_ENABLED) {
		float facing=max(dot(EYEDIR,LIGHT0_DIRECTION),0.0);
		float forward_scatter=pow(facing,6.0)*(1.0-cover)*(1.0-night);
		air+=vec3(0.28,0.14,0.05)*forward_scatter*(0.45+twilight);
	}
	float veil=low_air*mix(0.40,0.72,cover);
	COLOR=mix(air,mix(painted,air,veil),smoothstep(-0.09,0.025,elevation));
}
