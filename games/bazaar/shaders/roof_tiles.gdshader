// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform vec4 glaze : source_color;
void fragment(){
    vec3 tile=texture(atlas,UV).rgb;
    float enamel=smoothstep(0.05,0.16,tile.g-tile.r);
    ALBEDO=mix(tile,glaze.rgb*(0.67+0.48*tile.g),enamel);
    ROUGHNESS=0.88;
}
