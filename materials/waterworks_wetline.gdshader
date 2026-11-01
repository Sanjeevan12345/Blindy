shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
uniform float water_height=-6.0;
varying float world_y;
void vertex() { world_y=(MODEL_MATRIX*vec4(VERTEX,1.0)).y; }
void fragment() {
	float above=world_y-water_height;
	float band=(1.0-smoothstep(0.05,0.42,above))*smoothstep(-0.6,-0.3,above);
	ALBEDO=vec3(0.035,0.065,0.06);
	METALLIC=0.0;
	ROUGHNESS=0.22;
	ALPHA=band*0.55;
}
