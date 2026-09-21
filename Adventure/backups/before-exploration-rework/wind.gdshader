shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap;
uniform bool has_texture = true;
uniform bool has_normal = false;
uniform vec4 tint : source_color = vec4(1.0);
uniform float strength = 0.12;
uniform float height_scale = 1.0;
uniform float cutoff = 0.35;
void vertex() {
	vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float gust = sin(TIME * 1.2 + dot(p.xz, vec2(0.035, 0.024))) + 0.35 * sin(TIME * 2.7 + p.x * 0.08);
	float tip = pow(clamp(VERTEX.y / height_scale, 0.0, 1.0), 1.8);
	vec3 world_wind = vec3(0.85, 0.0, 0.45) * gust * strength * tip;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * world_wind;
}
void fragment() {
	vec4 color = tint;
	if (has_texture) color *= texture(albedo_texture, UV);
	ALBEDO = color.rgb;
	ALPHA = color.a;
	ALPHA_SCISSOR_THRESHOLD = cutoff;
	ROUGHNESS = 0.94;
	if (has_normal) NORMAL_MAP = texture(normal_texture, UV).rgb;
}
