shader_type spatial;
uniform float wetness=0.0;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 float grit=hash(floor(world.xz*9.0));
 float patches=hash(floor(world.xz/3.0));
 vec2 tile=abs(fract(world.xz/5.0)-0.5);
 float crack=smoothstep(0.478,0.495,max(tile.x,tile.y))*step(0.68,patches);
 ALBEDO=vec3(0.24,0.27,0.26)*(0.82+grit*0.25+patches*0.12)*(1.0-crack*0.22)*(1.0-wetness*0.28);
 ROUGHNESS=0.94-wetness*0.34;
}
