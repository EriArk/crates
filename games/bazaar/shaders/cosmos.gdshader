// SPDX-License-Identifier: GPL-3.0-or-later
shader_type sky;
uniform sampler2D dust : source_color, filter_linear, repeat_disable;

void sky() {
    float longitude = atan(EYEDIR.z, EYEDIR.x) / TAU;
    vec2 uv = vec2(abs(fract(longitude+0.12)*2.0-1.0), 0.59-asin(clamp(EYEDIR.y,-1.0,1.0))*0.6);
    vec3 nebula = texture(dust, clamp(uv,vec2(0.0),vec2(1.0))).rgb;
    COLOR = mix(nebula*1.25,vec3(0.014,0.016,0.044),smoothstep(0.80,1.0,abs(EYEDIR.y)));
}
