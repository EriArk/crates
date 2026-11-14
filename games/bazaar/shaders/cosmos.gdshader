// SPDX-License-Identifier: GPL-3.0-or-later
shader_type sky;
float hash(vec3 p){return fract(sin(dot(p,vec3(12.9898,78.233,39.425)))*43758.5453);}
void sky(){
 vec3 d=normalize(EYEDIR);float band=pow(max(0.0,1.0-abs(d.y*0.75+d.x*0.4-0.12)),10.0);
 float mist=0.5+0.25*sin(d.x*17.0+d.z*9.0)+0.25*sin(d.z*27.0-d.y*13.0);
 vec3 color=vec3(0.006,0.011,0.028)+band*mist*vec3(0.025,0.035,0.075);
 vec3 p=d*320.0;vec3 cell=floor(p);float star=step(0.997,hash(cell));
 float point=pow(max(0.0,1.0-length(fract(p)-0.5)*1.7),5.0);
 color+=star*point*vec3(0.72,0.83,1.0)*2.5;
 COLOR=color;
}
