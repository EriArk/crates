shader_type spatial;
uniform float wetness=0.0;
uniform sampler2D road_map : filter_linear_mipmap, repeat_disable;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 float grain=hash(floor(world.xz*3.0));
 float bank=smoothstep(2.0,12.0,world.y);
 vec3 soil=mix(vec3(0.39,0.31,0.20),vec3(0.26,0.38,0.15),bank);
 float quarry=(1.0-smoothstep(-30.0,80.0,world.x))*smoothstep(160.0,260.0,world.z);
 soil=mix(soil,vec3(0.47,0.36,0.24),quarry);
 vec3 paint=texture(road_map,(world.xz-vec2(-482.0,-382.0))/vec2(964.0,764.0)).rgb;
 soil=mix(soil,vec3(0.43,0.32,0.19),paint.g);
 soil=mix(soil,vec3(0.24,0.27,0.26),paint.r);
 ALBEDO=soil*(0.91+grain*0.16)*(1.0-0.20*wetness);ROUGHNESS=0.95-0.25*wetness;
}
