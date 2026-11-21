// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
uniform vec4 tint : source_color = vec4(0.5);
uniform bool concrete = false;
uniform float wetness = 0.0;
varying vec3 world;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec2 p=world.xz;
    float detail=mix(noise(p*5.0),0.5,smoothstep(0.3,1.2,length(fwidth(p*5.0))));
    float patches=noise(p*0.18);
    vec3 base=tint.rgb*(0.84+patches*0.22+detail*0.10);
    if (concrete) {
        vec2 seam=abs(fract(p/8.0+0.5)-0.5)*8.0;
        float joint=1.0-smoothstep(0.018,0.045+length(fwidth(p)),min(seam.x,seam.y));
        base*=1.0-joint*0.22;
        // Faded hazard paint along the open terrace edge; never a driving barrier.
        if (world.y>3.8 && world.z>-32.0) {
            float stripe=step(0.5,fract((world.x+world.z)*0.32));
            base=mix(vec3(0.17,0.18,0.15),vec3(0.75,0.55,0.16),stripe)*(0.7+patches*0.3);
        }
    } else {
        float ruts=sin(p.x*1.8+noise(p*0.06)*10.0)*0.5+0.5;
        base*=0.91+ruts*0.09;
    }
    float puddle=smoothstep(0.56,0.72,patches)*wetness;
    ALBEDO=base*(1.0-wetness*0.20);
    ROUGHNESS=mix(0.92,0.24,puddle);
    SPECULAR=mix(0.22,0.45,puddle);
}
