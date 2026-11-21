shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 night : source_color = vec4(0.14,0.19,0.29,1.0);
uniform vec4 haze : source_color = vec4(0.33,0.46,0.52,1.0);
uniform vec4 ink : source_color = vec4(0.16,0.29,0.33,1.0);
uniform vec4 gold : source_color = vec4(0.99,0.77,0.48,1.0);
uniform bool waves = false;
void fragment(){
	vec2 uv=vec2(UV.x,1.0-UV.y);
	vec3 col=mix(haze.rgb,night.rgb,smoothstep(0.05,0.98,uv.y));
	vec2 moon=(uv-vec2(0.72,0.68))*vec2(2.05,1.0);
	col=mix(col,gold.rgb,1.0-smoothstep(0.153,0.157,length(moon)));
	float ridge=0.24+0.19*abs(sin(7.0*uv.x+0.3))+0.08*sin(17.0*uv.x);
	col=mix(col,haze.rgb,1.0-smoothstep(ridge,ridge+0.005,uv.y));
	ridge=0.16+0.11*sin(8.0*uv.x+0.8)+0.035*sin(21.0*uv.x);
	col=mix(col,ink.rgb,1.0-smoothstep(ridge,ridge+0.005,uv.y));
	vec2 tile=fract(uv*vec2(11.,5.))-0.5;
	float star=1.0-smoothstep(0.048,0.083,abs(tile.x)+abs(tile.y)*1.1);
	col=mix(col,gold.rgb,star*0.55*step(0.5,uv.y)*smoothstep(0.17,0.21,length(moon)));
	if (waves) {
		vec2 p=vec2(uv.x*9.,uv.y*3.);
		float first=length(vec2(fract(p.x)-0.5,fract(p.y)));
		float second=length(vec2(fract(p.x+0.5)-0.5,fract(p.y+0.5)));
		float arcs=min(abs(first-.42),abs(second-.42));
		col=mix(ink.rgb,haze.rgb,.28+uv.y*.52);
		col=mix(col,gold.rgb,(1.-smoothstep(.012,.029,arcs))*.48);
	}
	ALBEDO=col;
}
