shader_type sky;
uniform vec3 zenith : source_color = vec3(0.21,0.46,0.72);
uniform vec3 horizon : source_color = vec3(0.70,0.81,0.87);
uniform vec3 sun_direction = vec3(0.0,0.7,0.7);
uniform float daylight = 1.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) { vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
void sky() {
	vec3 d=normalize(EYEDIR);
	vec3 color=mix(horizon,zenith,pow(max(d.y,0.0),0.48));
	vec2 p=d.xz/max(d.y+0.25,0.12)*2.2+vec2(TIME*0.003,TIME*0.0015);
	float clouds=noise(p)*0.58+noise(p*2.1)*0.28+noise(p*4.3)*0.14;
	float cover=smoothstep(0.52,0.73,clouds)*smoothstep(0.0,0.18,d.y);
	color=mix(color,mix(vec3(0.15,0.22,0.34),vec3(0.97,0.95,0.85),daylight),cover*0.8);
	float sun=smoothstep(0.99955,0.99988,dot(d,normalize(sun_direction)));
	float moon=smoothstep(0.99960,0.99987,dot(d,-normalize(sun_direction)));
	color+=sun*vec3(1.0,0.77,0.4)*daylight+moon*vec3(0.45,0.57,0.78)*(1.0-daylight);
	vec2 stars=vec2(atan(d.z,d.x),asin(d.y))*260.0;
	float star=step(0.996,hash(floor(stars)))*(1.0-smoothstep(0.0,0.12,length(fract(stars)-0.5)));
	color+=star*(1.0-daylight)*(1.0-cover)*smoothstep(0.0,0.2,d.y)*0.9;
	COLOR=mix(vec3(0.06,0.09,0.08),color,smoothstep(-0.15,0.03,d.y));
}
