// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode diffuse_burley;
uniform vec4 tint : source_color = vec4(1.0);
// Turf, sand, timber, stone, foliage. Coordinates are in metres, independent of UVs.
uniform int kind = 0;
uniform vec3 grain_axis = vec3(0.0,0.0,1.0);
uniform bool use_palette = false;
uniform sampler2D palette : source_color, filter_linear;
uniform int obstacle_count = 0;
uniform vec4 obstacles[8];
varying vec3 world;
varying vec3 local;
float hash(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p,p.yzx+33.33);
    return fract((p.x+p.y)*p.z);
}
float noise(vec3 p) {
    vec3 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),
        mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
float filtered_noise(vec3 p) {
    float footprint=max(length(dFdx(p)),length(dFdy(p)));
    return mix(noise(p),0.5,smoothstep(0.35,1.2,footprint));
}
void vertex() { world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; local=VERTEX; }
void fragment() {
    vec3 base=tint.rgb;
    if (use_palette) base*=texture(palette,UV).rgb;
    float broad=noise(world*1.7);
    float fine=filtered_noise(world*95.0);
    float detail=0.0;
    float rough=0.95;
    float micro=0.0;
    if (kind==0) {
        // Short mown fibres, small variations between individual clumps.
        detail=(filtered_noise(world*vec3(110.0,30.0,28.0))-0.5)*0.16+(broad-0.5)*0.065;
        micro=0.035; rough=0.94;
        float contact=1.0-smoothstep(0.0,0.24,min(5.0-abs(world.x),8.0-abs(world.z)));
        for (int i=0;i<8;i++) {
            if (i>=obstacle_count) break;
            vec2 d=max(max(obstacles[i].xy-world.xz,world.xz-obstacles[i].zw),vec2(0.0));
            contact=max(contact,1.0-smoothstep(0.0,0.30,length(d)));
        }
        AO=1.0-contact*0.38; AO_LIGHT_AFFECT=0.25;
    } else if (kind==1) {
        float phase=world.x*19.0+world.z*8.0+sin(world.z*3.0)*0.8;
        float ripples=sin(phase)*(1.0-smoothstep(0.3,1.5,fwidth(phase)));
        detail=(fine-0.5)*0.20+(broad-0.5)*0.10+ripples*0.035;
        micro=0.055;
    } else if (kind==2) {
        vec3 grain=local*22.0;
        grain*=vec3(1.0)-abs(grain_axis)*0.96;
        detail=(filtered_noise(grain)-0.5)*0.24+(broad-0.5)*0.055;
        rough=0.78; micro=0.025;
    } else if (kind==3) {
        detail=(noise(world*4.0)-0.5)*0.19+(filtered_noise(world*42.0)-0.5)*0.10;
        rough=0.88; micro=0.06;
    } else {
        detail=(noise(world*3.5)-0.5)*0.13;
        rough=0.95;
    }
    ALBEDO=base*(1.0+detail);
    ROUGHNESS=clamp(rough+(fine-0.5)*0.09,0.65,1.0);
    SPECULAR=0.22;
    // Filtered, low amplitude surface normals avoid noisy speculars at the horizon.
    vec3 p=world*48.0;
    float weight=1.0-smoothstep(0.2,1.0,max(length(dFdx(p)),length(dFdy(p))));
    vec3 bump=(VIEW_MATRIX*vec4(sin(p.z),0.0,cos(p.x),0.0)).xyz;
    NORMAL=normalize(NORMAL+bump*micro*weight);
}
