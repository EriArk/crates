// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode cull_disabled;
uniform bool grass = false;
uniform vec3 meadow_dark : source_color = vec3(0.32,0.57,0.32);
uniform vec3 meadow_light : source_color = vec3(0.48,0.68,0.37);
varying vec3 world;
varying float tip;
varying float detail;

void vertex() {
    vec3 root = MODEL_MATRIX[3].xyz;
    world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
    tip = grass ? UV.y : 0.0;
    detail = 1.0;
    if (grass) {
        // Screen-size fade works for both a wide eye lens and the telephoto overview.
        float depth = max(1.0,-(VIEW_MATRIX * vec4(root,1.0)).z);
        float pixels = 0.18 * length(MODEL_MATRIX[1].xyz) * VIEWPORT_SIZE.y * abs(PROJECTION_MATRIX[1][1]) * 0.5 / depth;
        detail = smoothstep(0.7,2.8,pixels);
        float wind = sin(root.x*0.65+root.z*0.38+TIME*1.1)*0.027 + sin(root.z*1.7-TIME*1.6)*0.009;
        // Transform the shared world wind back into each randomly rotated tuft.
        vec3 local_wind = transpose(mat3(MODEL_MATRIX)) * vec3(wind,0.0,wind*0.45);
        VERTEX += local_wind * tip * tip;
        VERTEX *= detail;
        NORMAL = vec3(0.0,1.0,0.0);
    } else {
        // Soft terrain lighting helps roots blend into the slope below them.
        NORMAL = normalize(mix(NORMAL,vec3(0.0,1.0,0.0),0.65));
    }
}

void fragment() {
    // A blade's back face should be as softly lit as its front, not a dark stripe.
    if (grass) NORMAL = normalize((VIEW_MATRIX * vec4(0.0,1.0,0.0,0.0)).xyz);
    float patch = 0.5 + 0.25*sin(world.x*0.53+world.z*0.31) + 0.25*sin(world.z*0.72-world.x*0.28);
    vec3 turf = mix(meadow_dark,meadow_light,patch);
    // COLOR selects the grassy rings while retaining the original sandy beach.
    float lawn = grass ? 1.0 : smoothstep(0.01,0.08,COLOR.g-COLOR.r);
    ALBEDO = mix(COLOR.rgb,turf,lawn);
    ALBEDO += vec3(0.055,0.065,0.025)*tip*detail;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
