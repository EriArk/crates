// SPDX-License-Identifier: GPL-3.0-or-later
shader_type sky;
uniform sampler2D coast : source_color, filter_linear, repeat_disable;
uniform float bearing = 0.0;

void sky() {
    // Reflect the painted strip behind the viewer to close the horizon.
    float longitude = atan(EYEDIR.z, EYEDIR.x) / TAU + bearing;
    float u = abs(fract(longitude) * 2.0 - 1.0);
    float elevation = asin(clamp(EYEDIR.y, -1.0, 1.0));
    float v = clamp(0.91 - elevation * 1.7, 0.0, 1.0);
    vec3 painted = texture(coast, vec2(u, v)).rgb;
    COLOR = mix(painted, vec3(0.12, 0.36, 0.55), smoothstep(0.52, 1.1, elevation));
}
