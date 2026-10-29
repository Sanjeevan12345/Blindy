shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 tint : source_color = vec4(0.15,0.20,0.23,1);
uniform float metalness = 0.7;
uniform float rust_amount = 0.2;
uniform float plate_grid = 0.0;
varying vec3 p;
varying vec3 n;
float hash(vec3 v) { return fract(sin(dot(v,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise(vec3 v) {
	vec3 i=floor(v); vec3 f=fract(v); f=f*f*(3.0-2.0*f);
	return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; n=normalize(MODEL_NORMAL_MATRIX*NORMAL); }
void fragment() {
	float dirt=noise(p*1.9)*0.55+noise(p*7.8)*0.3+noise(p*49.0)*0.15;
	float rust=smoothstep(0.73-rust_amount*0.10,0.84-rust_amount*0.10,dirt);
	float grain=noise(p*170.0);
	vec3 color=tint.rgb*(0.67+0.42*dirt);
	color=mix(color,vec3(0.20,0.082,0.027)*(0.7+dirt),rust*0.8);
	vec2 uv=mix(p.xy,p.xz,step(0.6,abs(n.y)));
	vec2 seam=abs(fract(uv/1.5)-0.5);
	float joint=smoothstep(0.475,0.495,max(seam.x,seam.y))*plate_grid;
	color*=1.0-joint*0.72;
	float scratches=step(0.83,noise(p*vec3(180.0,9.0,140.0)))*0.06;
	ALBEDO=color+scratches;
	METALLIC=metalness*(1.0-rust*0.65);
	ROUGHNESS=clamp(0.55+dirt*0.25+rust*0.15,0.0,1.0);
	NORMAL_MAP=normalize(vec3((grain-0.5)*0.12,(noise(p*150.0+3.0)-0.5)*0.12,1.0))*0.5+0.5;
	NORMAL_MAP_DEPTH=0.35;
}
