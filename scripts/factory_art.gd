extends Node3D
## Reusable factory kit. Visual geometry is batched; gameplay owns collisions.
var batches: Dictionary = {}
var palette: Dictionary = {}
var environment: Environment
var lamps: Array[Light3D] = []
var quality_high := true
var surface_materials: Array[ShaderMaterial] = []
var fog_volumes: Array[FogVolume] = []

func surface(color: String, metal: float=0.7, rust: float=0.25, grid: float=0.0) -> Material:
	var m := ShaderMaterial.new()
	m.shader = preload("res://materials/factory_surface.gdshader")
	var style := preload("res://scripts/art_profile.gd").material_style(color,metal,rust,grid)
	m.set_shader_parameter("tint",Color(style.tint))
	m.set_shader_parameter("metalness",style.metal)
	m.set_shader_parameter("rust_amount",style.rust)
	m.set_shader_parameter("plate_grid",grid)
	m.set_shader_parameter("material_family",style.family)
	m.set_shader_parameter("maximum_quality",quality_high)
	var base_name: String=["painted_metal","bare_steel","concrete"][style.family]
	var bindings := {"base_map":base_name,"grime_map":"grime","wear_map":"wear","roughness_map":"surface_roughness","detail_normal":"concrete_normal" if style.family==2 else "metal_normal"}
	for binding in bindings:
		m.set_shader_parameter(binding,load("res://materials/textures/"+bindings[binding]+".res"))
	surface_materials.append(m)
	return m

func emissive(color: String, energy: float=2) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color=Color(color)
	m.emission_enabled=true
	m.emission=Color(color)
	m.emission_energy_multiplier=minf(energy,1.8)
	return m

func _ready() -> void:
	palette={"steel":surface("374d56"),"blue":surface("326271",0.65,0.45),"rust":surface("825032",0.65,0.7),"black":surface("202a30"),"paint":surface("a77b3d"),"floor":surface("43535a",0.7,0.3,1),"yellow":surface("bc914b"),"soil":surface("303329",0,0.7),"leaf":surface("506e36",0,0),"amber":emissive("ffb64c",3.5),"cyan":emissive("54bbc9",1.5)}
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color=Color("547c39")
	leaf.roughness=0.8
	leaf.cull_mode=BaseMaterial3D.CULL_DISABLED
	palette["leaf"]=leaf
	setup_lighting()
	build_shell()
	build_route_details()
	build_greenhouse()
	flush()

func box(at: Vector3, size: Vector3, key: String, rotation: Vector3=Vector3.ZERO) -> void:
	var batch_key := key+"_box"
	if batch_key not in batches:
		batches[batch_key]={"mesh":BoxMesh.new(),"material":palette[key],"transforms":[]}
	batches[batch_key].transforms.append(Transform3D((Basis.from_euler(rotation)*Basis.from_scale(size)),at))

func rod(a: Vector3,b: Vector3,radius: float,key: String="steel") -> void:
	var batch_key := key+"_rod"
	if batch_key not in batches:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius=0.5
		cylinder.bottom_radius=0.5
		cylinder.height=1
		cylinder.radial_segments=12
		batches[batch_key]={"mesh":cylinder,"material":palette[key],"transforms":[]}
	var direction := (b-a).normalized()
	var basis := Basis.IDENTITY
	if direction.dot(Vector3.UP)< -0.999:
		basis=Basis(Vector3.RIGHT,PI)
	elif direction.dot(Vector3.UP)<0.999:
		basis=Basis(Quaternion(Vector3.UP,direction))
	batches[batch_key].transforms.append(Transform3D((basis*Basis.from_scale(Vector3(radius*2,a.distance_to(b),radius*2))),(a+b)*0.5))

func pipe_elbow(center: Vector3,radius: float,tube: float,start: float,end: float) -> void:
	for i in range(12):
		var a := lerpf(start,end,i/12.0)
		var b := lerpf(start,end,(i+1)/12.0)
		rod(center+Vector3(cos(a)*radius,sin(a)*radius,0),center+Vector3(cos(b)*radius,sin(b)*radius,0),tube,"rust")

