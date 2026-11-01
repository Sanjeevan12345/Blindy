extends SceneTree
const SIZE := 1024
func _initialize() -> void: call_deferred("bake")
func save_map(name: String,image: Image) -> void:
	image.save_png("res://materials/textures/"+name+".png")
	image.generate_mipmaps()
	ResourceSaver.save(ImageTexture.create_from_image(image),"res://materials/textures/"+name+".res")
	print("BAKED 1024px seamless mipmapped ",name)
func periodic(noise: FastNoiseLite,x: float,y: float) -> float:
	var a := noise.get_noise_2d(x,y)
	var b := noise.get_noise_2d(x-SIZE,y)
	var c := noise.get_noise_2d(x,y-SIZE)
	var d := noise.get_noise_2d(x-SIZE,y-SIZE)
	return lerpf(lerpf(a,b,x/SIZE),lerpf(c,d,x/SIZE),y/SIZE)*0.5+0.5
func bake() -> void:
	DirAccess.make_dir_recursive_absolute("res://materials/textures")
	var broad := FastNoiseLite.new()
	broad.seed=7162
	broad.frequency=0.008
	broad.fractal_octaves=3
	var fine := FastNoiseLite.new()
	fine.seed=2384
	fine.frequency=0.08
	fine.fractal_octaves=2
	var height := Image.create(SIZE,SIZE,false,Image.FORMAT_RF)
	var maps: Dictionary={}
	for name in ["painted_metal","bare_steel","concrete","grime","wear","surface_roughness"]: maps[name]=Image.create(SIZE,SIZE,false,Image.FORMAT_RGB8)
	for y in range(SIZE):
		for x in range(SIZE):
			var b := periodic(broad,float(x),float(y))
			var f := periodic(fine,float(x),float(y))
			var streak := periodic(broad,float(x),float(y)*0.13)
			maps.painted_metal.set_pixel(x,y,Color.WHITE*(0.68+b*0.25+f*0.07))
			maps.bare_steel.set_pixel(x,y,Color.WHITE*(0.53+b*0.18+f*0.07))
			maps.concrete.set_pixel(x,y,Color.WHITE*(0.48+b*0.25+f*0.18))
			maps.grime.set_pixel(x,y,Color.WHITE*clampf(b*0.5+streak*0.5,0,1))
			maps.wear.set_pixel(x,y,Color.WHITE*smoothstep(0.57,0.72,b*0.8+f*0.2))
			maps.surface_roughness.set_pixel(x,y,Color(0.4+b*0.25,0.55+f*0.2,0.75+f*0.2))
			height.set_pixel(x,y,Color(f*0.8+b*0.2,0,0))
		if y%128==0: await process_frame
	for name in maps: save_map(name,maps[name])
	var normal := Image.create(SIZE,SIZE,false,Image.FORMAT_RGB8)
	var concrete := Image.create(SIZE,SIZE,false,Image.FORMAT_RGB8)
	for y in range(SIZE):
		for x in range(SIZE):
			var dx := height.get_pixel((x+1)%SIZE,y).r-height.get_pixel((x-1+SIZE)%SIZE,y).r
			var dy := height.get_pixel(x,(y+1)%SIZE).r-height.get_pixel(x,(y-1+SIZE)%SIZE).r
			var n := Vector3(-dx*1.7,-dy*1.7,1).normalized()*0.5+Vector3.ONE*0.5
			normal.set_pixel(x,y,Color(n.x,n.y,n.z))
			var cn := Vector3(-dx*5,-dy*5,1).normalized()*0.5+Vector3.ONE*0.5
			concrete.set_pixel(x,y,Color(cn.x,cn.y,cn.z))
		if y%128==0: await process_frame
	save_map("metal_normal",normal)
	save_map("concrete_normal",concrete)
	quit()
