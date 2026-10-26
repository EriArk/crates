// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
uniform sampler2D palette : source_color, filter_linear_mipmap;
uniform vec4 paint : source_color = vec4(1.0,0.3,0.03,1.0);
uniform float damage = 0.0;
varying vec3 local;
void vertex(){local=VERTEX;}
void fragment(){
 vec3 base=texture(palette,UV).rgb;
 float painted=step(base.r*1.25,base.g)*step(base.r*1.15,base.b)*step(0.04,base.g);
 base=mix(base,paint.rgb*(0.7+base.g*0.6),painted);
 float grime=(sin(local.x*39.0+sin(local.z*23.0))*sin(local.y*28.0+local.z*11.0))*0.5+0.5;
 float mask=smoothstep(0.65-damage*0.25,0.85,grime)*damage;
 ALBEDO=mix(base,vec3(0.085,0.041,0.016),mask);
 ROUGHNESS=mix(0.48,0.95,mask); METALLIC=0.10;
}
