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
 // Paired ivory coachlines are confined to painted body panels.
 float offset=abs(abs(local.x)-0.32);
 float width=max(0.012,fwidth(local.x));
 float stripe=1.0-smoothstep(0.035,0.035+width,offset);
 base=mix(base,vec3(0.94,0.85,0.64),stripe*painted*0.92);
 float grime=(sin(local.x*39.0+sin(local.z*23.0))*sin(local.y*28.0+local.z*11.0))*0.5+0.5;
 float mask=smoothstep(0.65-damage*0.25,0.85,grime)*damage;
 ALBEDO=mix(base,vec3(0.085,0.041,0.016),mask);
 float dust=1.0-smoothstep(0.06,0.44,local.y);
 ALBEDO=mix(ALBEDO,vec3(0.20,0.14,0.09),dust*(0.08+0.09*grime));
 ROUGHNESS=mix(mix(0.80,0.43,painted),0.95,max(mask,dust*0.56));
 METALLIC=0.12*painted;
}
