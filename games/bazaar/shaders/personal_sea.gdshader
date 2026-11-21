// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode unshaded;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world.xz;float a=atan(p.x,p.y);float shore=length(p)-(50.0+1.8*sin(a*3.0)+0.9*cos(a*7.0)-1.7);
 vec3 water=mix(vec3(0.21,0.70,0.68),vec3(0.12,0.43,0.54),smoothstep(1.0,60.0,shore));
 float phase=shore*2.8-TIME*1.4+sin(a*11.0)*0.18;
 float wash=smoothstep(0.80,1.0,sin(phase))*(1.0-smoothstep(0.0,4.5,shore))*smoothstep(-1.0,0.0,shore);
 float ripple=sin(p.x*0.7+p.y*0.4+TIME*0.6)*sin(p.y*1.1-TIME*0.4);
 ripple*=1.0-smoothstep(0.25,1.5,max(fwidth(p.x),fwidth(p.y)));
 float crest=sin(p.y*2.5+p.x*0.7+0.85*sin(p.x*0.38)-TIME*0.85);
 float glints=smoothstep(0.93,1.0,crest)*smoothstep(0.55,1.0,sin(p.x*1.45+TIME*0.62));
 glints*=1.0-smoothstep(0.12,0.75,max(fwidth(p.x),fwidth(p.y))*2.5);
 water+=ripple*0.02+vec3(0.14,0.19,0.13)*glints;water=mix(water,vec3(0.86,0.97,0.92),wash*0.8);
 ALBEDO=mix(water,vec3(0.33,0.56,0.63),smoothstep(73.0,300.0,length(p)));
}
