// SPDX-License-Identifier: GPL-3.0-or-later
// Adapted from Pocket Golf's band-limited sea for a flowing creek.
shader_type spatial;
render_mode cull_disabled;
uniform vec4 deep : source_color = vec4(0.06,0.23,0.26,1);
uniform vec4 shallow : source_color = vec4(0.18,0.42,0.35,1);
uniform vec4 foam_color : source_color = vec4(0.80,0.90,0.82,1);
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world.xz; float bank=smoothstep(2.8,4.8,abs(p.x+30.0));
 float phase=p.x*4.0+sin(p.y*2.0-TIME*2.0)*0.7;
 float width=max(0.02,fwidth(phase));
 float ripple=sin(phase)*sin(p.y*3.0-TIME*2.4);
 float fleck=smoothstep(0.82-width,0.98+width,ripple);
 fleck*=1.0-smoothstep(0.25,1.1,fwidth(phase));
 vec3 water=mix(deep.rgb,shallow.rgb,bank);
 ALBEDO=mix(water,foam_color.rgb,fleck*(0.2+bank*0.45));
 ROUGHNESS=0.28; SPECULAR=0.45;
 NORMAL=normalize(NORMAL+vec3(sin(phase)*0.025,0.0,cos(p.y*3.0-TIME)*0.025));
}
