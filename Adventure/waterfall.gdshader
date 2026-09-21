shader_type spatial;
render_mode cull_disabled;
varying vec3 world_pos;
void vertex() {
	world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	VERTEX.z+=sin(VERTEX.x*2.4+TIME*1.8)*0.08*UV.y;
}
void fragment() {
	float streak=sin(UV.x*85.0+sin(UV.x*19.0)*2.0+TIME*0.35)*0.5+0.5;
	float flow=sin(UV.y*34.0-TIME*8.0+UV.x*6.0)*0.5+0.5;
	float foam=smoothstep(0.6,0.98,streak)*0.55+pow(UV.y,5.0)*0.3+flow*0.1;
	ALBEDO=mix(vec3(0.08,0.40,0.43),vec3(0.75,0.90,0.88),foam);
	ROUGHNESS=0.27; SPECULAR=0.65;
}
