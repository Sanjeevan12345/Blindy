extends RefCounted
## Shared look, with a different scale and emphasis for each chapter.
const PALETTE := {"orange":"d8752d","yellow":"e2b34d","teal":"377f85","steel":"67717b","green":"6d9b46"}
static func material_style(color: String,metal: float,rust: float,grid: float) -> Dictionary:
	var tint: String="6d9b46" if color=="506e36" else color
	var family := 0
	if grid>0 or color in ["374d56","43535a","344953","67717b"]: family=1
	if metal<0.1: family=2
	return {"tint":tint,"family":family,"metal":metal,"rust":rust}
static func lighting(art: Node3D,chapter: int) -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	art.environment=env
	world.environment=env
	art.add_child(world)
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("163f4b")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("9ebabb")
	env.ambient_light_energy=0.32
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure=1.0
	env.glow_enabled=true
	env.glow_intensity=0.22
	env.glow_bloom=0.02
	env.ssao_enabled=true
	env.ssao_intensity=0.8
	env.volumetric_fog_enabled=true
	env.volumetric_fog_density={1:0.004,2:0.0028,3:0.0019}[chapter]
	env.volumetric_fog_albedo=Color("68a0a9")
	env.volumetric_fog_emission=Color("143b46")
	env.volumetric_fog_emission_energy=0.03
	env.volumetric_fog_length=150
	env.fog_light_color=Color("427b85")
	env.fog_density=0.0018
	var key := DirectionalLight3D.new()
	key.rotation_degrees=Vector3(-48,-32,0)
	key.light_color=Color("ffdaac")
	key.light_energy=1.7
	key.light_angular_distance=3.0
	key.shadow_enabled=true
	key.set_meta("important_shadow",true)
	art.add_child(key)
	art.lamps.append(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(-26,145,0)
	fill.light_color=Color("78b9c2")
	fill.light_energy=0.65
	art.add_child(fill)
	art.lamps.append(fill)
	var pools: Array={1:[Vector3(0,6,2),Vector3(0,7,-24),Vector3(0,8,-64),Vector3(0,7,-112),Vector3(3,7,-146)],2:[Vector3(-16,7,12),Vector3(0,8,-30),Vector3(20,1,-40),Vector3(1,7,-80)],3:[Vector3(0,8,2),Vector3(-32,8,-44),Vector3(38,8,-54),Vector3(0,9,-44),Vector3(0,11,-104),Vector3(-32,7,-10),Vector3(16,7,-10)]}[chapter]
	for i in range(pools.size()):
		var spot := SpotLight3D.new()
		spot.position=pools[i]
		spot.rotation_degrees.x=-90
		spot.light_color=Color("ffc078")
		spot.light_energy=30
		spot.spot_range=23
		spot.spot_angle=65
		spot.spot_attenuation=0.8
		spot.light_size=1.0
		spot.shadow_enabled=i<2
		spot.set_meta("important_shadow",i<2)
		spot.light_volumetric_fog_energy=0.7
		art.add_child(spot)
		art.lamps.append(spot)
	art.palette["window"]=art.emissive("79b0b5",0.7)
	var window_x: float={1:-17.35,2:-34.35,3:-71.35}[chapter]
	var zs: Array={1:[-12,-48,-88,-125],2:[8,-28,-65],3:[-10,-48,-88]}[chapter]
	for z in zs:
		art.box(Vector3(window_x,13,z),Vector3(0.12,9,5),"window")
		for offset in [-2,0,2]: art.box(Vector3(window_x+0.14,13,z+offset),Vector3(0.18,9,0.15),"steel")
	# Atmosphere stays below the route, preserving the playable sightlines.
	var volume := FogVolume.new()
	volume.shape=RenderingServer.FOG_VOLUME_SHAPE_BOX
	volume.position={1:Vector3(0,-10,-73),2:Vector3(0,-18,-33),3:Vector3(0,-11,-48)}[chapter]
	volume.size={1:Vector3(32,14,180),2:Vector3(65,28,125),3:Vector3(48,12,80)}[chapter]
	var fog := FogMaterial.new()
	fog.density=0.014
	fog.albedo=Color("5c9da8")
	fog.emission=Color("153f49")*0.04
	volume.material=fog
	art.add_child(volume)
	art.fog_volumes.append(volume)
