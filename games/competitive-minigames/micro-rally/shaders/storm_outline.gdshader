shader_type spatial;
render_mode unshaded,cull_back,depth_draw_never,depth_test_disabled,fog_disabled;
uniform float strength=0.0;
void vertex(){VERTEX+=NORMAL*0.012;}
void fragment(){ALBEDO=vec3(0.43,0.88,1.0);EMISSION=ALBEDO;ALPHA=strength*pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),2.2);}
