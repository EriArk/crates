shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled;

uniform float power = 0.0;
varying float along;

void vertex() {
    along = VERTEX.y + 0.5;
    VERTEX.y = along * mix(0.36, 2.05, power);
}

void fragment() {
    float flame = pow(1.0 - along, 1.45);
    ALBEDO = mix(vec3(0.06, 0.56, 0.83), vec3(0.24, 0.88, 0.74), flame);
    float edge = abs(dot(normalize(NORMAL), normalize(VIEW)));
    ALPHA = (0.14 + power * 0.58) * flame * smoothstep(0.0, 0.64, edge);
}
