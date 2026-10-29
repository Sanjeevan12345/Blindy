extends RefCounted
## Stable encounter IDs and route metadata shared by gameplay and traversal tests.
const ENCOUNTERS := [
	{"id":"release", "dock":Vector3(0,0,1), "action":"Release maintenance cradle", "objective":"BOOT BAY / Find EXIT. Drive to the release lever.", "gate":-3.0},
	{"id":"sorting", "dock":Vector3(-3.5,0,-29), "action":"Open sorting gate", "objective":"SORTING AISLE / Weave between scrap stacks. Find the gate console.", "gate":-33.0},
	{"id":"bridge", "dock":Vector3(0,0,-44), "action":"Extend service bridge", "objective":"CONVEYOR GALLERY / Stop at the bridge control console.", "gate":-47.0},
	{"id":"shutter", "dock":Vector3(0,0,-76), "action":"Open conveyor shutter", "objective":"BROKEN CONVEYOR / Jump the training obstacle and gap. Reach the shutter.", "gate":-79.0},
	{"id":"seal", "dock":Vector3(0,0,-101), "action":"Release greenhouse seal", "objective":"LAST GREENHOUSE / Cross the second gap. Follow the green lights.", "gate":-104.0},
	{"id":"pickup", "dock":Vector3(-2,0,-115), "action":"Secure the sapling", "objective":"LAST GREENHOUSE / Retrieve the living specimen."},
	{"id":"power", "dock":Vector3(3,0,-132), "action":"Restore lift power", "objective":"RETURN CATWALK / Carry the sapling to the lift power console.", "gate":-135.0},
	{"id":"departure", "dock":Vector3(3,0.5,-147), "action":"Activate departure", "objective":"SERVICE LIFT / Park inside the lift and activate departure."}
]
const COMPLETE := 8
const SHELF := Vector3(-2,1.24,-116.5)
const LIFT := Vector3(3,0.4,-147)
const JUMPS := [-60.0,-65.0,-86.0]
const GAPS := [Vector2(-65,-67),Vector2(-86,-88)]
const GAP_CHECKPOINTS := [Vector3(0,0.1,-61.6),Vector3(0,0.1,-82.6)]
const ROUTES := [
	[Vector3(0,0,1)],
	[Vector3(3.7,0,-11),Vector3(3.7,0,-19),Vector3(-3.7,0,-20.5),Vector3(-3.7,0,-27),Vector3(-3.5,0,-29)],
	[Vector3(-3.5,0,-37),Vector3(0,0,-40),Vector3(0,0,-44)],
	[Vector3(0,0,-56),Vector3(0,0,-76)],
	[Vector3(0,0,-101)],
	[Vector3(-2,0,-108),Vector3(-2,0,-115)],
	[Vector3(2,0,-115),Vector3(3,0,-122),Vector3(3,0,-132)],
	[Vector3(3,0,-147)]
]

static func docks() -> Array:
	return ENCOUNTERS.map(func(e): return e.dock)

static func route_length() -> float:
	var previous := Vector3(0,0,5)
	var length := 0.0
	for route in ROUTES:
		for point in route:
			length += Vector2(point.x-previous.x,point.z-previous.z).length()
			previous = point
	return length
