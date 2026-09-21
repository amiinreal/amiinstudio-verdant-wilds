shader_type spatial;
render_mode cull_disabled, depth_draw_always;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform bool river = false;
varying vec3 world_pos;
void vertex() {
 world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.y+=sin(world_pos.x*0.3+world_pos.z*0.21+TIME*1.1)*0.035;
}
void fragment() {
 vec2 flow=river ? vec2(UV.x*12.0,UV.y-TIME*1.8) : world_pos.xz*0.8+vec2(TIME*0.3,-TIME*0.2);
 float a=sin(flow.y*2.4+sin(flow.x*1.7));
 float b=sin(flow.y*4.7-flow.x*2.1+TIME*0.6);
 float depth=texture(depth_texture,SCREEN_UV).r;
 vec4 scene=INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.0-1.0,depth,1.0);
 float thickness=max(0.0,-scene.z/scene.w+VERTEX.z);
 float fresnel=pow(1.0-max(dot(normalize(NORMAL),normalize(VIEW)),0.0),4.0);
 float shore=(1.0-smoothstep(0.04,0.65,thickness))*smoothstep(-0.2,0.5,a+b*0.3);
 float streak=pow(max(0.0,a*b),7.0)*0.12;
 ALBEDO=mix(vec3(0.12,0.48,0.43),vec3(0.025,0.19,0.24),smoothstep(0.0,5.0,thickness));
 ALBEDO=mix(ALBEDO,vec3(0.68,0.87,0.83),clamp(shore*0.7+streak+fresnel*0.2,0.0,0.85));
 NORMAL_MAP=vec3(0.5+a*0.025,0.5+b*0.022,1.0);
 ROUGHNESS=0.34; SPECULAR=0.7;
 ALPHA=clamp(0.52+thickness*0.12+fresnel*0.2,0.52,0.94);
}
