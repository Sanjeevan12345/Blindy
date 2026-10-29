shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 paint_color : source_color = vec4(0.88, 0.43, 0.08, 1.0);
uniform float wear = 0.35;
varying vec3 local_position;
varying vec3 local_normal;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.17, 0.31, 0.73));
	p *= 19.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i+vec3(1,0,0)),f.x),
		mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),
		mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),
		mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
}
void fragment() {
	vec3 p = local_position;
	float broad = noise(p * 18.0);
	float grain = noise(p * 210.0);
	vec3 n = abs(normalize(local_normal));
	float edge = smoothstep(0.01, 0.22, 1.0 - max(n.x, max(n.y, n.z)));
	float chips = smoothstep(0.72 - wear * 0.05, 0.79 - wear * 0.05,
		broad * 0.65 + grain * 0.10 + edge * 0.25);
	float scratch = step(0.88, noise(p * vec3(280.0, 13.0, 190.0))) * 0.3;
	vec3 rust = mix(vec3(0.105, 0.085, 0.068), vec3(0.34, 0.20, 0.10), grain);
	vec3 paint = paint_color.rgb * (0.82 + 0.18 * broad) * (0.94 + grain * 0.06);
	ALBEDO = mix(paint, rust, clamp(chips + scratch * wear, 0.0, 1.0));
	METALLIC = mix(0.30, 0.72, chips);
	ROUGHNESS = mix(0.48, 0.83, max(chips, 1.0 - broad));
}
