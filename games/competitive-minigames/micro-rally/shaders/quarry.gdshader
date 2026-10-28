// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
varying vec3 world;
void vertex() { world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) { vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
void fragment() {
 float grain=noise(world.xz*3.5);
 float patches=noise(world.xz*0.12);
 float strata=sin(world.y*3.2+noise(world.xz*0.09)*1.3)*0.5+0.5;
 vec3 stone=mix(vec3(0.36,0.34,0.29),vec3(0.58,0.54,0.43),strata*0.35+patches*0.5+grain*0.15);
 ALBEDO=stone; ROUGHNESS=0.94;
 NORMAL_MAP=normalize(vec3((grain-0.5)*0.12,0.0,1.0))*0.5+0.5;
}
