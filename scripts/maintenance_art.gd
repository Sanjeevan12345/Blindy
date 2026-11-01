extends "res://scripts/factory_art.gd"
## Level 2 backdrop: open shaft, not the Level 1 corridor.
func art_level() -> int: return 2

func build_shell() -> void:
	box(Vector3(0,-29,-33),Vector3(78,1,135),"black")
	for side in [-1,1]:
		box(Vector3(side*35,-1,-33),Vector3(1,58,135),"blue")
		for z in range(-90,30,16):
			box(Vector3(side*32,0,z),Vector3(0.8,54,0.8),"steel")
			rod(Vector3(side*30,-25,z+4),Vector3(side*30,24,z+4),0.55,"rust")
			for y in [-18,-10,8,18]:
				catwalk(Vector3(side*30,y,z),12,3)
				machine(Vector3(side*29,y+0.2,z),absi(z+y))
	for z in [-80,-50,-20,10]:
		box(Vector3(0,25,z),Vector3(70,0.7,0.7),"steel")
		for x in [-22,-5,15]:
			for i in range(10):
				var a := i/10.0
				var b := (i+1)/10.0
				rod(Vector3(x,24-4*sin(a*PI),z+a*25),Vector3(x,24-4*sin(b*PI),z+b*25),0.045,"black")
	for z in [-65,-22,16]:
		rod(Vector3(-27,-25,z),Vector3(-27,2,z),0.95,"rust")
		pipe_elbow(Vector3(-24,2,z),3,0.95,PI,PI/2)
		rod(Vector3(-24,5,z),Vector3(-8,5,z),0.95,"rust")

func build_route_details() -> void:
	for spec in [[Vector3(-16,0,14),Vector3(12,0.4,10)],[Vector3(0,0,-30),Vector3(16,0.4,12)],[Vector3(20,-6,-40),Vector3(8,0.4,8)],[Vector3(20,0,-80),Vector3(8,0.4,8)],[Vector3(1,0,-78),Vector3(12,0.4,10)]]:
		var at: Vector3=spec[0]
		var size: Vector3=spec[1]
		# Tower supports disappear down into the teal shaft.
		for dx in [-1,1]:
			for dz in [-1,1]:
				var base := at+Vector3(dx*(size.x*0.5-0.7),0,dz*(size.z*0.5-0.7))
				box(base+Vector3(0,-12,0),Vector3(0.5,24,0.5),"steel")
				for depth in [-4,-9,-14]:
					box(base+Vector3(0,depth,0),Vector3(1.2,0.2,1.2),"rust")
		lamp(at+Vector3(-2,5,0),true)
		box(at+Vector3(0,6.8,0),Vector3(size.x+2,0.3,0.3),"steel")
	for at in [Vector3(-16,4.5,1),Vector3(-6,4.5,1),Vector3(6,4.5,1),Vector3(12,4.5,-9),Vector3(10,-1.5,-20),Vector3(20,-1.5,-20),Vector3(20,-1.5,-34),Vector3(20,1,-57),Vector3(20,4,-72)]:
		lamp(at)
		box(at+Vector3(0,1.8,0),Vector3(6,0.2,0.2),"steel")
	# Two large inactive fan housings alongside the safer service route.
	for x in [-2,6]:
		var center := Vector3(x,1.1,6.3)
		rod(center-Vector3(0,2,0),center+Vector3(0,0.3,0),2.2,"blue")
		rod(center+Vector3(0,0.35,0),center+Vector3(0,0.45,0),1.9,"black")
		for i in range(8):
			var a := TAU*i/8
			rod(center+Vector3(0,0.48,0),center+Vector3(cos(a)*1.9,0.48,sin(a)*1.9),0.06)
			box(center+Vector3(cos(a)*0.9,0.4,sin(a)*0.9),Vector3(1.1,0.10,0.45),"black",Vector3(0,-a,0))
		rod(center+Vector3(0,0.45,0),center+Vector3(0,0.6,0),0.3,"steel")
	# Enclosed arrival and repair landmarks with bevel-like layered frames.
	for pair in [[Vector3(-21,0,14),"paint",-PI/2],[Vector3(1,0,-82),"blue",PI]]:
		var at: Vector3=pair[0]
		var facing: float=pair[2]
		var basis := Basis(Vector3.UP,facing)
		box(at+basis*Vector3(0,2.6,0.4),Vector3(6.5,5.2,1.2),pair[1],Vector3(0,facing,0))
		box(at+basis*Vector3(0,2.3,-0.25),Vector3(4.5,4.6,0.4),"black",Vector3(0,facing,0))
		box(at+basis*Vector3(0,2.3,-0.49),Vector3(3.7,4.2,0.1),"steel",Vector3(0,facing,0))
		box(at+basis*Vector3(0,4.7,-0.55),Vector3(3.8,0.18,0.2),"amber",Vector3(0,facing,0))
		for x in [-2.1,2.1]:
			box(at+basis*Vector3(x,2.2,-0.5),Vector3(0.13,4.3,0.16),"yellow",Vector3(0,facing,0))
	# Freight lift housing and vertical guide rails; openings face the platforms.
	for x in [7.3,12.7]:
		box(Vector3(x,-1.5,-33.3),Vector3(0.4,13,0.4),"paint")
	box(Vector3(10,4.5,-30),Vector3(6,0.4,7),"blue")
	box(Vector3(10,-2,-33.4),Vector3(6,13,0.4),"blue")
	for side in [-1,1]:
		rod(Vector3(10+side*2.4,-8,-33),Vector3(10+side*2.4,4,-33),0.08,"steel")
	for height in [0.0,-6.0]:
		for z in [-32.8,-27.2]:
			box(Vector3(7.2,height+2,z),Vector3(0.5,4,0.55),"paint")
		box(Vector3(7.2,height+4,-30),Vector3(0.55,0.45,6),"blue")
		box(Vector3(6.88,height+3.7,-30),Vector3(0.10,0.18,4.4),"amber")
	for x in [7.2,12.8]:
		box(Vector3(x,-4,-26.8),Vector3(0.55,4,0.5),"paint")
	box(Vector3(10,-2,-26.8),Vector3(6,0.45,0.5),"blue")
	# Green repair terminal.
	box(Vector3(3.5,0.8,-79.5),Vector3(0.8,1.6,0.6),"blue")
	var green := emissive("78d58a",1.5)
	var screen := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size=Vector3(0.65,0.7,0.08)
	screen.mesh=mesh
	screen.material_override=green
	screen.position=Vector3(3.5,1.15,-79.85)
	add_child(screen)

func build_greenhouse() -> void:
	pass

func lamp(at: Vector3,shadow: bool=false) -> void:
	super.lamp(at,shadow)
	lamps[-1].light_energy=7.5
