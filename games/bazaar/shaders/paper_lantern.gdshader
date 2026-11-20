// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
uniform vec4 paper : source_color = vec4(1.0,0.71,0.42,1.0);
void fragment() {
    float latitude=UV.y;
    float phase=latitude*9.0;
    float width=max(fwidth(phase),0.025);
    float rib=(1.0-smoothstep(0.045,0.045+width,abs(fract(phase)-0.5)))*(1.0-smoothstep(0.18,0.62,width));
    float cap=smoothstep(0.09,0.14,min(latitude,1.0-latitude));
    vec3 silk=mix(vec3(0.16,0.12,0.16),paper.rgb*(1.0-0.24*rib),cap);
    ALBEDO=silk; EMISSION=silk*cap*0.38; ROUGHNESS=0.95;
}
