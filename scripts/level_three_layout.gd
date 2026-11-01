extends RefCounted
const START := Vector3(0,0.1,40)
const COMPLETE := 1
const ENCOUNTERS := [{"objective":"Restart both pumps, then reach the surface elevator.","action":"Operate nearby machinery"}]
const LIFT := Vector3(0,3.6,-104)
const SHELF := START
const A_OUT := [Vector3.ZERO,Vector3(-16,0,0),Vector3(-32,0,0),Vector3(-32,0,-18),Vector3(-48,0,-18),Vector3(-48,0,-32),Vector3(-48,0,-44),Vector3(-32,0,-44)]
const A_RETURN := [Vector3(-32,0,-44),Vector3(-8,0,-20),Vector3.ZERO]
const B_OUT := [Vector3.ZERO,Vector3(16,0,0),Vector3(16,0,-22),Vector3(32,0,-22),Vector3(38,0,-22),Vector3(38,0,-24),Vector3(38,-3,-42),Vector3(38,-3,-45),Vector3(38,0,-49),Vector3(38,0,-54)]
const B_RETURN := [Vector3(38,0,-54),Vector3(58,0,-54),Vector3(58,0,-26),Vector3(50,0,-26),Vector3(50,0,-10),Vector3(26,0,-10),Vector3(26,0,0),Vector3(16,0,0),Vector3.ZERO]
const FINALE := [Vector3.ZERO,Vector3(6,0,-8),Vector3(6,-5.4,-38),Vector3(0,-5.4,-38),Vector3(0,0.6,-38),Vector3(0,0.6,-44),Vector3(0,0.6,-60),Vector3(0,0.6,-70),Vector3(0,0.6,-84),Vector3(16,0.6,-84),Vector3(16,3.6,-104),LIFT]
const STATIONS := {
	"training":{"at":Vector3.ZERO,"target":40.0,"yaw":0.0},
	"pump_a":{"at":Vector3(-32,0,-44),"target":35.0,"yaw":-PI/2},
	"lock":{"at":Vector3(38,-3,-45),"target":50.0,"yaw":0.0},
	"pump_b":{"at":Vector3(38,0,-54),"target":65.0,"yaw":0.0},
	"basin":{"at":Vector3(0,-5.4,-38),"target":50.0,"yaw":0.0},
	"exit":{"at":LIFT,"target":0.0,"yaw":PI/2},
	"battery":{"at":Vector3(-48,0,-18),"target":0.0,"yaw":PI/2},
	"light_1":{"at":Vector3(50,0,-21),"target":0.0,"yaw":0.0},
	"light_2":{"at":Vector3(32,0,-10),"target":0.0,"yaw":PI/2}}
const CHECKPOINTS := [Vector3(0,0,40),Vector3.ZERO,Vector3(-16,0,0),Vector3(-48,0,-18),Vector3(-32,0,-44),Vector3(16,0,-5),Vector3(16,0,-15),Vector3(38,0,-22),Vector3(38,-3,-41),Vector3(38,0,-54),Vector3(50,0,-26),Vector3(6,-5.4,-38),Vector3(0,0.6,-44),Vector3(0,0.6,-73)]
static func docks() -> Array: return [Vector3.ZERO]
static func length_of(points: Array) -> float:
	var distance := 0.0
	for i in range(points.size()-1): distance+=points[i].distance_to(points[i+1])
	return distance
static func route_length() -> float:
	return 40.0+length_of(A_OUT)+length_of(A_RETURN)+length_of(B_OUT)+length_of(B_RETURN)+length_of(FINALE)
