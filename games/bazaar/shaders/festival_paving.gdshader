// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
varying vec2 ground;
void vertex(){ground=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;}
void fragment(){
    vec2 tile=ground/vec2(1.2,0.72);
    tile.x+=0.5*mod(floor(tile.y),2.0);
    vec2 edge=min(fract(tile),1.0-fract(tile));
    float aa=max(fwidth(tile.x),fwidth(tile.y));
    float mortar=(1.0-smoothstep(0.008,0.02+aa,min(edge.x,edge.y)))*(1.0-smoothstep(0.2,0.6,aa));
    vec2 id=floor(tile);
    float shade=fract(sin(dot(id,vec2(12.9898,78.233)))*43758.5453);
    vec3 stone=mix(vec3(0.60,0.54,0.47),vec3(0.68,0.62,0.54),shade);
    float r=length(ground);
    float border=abs(r-4.95);
    float trim=1.0-smoothstep(0.19,0.21+fwidth(r),border);
    float lozenge=abs(fract(atan(ground.y,ground.x)*12.0/PI+0.5)-0.5)*2.0+border*6.0;
    vec3 inlay=mix(vec3(0.19,0.45,0.45),vec3(0.90,0.69,0.40),1.0-smoothstep(0.70,0.82,lozenge));
    ALBEDO=mix(stone,inlay,trim)*(1.0-0.16*mortar);
    ROUGHNESS=0.94;
}
