extends Node3D
## Rendering only. Machinery, immersion and save state remain owned by the level.
const STATIC_REFLECTION_LAYER := 1<<18
var level
var probes: Array[ReflectionProbe] = []
var wetlines: Array = []
var spray: Array[GPUParticles3D] = []
var maximum := true
var enabled_view := false

func configure(owner_level: Node3D) -> void:
	level=owner_level
	mark_static(level.world)
	for data in [[Vector3(0,3,-48),Vector3(60,32,86)],[Vector3(38,1,-45),Vector3(14,18,16)]]:
		var probe := ReflectionProbe.new()
		probe.size=data[1]
		probe.position=data[0]
		probe.origin_offset=Vector3(0,3,0)
		probe.box_projection=true
		probe.interior=true
		probe.update_mode=ReflectionProbe.UPDATE_ONCE
		probe.cull_mask=STATIC_REFLECTION_LAYER
		probe.max_distance=100
		add_child(probe)
		probes.append(probe)
	for x in [-24.69,24.69]: make_wetline(Vector3(x,-5,-48),Vector2(70,10),PI/2,0)
	for x in [34.88,41.12]: make_wetline(Vector3(x,-1.5,-45),Vector2(6.4,6),PI/2,1)
	for i in range(2): spray.append(make_spray())
	refresh()

func mark_static(node: Node) -> void:
	if node is RigidBody3D or node is AnimatableBody3D or node is Label3D: return
	if node==level.water or node==level.lock_water or node in level.barriers.values(): return
	if node in level.jet_visuals or node in level.jet_signals or node in level.station_markers.values(): return
	if node is VisualInstance3D: node.layers |= STATIC_REFLECTION_LAYER
	for child in node.get_children(): mark_static(child)

func make_wetline(at: Vector3,size: Vector2,yaw: float,index: int) -> void:
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size=size
	mesh.mesh=quad
	mesh.position=at
	mesh.rotation.y=yaw
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader=preload("res://materials/waterworks_wetline.gdshader")
	mesh.material_override=material
	add_child(mesh)
	wetlines.append({"mesh":mesh,"index":index})

func make_spray() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount=40
	particles.lifetime=1.2
	particles.visibility_aabb=AABB(Vector3(-5,-2,-5),Vector3(10,5,10))
	var process := ParticleProcessMaterial.new()
	process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents=Vector3(2.8,0.02,2.8)
	process.direction=Vector3.UP
	process.spread=35
	process.initial_velocity_min=0.25
	process.initial_velocity_max=0.65
	process.gravity=Vector3(0,-1.6,0)
	process.scale_min=0.45
	process.scale_max=1.0
	var gradient := Gradient.new()
	gradient.set_color(0,Color(0.7,0.85,0.82,0.4))
	gradient.set_color(1,Color(0.7,0.85,0.82,0))
	var texture := GradientTexture1D.new()
	texture.gradient=gradient
	process.color_ramp=texture
	particles.process_material=process
	var quad := QuadMesh.new()
	quad.size=Vector2(0.055,0.055)
	var material := StandardMaterial3D.new()
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
	quad.material=material
	particles.draw_pass_1=quad
	particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.emitting=false
	add_child(particles)
	return particles

func _process(_delta: float) -> void: refresh()

func refresh() -> void:
	if not is_instance_valid(level): return
	maximum=level.factory.quality_high
	enabled_view=level.running and (level.solo or level.role==0)
	var surfaces := [level.water,level.lock_water]
	for i in range(surfaces.size()):
		var mesh: MeshInstance3D=surfaces[i]
		mesh.visible=enabled_view
		var material: ShaderMaterial=mesh.material_override
		var filling: bool=(level.basin_time>0 and level.basin_time<14) if i==0 else (level.lock_time>0 and level.lock_time<8)
		material.set_shader_parameter("maximum_quality",maximum)
		material.set_shader_parameter("water_time",level.clock)
		material.set_shader_parameter("water_height",mesh.position.y)
		material.set_shader_parameter("disturbance",0.7 if filling and maximum else 0.0)
		material.set_shader_parameter("raft_center",Vector2(0,-38) if i==0 else Vector2(38,-45))
		material.set_shader_parameter("wake_strength",(0.6 if filling else 0.08) if maximum else 0.0)
		if spray.size()>i:
			spray[i].position=Vector3(0,mesh.position.y+0.04,-38) if i==0 else Vector3(38,mesh.position.y+0.04,-45)
			spray[i].visible=enabled_view and maximum
			spray[i].emitting=enabled_view and maximum and filling
	for probe in probes: probe.visible=enabled_view
	for item in wetlines:
		item.mesh.visible=enabled_view
		item.mesh.material_override.set_shader_parameter("water_height",surfaces[item.index].position.y)

func _exit_tree() -> void:
	for particles in spray:
		particles.emitting=false
		particles.process_material=null
		particles.draw_pass_1=null
