shader_type spatial;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform vec4 mud_dark : source_color = vec4(0.39,0.28,0.18,1.0);
uniform vec4 mud_light : source_color = vec4(0.59,0.45,0.30,1.0);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void fragment(){
 float grain=noise(UV*vec2(68.0,7.0));
 float patch=noise(UV*vec2(8.0,0.22));
 float meander=sin(UV.y*0.048)*0.022+sin(UV.y*0.13)*0.009;
 float across=abs(UV.x-0.5-meander);
 float rut=1.0-smoothstep(0.018,0.064,abs(across-0.13));
 float packed=1.0-smoothstep(0.25,0.42,across);
 float verge=smoothstep(0.38,0.50,across+0.025*(patch-0.5));
 vec3 clay=mix(mud_dark.rgb,mud_light.rgb,0.23+0.30*grain+0.27*patch);
 vec3 base=clay*(1.0+packed*0.14-rut*(0.14+wetness*0.12));
 base=mix(base,mud_light.rgb*(0.76+grain*0.25),verge*0.72);
 // Churned water collects in the wheel paths before the compacted shoulder.
 float water=wetness*smoothstep(0.24,0.82,patch+rut*0.25);
 float checker=mod(floor(UV.x*16.0)+floor(UV.y*1.6),2.0);
 float stripe=(1.0-smoothstep(1.19,1.25,UV.y))*step(0.02,UV.x)*step(UV.x,0.98);
 vec3 chalk=mix(mud_dark.rgb*0.65,vec3(0.85,0.77,0.59),checker);
 base=mix(base,chalk,stripe*(0.75+grain*0.15));
 ALBEDO=base*(1.0-water*0.36);
 ROUGHNESS=mix(0.94,0.29,water);
 SPECULAR=mix(0.21,0.53,water);
}
