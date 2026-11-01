shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 tint : source_color = vec4(0.15,0.20,0.23,1);
uniform float metalness = 0.7;
uniform float rust_amount = 0.2;
uniform float plate_grid = 0.0;
uniform sampler2D base_map : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D grime_map : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D wear_map : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_map : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D detail_normal : repeat_enable, filter_linear_mipmap_anisotropic;
uniform bool maximum_quality = true;
uniform int material_family = 0;
varying vec3 p;
varying vec3 n;
vec4 mapped(sampler2D tex,vec3 point,vec3 weights) {
	// Flat faces need only their one projection; curved/bevelled faces blend.
	if (weights.x>0.9999) return texture(tex,point.zy);
	if (weights.y>0.9999) return texture(tex,point.xz);
	if (weights.z>0.9999) return texture(tex,point.xy);
	if (!maximum_quality) {
		if (weights.x>weights.y && weights.x>weights.z) return texture(tex,point.zy);
		if (weights.y>weights.z) return texture(tex,point.xz);
		return texture(tex,point.xy);
	}
	return texture(tex,point.zy)*weights.x+texture(tex,point.xz)*weights.y+texture(tex,point.xy)*weights.z;
}
float hash3(vec3 v) { return fract(sin(dot(v,vec3(127.1,311.7,74.7)))*43758.5453); }
float weather_noise(vec3 v) {
	vec3 i=floor(v),f=fract(v); f=f*f*(3.0-2.0*f);
	return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; n=normalize(MODEL_NORMAL_MATRIX*NORMAL); }
void fragment() {
	vec3 weights=pow(abs(n),vec3(4.0));
	weights/=max(dot(weights,vec3(1.0)),0.0001);
	vec3 q=p/2.5;
	float base=mapped(base_map,q,weights).r;
	float dirt=mapped(grime_map,q*0.38,weights).r;
	float wear=mapped(wear_map,q*0.75,weights).r;
	vec3 rough=mapped(roughness_map,q,weights).rgb;
	vec2 uv=abs(n.y)>0.6 ? p.xz : (abs(n.x)>abs(n.z) ? p.zy : p.xy);
	vec2 seam=abs(fract(uv/1.5)-0.5);
	float joint=smoothstep(0.480,0.495,max(seam.x,seam.y))*plate_grid;
	// Preserve the approved worn-steel look; filter tiny detail with distance.
	float footprint=max(length(dFdx(p)),length(dFdy(p)));
	float fine_fade=1.0-smoothstep(0.008,0.055,footprint);
	float weather=weather_noise(p*1.9)*0.55+weather_noise(p*7.8)*0.3+mix(0.5,weather_noise(p*49.0),fine_fade)*0.15;
	float rust=smoothstep(0.73-rust_amount*0.10,0.84-rust_amount*0.10,weather);
	vec3 color=tint.rgb*(0.67+0.42*weather);
	color*=0.93+base*0.10+(dirt-0.5)*0.025;
	rust=max(rust,wear*rust_amount*0.03);
	color=mix(color,vec3(0.20,0.082,0.027)*(0.7+weather),rust*0.8);
	color*=1.0-joint*0.72;
	float scratches=step(0.83,weather_noise(p*vec3(180.0,9.0,140.0)))*0.045*fine_fade;
	ALBEDO=color+scratches;
	METALLIC=metalness*(1.0-rust*0.65);
	ROUGHNESS=clamp(0.55+weather*0.25+rust*0.15+(rough.r-0.5)*0.06,0.0,1.0);
	vec3 micro=mapped(detail_normal,q,weights).rgb*2.0-1.0;
	NORMAL=normalize((VIEW_MATRIX*vec4(normalize(n+vec3(micro.x,0,micro.y)*0.18),0.0)).xyz);
}
