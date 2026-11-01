extends "res://scripts/maintenance_art.gd"
func art_level() -> int: return 3
func build_shell() -> void:
	palette["blue"]=surface("36505d",0.4,0.12)
	palette["black"]=surface("132733",0.25,0.02)
	box(Vector3(0,-16,-32),Vector3(160,1,190),"black")
	for x in [-72,76]:
		box(Vector3(x,5,-32),Vector3(1,44,190),"blue")
		for z in range(-116,57,16):
			box(Vector3(x,5,z),Vector3(1.4,46,1.4),"steel")
			rod(Vector3(x-2,-12,z),Vector3(x-2,18,z),0.7,"rust")
			for y in [-7,12,20]: catwalk(Vector3(x-4,y,z),12,3)
	for z in [-112,-72,-32,8,48]:
		box(Vector3(0,27,z),Vector3(150,0.8,0.8),"steel")
func build_route_details() -> void:
	for x in [-25,25]:
		box(Vector3(x,-5,-48),Vector3(0.6,10,72),"steel")
		for z in range(-82,-12,10):
			box(Vector3(x,1,z),Vector3(1,2,1),"yellow")
	for x in [34.7,41.3]:
		box(Vector3(x,-1.5,-45),Vector3(0.35,6,6.4),"steel")
		rod(Vector3(x,-3,-45),Vector3(x,5,-45),0.15,"yellow")
	for at in [Vector3(-32,0,-44),Vector3(38,0,-54)]:
		machine(at+Vector3(3,0,0),2)
		for x in [-3,3]:
			rod(at+Vector3(x,0,-3),at+Vector3(x,9,-3),0.8,"rust")
			pipe_elbow(at+Vector3(x+2,9,-3),2,0.8,PI/2,PI)
	for x in [-35,-24]:
		box(Vector3(x,-1.2,-28),Vector3(9,2,13),"steel")
		box(Vector3(x,-0.16,-28),Vector3(8.5,0.06,12.5),"blue")
	for z in [-8,-18]:
		rod(Vector3(19,0,z),Vector3(19,5,z),0.6,"rust")
		pipe_elbow(Vector3(17,5,z),2,0.6,0,PI/2)
	for at in [Vector3(0,0,40),Vector3(0,0,0),Vector3(-16,0,0),Vector3(-48,0,-18),Vector3(-32,0,-44),Vector3(16,0,-5),Vector3(38,0,-22),Vector3(38,0,-54),Vector3(58,0,-40),Vector3(0,0.6,-44),Vector3(0,0.6,-74),Vector3(0,3.6,-104)]:
		lamp(at+Vector3(2,6,1),true)
		for offset in [-2,2]: box(at+Vector3(offset,-7,0),Vector3(0.4,14,0.4),"steel")
	# Framed gallery: the level controls local lighting and head spotlight.
	for z in range(-26,-9,4):
		for x in [47,53]: box(Vector3(x,2,z),Vector3(0.2,4,0.2),"steel")
		box(Vector3(50,4,z),Vector3(6,0.2,0.3),"steel")
	for x in range(27,51,4):
		box(Vector3(x,4,-10),Vector3(0.2,0.2,6),"steel")
	# Distant city silhouette above the exit.
	for i in range(14):
		box(Vector3(-26+i*4,9+(i%4),-126),Vector3(3,11+(i%4)*2,4),"blue")
func build_greenhouse() -> void: pass