func flush() -> void:
	for data in batches.values():
		var chunks: Dictionary={}
		for transform in data.transforms:
			var cell := Vector2i(floori(transform.origin.x/24),floori(transform.origin.z/24))
			if cell not in chunks: chunks[cell]=[]
			chunks[cell].append(transform)
		for cell in chunks:
			var origin := Vector3(cell.x*24,0,cell.y*24)
			var mm := MultiMesh.new()
			mm.transform_format=MultiMesh.TRANSFORM_3D
			mm.mesh=data.mesh
			mm.instance_count=chunks[cell].size()
			for i in range(mm.instance_count):
				var transform: Transform3D=chunks[cell][i]
				transform.origin-=origin
				mm.set_instance_transform(i,transform)
			var node := MultiMeshInstance3D.new()
			node.multimesh=mm
			node.material_override=data.material
			node.position=origin
			add_child(node)
	batches.clear()

func art_level() -> int: return 1

func setup_lighting() -> void:
	preload("res://scripts/art_profile.gd").lighting(self,art_level())

func lamp(at: Vector3, shadow: bool=false) -> void:
	box(at,Vector3(1.0,0.18,0.65),"black")
	box(at+Vector3(0,-0.11,0),Vector3(0.77,0.035,0.44),"amber")
	rod(at+Vector3(0,0.1,0),at+Vector3(0,1.8,0),0.035)
	var light := OmniLight3D.new()
	light.position=at+Vector3(0,-0.35,0)
	light.light_color=Color("ffb35c")
	light.light_energy=4.5
	light.omni_range=10
	light.omni_attenuation=1.4
	light.shadow_enabled=shadow
	light.set_meta("important_shadow",shadow)
	light.light_volumetric_fog_energy=1.2
	add_child(light)
	lamps.append(light)

func catwalk(at: Vector3,length: float,width: float=3) -> void:
	box(at,Vector3(width,0.22,length),"floor")
	for side in [-1,1]:
		box(at+Vector3(side*width*0.5,0.9,0),Vector3(0.06,0.07,length),"steel")
		for z in range(int(-length*0.5),int(length*0.5)+1,3):
			rod(at+Vector3(side*width*0.5,0,z),at+Vector3(side*width*0.5,0.9,z),0.04)
		box(at+Vector3(side*(width*0.5-0.13),0.13,0),Vector3(0.10,0.02,length),"yellow")

func machine(at: Vector3, variation: int=0) -> void:
	box(at+Vector3(0,0.9,0),Vector3(2.5,1.8,2),"blue" if variation%2 else "paint")
	box(at+Vector3(0,1,-1.02),Vector3(1.9,1.25,0.10),"black")
	for x in [-0.7,-0.35,0,0.35,0.7]:
		box(at+Vector3(x,1,-1.10),Vector3(0.09,0.8,0.08),"steel")
	for x in [-1.0,1.0]:
		for y in [0.25,1.55]:
			rod(at+Vector3(x,y,-1.02),at+Vector3(x,y,-1.12),0.06,"rust")
	rod(at+Vector3(-0.9,1.8,0),at+Vector3(-0.9,2.8,0),0.12,"rust")
	box(at+Vector3(0.65,1.5,-1.12),Vector3(0.17,0.06,0.04),"cyan")

func build_shell() -> void:
	# Deep shaft and layered background platforms imply a much larger facility.
	box(Vector3(0,-12,-73),Vector3(50,0.6,180),"black")
	for side in [-1,1]:
		box(Vector3(side*18,7,-73),Vector3(1,38,180),"blue")
		for z in range(-154,12,12):
			box(Vector3(side*14,5,z),Vector3(0.8,30,0.8),"steel")
			box(Vector3(side*17,4,z),Vector3(0.3,6,7),"rust")
			for y in [-5,7,15]:
				catwalk(Vector3(side*12,y,z),10,3)
				box(Vector3(side*12,y-1,z),Vector3(4,0.25,0.25),"rust",Vector3(0,0,side*0.4))
			rod(Vector3(side*15,-8,z+2),Vector3(side*15,16,z+2),0.32,"rust")
			for y in range(-5,16,4):
				rod(Vector3(side*15,y,z+2),Vector3(side*15,y+0.18,z+2),0.42,"steel")
			machine(Vector3(side*10,-5,z),absi(z))
			if z%24== -10 or z%24==0:
				lamp(Vector3(side*11,11,z))
	for z in range(-150,10,16):
		box(Vector3(0,16,z),Vector3(34,0.7,0.5),"steel")
		catwalk(Vector3(0,10,z),3,26)
		for x in [-8,8]:
			rod(Vector3(x,16,z),Vector3(x,10,z),0.055,"black")
		# Loose service cables sag between roof girders.
		for offset in [-1.0,0.0,1.0]:
			for i in range(8):
				var a := i/8.0
				var b := (i+1)/8.0
				rod(Vector3(-12+24*a,14-sin(a*PI)*2,z+offset),Vector3(-12+24*b,14-sin(b*PI)*2,z+offset),0.025,"black")
	# Giant pipe bends frame views without obstructing the route.
	for z in [-18,-58,-96,-136]:
		rod(Vector3(8,-8,z),Vector3(8,2,z),0.65,"rust")
		pipe_elbow(Vector3(10,2,z),2,0.65,PI,PI/2)
		rod(Vector3(10,4,z),Vector3(17,4,z),0.65,"rust")

