shader_type spatial;
render_mode cull_disabled, depth_draw_never;
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 tint : source_color = vec4(0.025,0.13,0.14,1.0);
uniform vec3 absorption = vec3(0.64,0.30,0.23);
uniform vec2 surface_dimensions = vec2(48.0,70.0);
uniform float water_height = -6.0;
uniform float water_time = 0.0;
uniform float ripple_strength = 0.07;
uniform float foam_strength = 0.55;
uniform bool maximum_quality = true;
uniform float disturbance = 0.0;
uniform vec2 raft_center = vec2(0.0,-38.0);
uniform vec2 raft_extent = vec2(3.0);
uniform float wake_strength = 0.0;
varying vec3 world_surface;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p), f=fract(p);
	f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float waves(vec2 p) {
	float a=noise(p*0.7+vec2(water_time*0.075,water_time*0.031));
	float b=noise(p*2.3+vec2(-water_time*0.10,water_time*0.062));
	float c=maximum_quality ? noise(p*7.5+vec2(water_time*0.12,-water_time*0.09)) : 0.5;
	return a*0.55+b*0.30+c*0.15;
}
void vertex() {
	vec3 initial=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	VERTEX.y-=0.015;
	if (maximum_quality) VERTEX.y+=(waves(initial.xz)-0.5)*0.025;
	world_surface=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
vec3 view_position(vec2 uv,float d,mat4 inverse_projection) {
	vec4 p=inverse_projection*vec4(uv*2.0-1.0,d,1.0);
	return p.xyz/max(p.w,0.00001);
}
vec2 project_uv(vec3 p,mat4 projection) {
	vec4 q=projection*vec4(p,1.0);
	return q.xy/max(q.w,0.00001)*0.5+0.5;
}
void fragment() {
	vec3 surface_view=(VIEW_MATRIX*vec4(world_surface,1.0)).xyz;
	vec2 p=world_surface.xz;
	float h=waves(p);
	float dx=(waves(p+vec2(0.04,0))-h)/0.04;
	float dz=(waves(p+vec2(0,0.04))-h)/0.04;
	float ring=length((p-raft_center)/max(raft_extent,vec2(0.1)));
	float fill_wave=sin(ring*18.0-water_time*3.0)*exp(-abs(ring-1.3)*1.6)*disturbance;
	float distance_fade=mix(1.0,0.2,smoothstep(12.0,65.0,length(surface_view)));
	vec3 normal_world=normalize(vec3((-dx*ripple_strength-fill_wave*0.025)*distance_fade,1.0,-dz*ripple_strength*distance_fade));
	NORMAL=normalize((VIEW_MATRIX*vec4(normal_world,0.0)).xyz);
	float facing=clamp(dot(normalize(-surface_view),NORMAL),0.0,1.0);
	float fresnel=0.02+0.98*pow(1.0-facing,5.0);
	float original_depth=textureLod(scene_depth,SCREEN_UV,0.0).r;
	vec3 behind=view_position(SCREEN_UV,original_depth,INV_PROJECTION_MATRIX);
	float thickness=original_depth>0.000001 ? clamp(surface_view.z-behind.z,0.0,30.0) : 12.0;
	vec2 offset=NORMAL.xy*0.012*min(thickness,1.0);
	vec2 refract_uv=clamp(SCREEN_UV+offset,vec2(0.002),vec2(0.998));
	float rd=textureLod(scene_depth,refract_uv,0.0).r;
	vec3 refracted_position=view_position(refract_uv,rd,INV_PROJECTION_MATRIX);
	// Reject foreground silhouettes rather than dragging them across the surface.
	if (rd>0.000001 && refracted_position.z>surface_view.z-0.04) refract_uv=SCREEN_UV;
	vec3 transmission=exp(-absorption*thickness);
	vec3 refracted=textureLod(scene_color,refract_uv,0.2).rgb;
	float edge=1.0-smoothstep(0.03,0.25,thickness);
	float breakup=smoothstep(0.38,0.68,noise(p*4.0+vec2(water_time*0.13,0)));
	vec2 delta=abs(p-raft_center)-raft_extent;
	float raft_distance=length(max(delta,vec2(0)))+min(max(delta.x,delta.y),0.0);
	float wake=(1.0-smoothstep(0.03,0.38,abs(raft_distance)))*wake_strength;
	float foam=clamp((edge+max(wake,0.0)*0.4)*breakup*foam_strength,0.0,0.7);
	ALBEDO=mix(tint.rgb*(1.0-transmission),vec3(0.38,0.48,0.44),foam);
	EMISSION=refracted*transmission*(1.0-fresnel)*(1.0-foam);
	METALLIC=0.0;
	SPECULAR=0.25;
	ROUGHNESS=mix(0.12,0.65,foam);
	ALPHA=1.0;
	if (maximum_quality) {
		vec3 direction=normalize(reflect(normalize(surface_view),NORMAL));
		vec3 start=surface_view+NORMAL*0.09;
		float previous=0.12;
		for (int i=0;i<64;i++) {
			float distance_along=mix(0.12,40.0,pow(float(i+1)/64.0,1.45));
			vec3 sample_position=start+direction*distance_along;
			if (sample_position.z>=-0.05) break;
			vec2 uv=project_uv(sample_position,PROJECTION_MATRIX);
			if (any(lessThan(uv,vec2(0.002))) || any(greaterThan(uv,vec2(0.998)))) break;
			float d=textureLod(scene_depth,uv,0.0).r;
			vec3 scene=view_position(uv,d,INV_PROJECTION_MATRIX);
			float gap=scene.z-sample_position.z;
			if (d>0.000001 && gap>0.0 && gap<0.45+distance_along*0.015) {
				float lo=previous, hi=distance_along;
				for (int j=0;j<5;j++) {
					float mid=(lo+hi)*0.5;
					vec3 candidate=start+direction*mid;
					vec2 cuv=project_uv(candidate,PROJECTION_MATRIX);
					float cd=textureLod(scene_depth,cuv,0.0).r;
					if (view_position(cuv,cd,INV_PROJECTION_MATRIX).z>candidate.z) hi=mid; else lo=mid;
				}
				uv=project_uv(start+direction*hi,PROJECTION_MATRIX);
				vec2 border=min(uv,vec2(1.0)-uv);
				float confidence=smoothstep(0.0,0.10,min(border.x,border.y))*(1.0-smoothstep(30.0,40.0,hi));
				RADIANCE=vec4(textureLod(scene_color,uv,0.5).rgb,confidence*(1.0-foam));
				break;
			}
			previous=distance_along;
		}
	}
}
