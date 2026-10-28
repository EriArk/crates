shader_type spatial;
uniform float wetness=0.0;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 float grain=hash(floor(world.xz*3.0));
 float bank=smoothstep(16.0,48.0,abs(world.x));
 vec3 soil=mix(vec3(0.39,0.31,0.20),vec3(0.26,0.38,0.15),bank);
 float quarry=smoothstep(50.0,85.0,world.x)*(1.0-smoothstep(-50.0,-20.0,world.z));
 soil=mix(soil,vec3(0.47,0.36,0.24),quarry);
 ALBEDO=soil*(0.91+grain*0.16)*(1.0-0.20*wetness);ROUGHNESS=0.95-0.25*wetness;
}
