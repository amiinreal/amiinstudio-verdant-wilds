shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform vec4 tint : source_color=vec4(0.9,0.94,0.9,0.22);
void vertex() {
	MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
}
void fragment() {
	float radius=length(UV-vec2(0.5))*2.0;
	ALBEDO=tint.rgb*COLOR.rgb;
	ALPHA=tint.a*COLOR.a*(1.0-smoothstep(0.15,1.0,radius));
}
