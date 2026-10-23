// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 deep_color : source_color = vec4(0.12, 0.53, 0.65, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.37, 0.79, 0.77, 1.0);
uniform vec4 foam_color : source_color = vec4(0.87, 0.97, 0.88, 1.0);
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec2 p = world.xz;
    float a = atan(p.y / 14.2, p.x / 10.7);
    float coast = length(p / vec2(10.7,14.2)) / (1.0 + 0.045*sin(a*3.0+0.4) + 0.025*cos(a*7.0));
    float shallow = 1.0 - smoothstep(1.05,1.85,coast);
    float swell = sin(p.x*0.65 + p.y*0.35 + TIME*0.6) * sin(p.y*0.8 - TIME*0.45);
    vec3 water = mix(deep_color.rgb, shallow_color.rgb, shallow);
    water += swell * 0.018;
    // Two slow, narrow wash lines follow the actual irregular shoreline.
    float wash = sin(coast*37.0 - TIME*1.6 + sin(a*8.0)*0.25);
    float foam = smoothstep(0.88,0.99,wash) * (1.0-smoothstep(1.06,1.28,coast)) * smoothstep(0.98,1.04,coast);
    float ripple = sin(p.x*1.9 + sin(p.y*1.4) + TIME*0.8);
    float fleck = smoothstep(0.992,1.0,ripple) * smoothstep(0.75,1.0,sin(p.y*3.0-TIME*0.5));
    water = mix(water,foam_color.rgb,foam*0.8 + fleck*0.16);
    // A soft horizon without screen/depth textures: works in Mobile and Compatibility.
    water = mix(water,vec3(0.66,0.84,0.85),smoothstep(70.0,350.0,length(p)));
    ALBEDO = water;
}
