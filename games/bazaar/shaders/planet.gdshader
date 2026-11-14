// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode unshaded;
varying vec3 local;
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise(vec3 p){
 vec3 i=floor(p), f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
float fbm(vec3 p){return noise(p)*0.55+noise(p*2.03)*0.28+noise(p*4.11)*0.12+noise(p*8.17)*0.05;}
void vertex(){local=normalize(VERTEX);}
void fragment(){
 vec3 n=normalize(local);float turbulence=fbm(n*9.0);float latitude=n.y*0.85+n.x*0.2;
 float bands=0.5+0.5*sin(latitude*44.0+turbulence*7.0+sin(n.z*9.0)*0.8);
 vec3 color=mix(vec3(0.12,0.24,0.42),vec3(0.48,0.63,0.70),smoothstep(0.1,0.85,bands));
 color=mix(color,vec3(0.79,0.67,0.53),smoothstep(0.56,0.75,turbulence)*0.65);
 float detail=fbm(n*38.0);color*=0.85+detail*0.28;
 float daylight=smoothstep(-0.17,0.65,dot(n,normalize(vec3(-0.65,0.45,0.7))));
 float rim=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),4.0);
 ALBEDO=color*(0.045+0.955*daylight)+vec3(0.17,0.43,0.66)*rim*daylight*0.55;
}
