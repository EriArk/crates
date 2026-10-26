shader_type spatial;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform vec4 mud_dark : source_color = vec4(0.39,0.28,0.18,1.0);
uniform vec4 mud_light : source_color = vec4(0.59,0.45,0.30,1.0);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void fragment(){
 float n=noise(UV*vec2(36,3))*0.55+noise(UV*vec2(150,18))*0.45;
 float rut=pow(abs(sin(UV.x*72.0+noise(UV*vec2(3,0.3))*1.5)),14.0);
 float wet=max(smoothstep(0.64,0.8,noise(UV*vec2(8,0.18))),wetness*0.65);
 ALBEDO=mix(mud_dark.rgb,mud_light.rgb,n)*(1.0-rut*0.28);
 ALBEDO=mix(ALBEDO,mud_dark.rgb*0.75,wet*0.45);
 ALBEDO*=1.0-wetness*0.10;
 ROUGHNESS=mix(0.91,0.22,wet);
 NORMAL_MAP=normalize(vec3((rut-0.5)*0.12,0.0,1.0))*0.5+0.5;
}
