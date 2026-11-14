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
 vec3 base=station?mix(vec3(0.22,0.29,0.38),vec3(0.28,0.36,0.44),variation):mix(vec3(0.44,0.40,0.32),vec3(0.49,0.45,0.37),variation);
 if(station)base=mix(base,vec3(0.44,0.53,0.57),smoothstep(25.0,26.0,length(p)));
 ALBEDO=base*(1.0-seam*0.28);ROUGHNESS=station?0.68:0.98;METALLIC=station?0.25:0.0;
}
