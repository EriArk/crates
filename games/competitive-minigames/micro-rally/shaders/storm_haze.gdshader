shader_type canvas_item;
uniform float density=0.0;
uniform float clock=0.0;
uniform vec2 focus=vec2(0.5);
uniform float aspect=1.77778;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 float n=noise(UV*vec2(7.0,4.0)+vec2(clock*0.025,-clock*0.014));
 float car_window=smoothstep(0.025,0.075,length((UV-focus)*vec2(aspect,1.0)));
 COLOR=vec4(mix(vec3(0.11,0.18,0.25),vec3(0.24,0.32,0.39),n),density*(0.45+n*0.25)*mix(0.25,1.0,car_window));
}
