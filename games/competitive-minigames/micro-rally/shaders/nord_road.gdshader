shader_type spatial;
uniform float wetness = 0.0;
uniform vec2 karussell;
uniform vec2 mini_karussell;
float zone(vec2 span,float distance){return smoothstep(span.x,span.x+20.0,distance)*(1.0-smoothstep(span.y-20.0,span.y,distance));}
void fragment(){
 float grain=sin(UV.x*710.0+sin(UV.y*31.0))*sin(UV.y*93.0);
 float filtered=1.0-smoothstep(0.3,1.0,max(length(dFdx(UV*vec2(710.0,93.0))),length(dFdy(UV*vec2(710.0,93.0)))));
 float patches=sin(UV.y*0.37+sin(UV.x*38.0))*sin(UV.x*21.0+UV.y*0.63);
 vec3 asphalt=vec3(0.14,0.16,0.155)*(1.0+patches*0.055+grain*filtered*0.07);
 float concrete=max(zone(karussell,UV.y),zone(mini_karussell,UV.y))*(1.0-smoothstep(0.62,0.70,UV.x));
 float joint=1.0-smoothstep(0.02,0.05,abs(fract(UV.y/3.0)-0.5));
 ALBEDO=mix(asphalt,vec3(0.61,0.60,0.53)*(1.0-joint*0.18),concrete);
 float kerb=1.0-step(0.055,min(UV.x,1.0-UV.x));
 vec3 paint=mix(vec3(0.84,0.82,0.72),vec3(0.63,0.11,0.08),step(0.5,fract(UV.y/6.0)));
 ALBEDO=mix(ALBEDO,paint,kerb)*(1.0-wetness*0.16);
 ROUGHNESS=mix(0.94,0.4,wetness); SPECULAR=0.22;
}