func build_route_details() -> void:
	for z in range(-150,8,3):
		for x in [-5.65,5.65]:
			box(Vector3(x,0.018,z),Vector3(0.32,0.022,1.0),"yellow",Vector3(0,0.35,0))
			for offset in [-0.18,0.18]:
				rod(Vector3(x+offset,0.01,z),Vector3(x+offset,0.035,z),0.025,"steel")
	for z in range(-148,6,10):
		lamp(Vector3(-3 if z%20==2 else 3,4.8,z),z in [-148,-98,-48,2])
		for side in [-1,1]:
			machine(Vector3(side*8,0,z),absi(z))
			box(Vector3(side*5.9,1.1,z),Vector3(0.24,2.2,0.24),"steel")
			box(Vector3(side*5.9,1.6,z),Vector3(0.30,0.35,0.32),"amber")
	# Conveyor roller beds and hanging maintenance claws off the walkable path.
	for z in [-12,-30,-42,-58,-76,-90]:
		box(Vector3(-8,0.65,z),Vector3(3,0.25,6),"blue")
		for i in range(10):
			rod(Vector3(-9.3,0.9,z-2.7+i*0.6),Vector3(-6.7,0.9,z-2.7+i*0.6),0.12,"steel")
		machine(Vector3(-8,1,z),absi(z))
		rod(Vector3(-7,10,z),Vector3(-7,6,z),0.065,"black")
		rod(Vector3(-7,6,z),Vector3(-6.4,4.5,z),0.20,"paint")
		for s in [-1,1]:
			rod(Vector3(-6.4,4.5,z),Vector3(-6.4+s*0.6,3.8,z),0.12,"paint")
			rod(Vector3(-6.4+s*0.6,3.8,z),Vector3(-6.4+s*0.3,3.5,z),0.10,"black")
	# Exit frame and a warm focal point at the far end.
	for x in [0,6]:
		box(Vector3(x,3,-150.5),Vector3(0.55,6,0.8),"paint")
	box(Vector3(3,6,-150.5),Vector3(6.5,0.6,0.8),"paint")
	lamp(Vector3(3,5.5,-149),true)
	box(Vector3(3,3,-151),Vector3(5.5,6,0.3),"steel")

func build_greenhouse() -> void:
	var foliage := preload("res://scripts/cinematic_kit.gd").new()
	foliage.art=self
	for x in [-5.5,5.5]:
		for z in [-105,-110,-115,-120]:
			box(Vector3(x,2.5,z),Vector3(0.16,5,0.16),"steel")
		box(Vector3(x,5,-112.5),Vector3(0.18,0.18,16),"steel")
	for z in [-105,-110,-115,-120]:
		box(Vector3(0,5,z),Vector3(11,0.18,0.18),"steel")
	for side in [-1,1]:
		for z in range(-119,-104,2):
			box(Vector3(side*4.6,0.4,z),Vector3(1.4,0.8,1.7),"soil")
			for i in range(3):
				var at := Vector3(side*4.6+(i-1)*0.25,0.8,z)
				rod(at,at+Vector3(0,0.65,0),0.025,"leaf")
				foliage.leaf(at+Vector3(0.12,0.4,0),Vector3(0.42,0.42,0.7),Vector3(0,0,0.5))
				foliage.leaf(at+Vector3(-0.12,0.55,0),Vector3(0.42,0.42,0.7),Vector3(0,0,-0.5))
	var green_light := OmniLight3D.new()
	green_light.position=Vector3(0,3,-113)
	green_light.light_color=Color("c6de9a")
	green_light.light_energy=3
	green_light.omni_range=12
	add_child(green_light)

func set_quality(high: bool) -> void:
	quality_high=high
	environment.volumetric_fog_enabled=high
	environment.fog_enabled=not high
	environment.ssao_enabled=high
	for volume in fog_volumes: volume.visible=high
	for material in surface_materials: material.set_shader_parameter("maximum_quality",high)
	for light in lamps:
		light.shadow_enabled=high and bool(light.get_meta("important_shadow",false))
