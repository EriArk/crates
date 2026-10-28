shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,fog_disabled;
uniform float clock=0.0;
uniform float flash=0.0;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 float n=noise(world.xz*0.12+vec2(clock*0.12,world.y*0.08-clock*0.09));
 n+=noise(UV*7.0+vec2(clock*0.07,-clock*0.11))*0.45;
 vec2 p=(UV-0.5)*2.0;
 float fade=1.0-smoothstep(0.35,1.0,length(p)+0.18*(n-0.5));
 ALBEDO=mix(vec3(0.09,0.14,0.20),vec3(0.24,0.32,0.39),n)+vec3(0.23,0.36,0.48)*flash;
 ALPHA=fade*smoothstep(0.12,0.95,n)*0.52;
}
