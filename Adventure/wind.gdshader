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
uniform float visibility_start = 0.0;
uniform float visibility_end = 135.0;
uniform bool grass = false;
uniform vec3 players[6];
uniform int player_count = 0;
uniform sampler2D ground_mask : filter_nearest, repeat_disable;
uniform vec2 wind_direction = vec2(0.85,0.45);
varying vec2 ground_uv;
varying float view_distance;
void vertex() {
	vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ground_uv=(MODEL_MATRIX[3].xz+vec2(512.0))/1024.0;
	float gust = sin(TIME * 1.2 + dot(p.xz, vec2(0.035, 0.024))) + 0.35 * sin(TIME * 2.7 + p.x * 0.08);
	float tip = pow(clamp((p.y-MODEL_MATRIX[3].y) / height_scale, 0.0, 1.0), 1.8);
	view_distance=length(p-INV_VIEW_MATRIX[3].xyz);
	vec3 world_wind = vec3(wind_direction.x, 0.0, wind_direction.y) * gust * strength * tip;
	if (grass) {
		for (int i=0; i<6; i++) {
			if (i>=player_count) break;
			vec3 away=p-players[i];
			float influence=(1.0-smoothstep(0.15,1.4,length(away.xz)))*(1.0-smoothstep(1.0,2.0,abs(away.y)));
			world_wind += vec3(normalize(away.xz+vec2(0.001)).x,-0.4,normalize(away.xz+vec2(0.001)).y)*influence*tip*0.45;
		}
	}
	VERTEX += inverse(mat3(MODEL_MATRIX)) * world_wind;
}
void fragment() {
	if (grass && texture(ground_mask,ground_uv).r > 0.5) discard;
	if (view_distance < visibility_start || view_distance > visibility_end) discard;
	vec4 color = tint;
	if (has_texture) color *= texture(albedo_texture, UV);
	ALBEDO = color.rgb;
	ALPHA = color.a;
	ALPHA_SCISSOR_THRESHOLD = cutoff;
	ROUGHNESS = 0.94;
	if (has_normal) NORMAL_MAP = texture(normal_texture, UV).rgb;
}
