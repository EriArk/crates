// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode cull_disabled;
uniform vec4 dye : source_color = vec4(0.17,0.38,0.40,1.0);
uniform vec4 ink : source_color = vec4(0.99,0.85,0.57,1.0);
uniform bool banner=false;
void vertex(){
    if(banner) VERTEX.z += 0.055*UV.y*UV.y*sin(TIME*1.6+MODEL_MATRIX[3].z+UV.x*3.0+UV.y*2.0);
}
void fragment(){
    vec2 uv=UV;
    vec2 p=(uv-vec2(0.5,0.34))*vec2(1.0, banner?2.6:0.23);
    float aa=max(fwidth(p.x),fwidth(p.y));
    float sun=1.0-smoothstep(0.19,0.19+aa,length(p));
    vec2 wave=vec2(fract(uv.x*(banner?2.0:9.0))-0.5,(uv.y-0.88)*(banner?4.8:0.95));
    float arc=abs(length(wave)-0.47);
    float print_wave=(1.0-smoothstep(0.025,0.025+fwidth(arc),arc))*step(uv.y,0.88);
    float hem=1.0-smoothstep(0.014,0.014+fwidth(uv.y),abs(uv.y-0.94));
    float art=max(max(print_wave,hem),banner?sun:0.0);
    ALBEDO=mix(dye.rgb*(0.93+0.07*cos(uv.x*TAU*3.0)),ink.rgb,art*0.93);
    ROUGHNESS=1.0;
}
