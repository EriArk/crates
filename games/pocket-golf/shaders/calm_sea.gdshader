// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode unshaded, cull_disabled;
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    float coast = length(world.xz / vec2(10.7, 14.2));
    vec3 water = mix(vec3(0.37,0.79,0.77), vec3(0.12,0.53,0.65), smoothstep(1.0,1.85,coast));
    ALBEDO = mix(water, vec3(0.66,0.84,0.85), smoothstep(70.0,350.0,length(world.xz)));
}
