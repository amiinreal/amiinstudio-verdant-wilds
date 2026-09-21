shader_type spatial;
render_mode cull_disabled;
uniform sampler2D ground_mask : filter_nearest, repeat_disable;
uniform sampler2D terrain_height : filter_nearest, repeat_disable;
uniform vec3 players[6];
uniform int player_count = 0;
varying vec2 ground_uv;
varying float distance_to_view;
float terrain(vec2 p) {
 vec2 grid=clamp((p+512.0)/4.0,vec2(0.0),vec2(255.999));
 ivec2 cell=ivec2(floor(grid)); vec2 f=fract(grid);
 float a=texelFetch(terrain_height,cell,0).r;
 float b=texelFetch(terrain_height,cell+ivec2(1,0),0).r;
 float c=texelFetch(terrain_height,cell+ivec2(0,1),0).r;
 float d=texelFetch(terrain_height,cell+ivec2(1,1),0).r;
 return f.x+f.y<=1.0 ? a+(b-a)*f.x+(c-a)*f.y : d+(c-d)*(1.0-f.x)+(b-d)*(1.0-f.y);
}
void vertex() {
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float blade_height=p.y-MODEL_MATRIX[3].y;
 p.y=terrain(p.xz)+blade_height-0.025;
 ground_uv=(p.xz+512.0)/1024.0;
 float tip=clamp(blade_height/.4,0.0,1.0);
 p.xz+=vec2(.06,.035)*sin(TIME*1.4+dot(p.xz,vec2(.18,.12)))*tip*tip;
 for(int i=0;i<6;i++) {
  if(i>=player_count) break;
  vec3 away=p-players[i]; float influence=(1.0-smoothstep(.2,1.1,length(away.xz)))*(1.0-smoothstep(1.0,2.0,abs(away.y)));
  p.xz+=normalize(away.xz+vec2(.001))*influence*tip*.3;
  p.y-=influence*tip*.12;
 }
 distance_to_view=length(p-INV_VIEW_MATRIX[3].xyz);
 p.y-=smoothstep(42.0,60.0,distance_to_view)*blade_height;
 VERTEX=(inverse(MODEL_MATRIX)*vec4(p,1.0)).xyz;
 NORMAL=normalize(vec3(0.15,1.0,0.12));
}
void fragment() {
 if(texture(ground_mask,ground_uv).r>.5 || distance_to_view>60.0) discard;
 ALBEDO=COLOR.rgb*.78;
 ROUGHNESS=1.0;
 BACKLIGHT=COLOR.rgb*.25;
}
