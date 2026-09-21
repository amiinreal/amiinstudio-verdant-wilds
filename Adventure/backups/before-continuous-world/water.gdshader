shader_type spatial;
render_mode cull_disabled;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float wave = sin(world_pos.x * 0.5 + TIME * 0.6) * sin(world_pos.z * 0.6 - TIME * 0.4);
	float foam = pow(0.5 + 0.5 * sin(world_pos.x * 1.6 + world_pos.z * 1.4 + wave + TIME), 20.0);
	ALBEDO = mix(vec3(0.045, 0.22, 0.25), vec3(0.15, 0.43, 0.43), 0.4 + wave * 0.14 + foam * 0.2);
	ROUGHNESS = 0.32;
	METALLIC = 0.1;
}
