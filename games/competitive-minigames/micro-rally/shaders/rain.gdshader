// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float rain_time = 0.0;
uniform float anchor_y = 0.0;
uniform float intensity : hint_range(0.0,1.0) = 1.0;
void vertex() {
    // Local 58 m volume: bounded instances, no per-drop nodes or physics.
    float local_y = MODEL_MATRIX[3].y - anchor_y;
    VERTEX.y += mod(local_y + 20.0 - rain_time * 16.0, 20.0) - local_y;
    VERTEX.x += VERTEX.y * 0.12;
}
void fragment() {
    ALBEDO = vec3(0.69, 0.79, 0.84);
    ALPHA = intensity * 0.38 * (1.0 - abs(UV.y * 2.0 - 1.0));
}
