// SPDX-License-Identifier: GPL-3.0-or-later
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float focus_y = 0.52;
uniform float strength = 3.8;

void fragment() {
	// An oval focus area softens all four edges without a cut-out horizontal band.
	// Grow the blur radius continuously, then convert to mip LOD (which is logarithmic).
	// Interpolating LOD directly made the visible blur expand too abruptly near the edges.
	vec2 lens = vec2(SCREEN_UV.x - 0.5, SCREEN_UV.y - focus_y);
	float distance_from_focus = clamp(length(lens) / 0.60, 0.0, 1.0);
	float radius = strength * 2.4 * pow(distance_from_focus, 2.6);
	COLOR = vec4(textureLod(screen_texture, SCREEN_UV, log2(1.0 + radius)).rgb, 1.0);
}
