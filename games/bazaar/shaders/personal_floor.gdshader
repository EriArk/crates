// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
uniform bool station=false;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world.xz; vec2 tiled=p/(station?4.0:1.6); if(!station)tiled.x+=mod(floor(tiled.y),2.0)*0.5;
 vec2 edges=min(fract(tiled),1.0-fract(tiled)); float fw=max(fwidth(tiled.x),fwidth(tiled.y));
 float seam=1.0-smoothstep(0.006,0.014+fw,min(edges.x,edges.y)); seam*=1.0-smoothstep(0.25,0.8,fw);
 float variation=fract(sin(dot(floor(tiled),vec2(12.9898,78.233)))*43758.5453);
 vec3 base=station?mix(vec3(0.22,0.29,0.38),vec3(0.28,0.36,0.44),variation):mix(vec3(0.61,0.55,0.43),vec3(0.72,0.66,0.53),variation);
 if(station)base=mix(base,vec3(0.44,0.53,0.57),smoothstep(25.0,26.0,length(p)));
 float radius=length(p);
 float angle=atan(p.y,p.x);
 // Observatory sighting marks and a compass rose are flush with the buildable floor.
 if(station){
     float annulus=1.0-smoothstep(0.07,0.12+fwidth(radius),abs(radius-20.4));
     float ticks=(1.0-smoothstep(0.035,0.065,abs(fract(angle*24.0/PI+0.5)-0.5)))*smoothstep(19.1,19.35,radius)*(1.0-smoothstep(20.0,20.2,radius));
     base=mix(base,vec3(0.72,0.56,0.37),max(annulus,ticks)*0.75);
 }else{
     float spoke=abs(sin(angle*4.0));
     float rose=1.0-smoothstep(0.96,1.03,radius*(0.18+spoke*0.66));
     float band=1.0-smoothstep(0.09,0.13+fwidth(radius),abs(radius-6.2));
     base=mix(base,vec3(0.31,0.54,0.53),max(band,rose)*0.84);
 }
 ALBEDO=base*(1.0-seam*0.28);ROUGHNESS=station?0.68:0.98;METALLIC=station?0.25:0.0;
}
