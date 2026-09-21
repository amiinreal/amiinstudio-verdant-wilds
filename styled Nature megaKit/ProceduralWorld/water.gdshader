shader_type spatial;
render_mode cull_disabled;

uniform vec3 deep_color : source_color = vec3(0.075, 0.34, 0.38);
uniform vec3 crest_color : source_color = vec3(0.25, 0.62, 0.61);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float waves = sin(p.x * 0.68 + TIME * 0.65) * sin(p.y * 0.52 - TIME * 0.42);
	float ripples = pow(0.5 + 0.5 * sin(p.x * 1.8 + p.y * 2.1 + waves * 2.0 + TIME), 16.0);
	ALBEDO = mix(deep_color, crest_color, 0.27 + waves * 0.14 + ripples * 0.20);
	ROUGHNESS = 0.28;
	METALLIC = 0.12;
	NORMAL = normalize(NORMAL + vec3(waves * 0.06, ripples * 0.05, 0.0));
}
