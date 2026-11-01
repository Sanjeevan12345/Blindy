extends RefCounted
const START := Vector3(-16,0.15,14)
const ENCOUNTERS := [
	{"id":"stabilize","dock":Vector3(-16,0,4),"action":"Acknowledge manual cargo control","objective":"ARRIVAL / Hands: practise J/L balance, then stop at the tutorial console."},
	{"id":"turntable","dock":Vector3(0,0,-30),"action":"Align the turntable with the freight lift","objective":"ROUTE CHOICE / Cross the hanging bridge OR follow the wide service route. Rejoin at the turntable."},
	{"id":"freight","dock":Vector3(10,0,-30),"action":"Descend to the lower maintenance deck","objective":"MACHINERY ISLAND / Board the freight lift and hold E."},
	{"id":"refill","dock":Vector3(20,-6,-40),"action":"Refill water and release the lower gate","objective":"LOWER CATWALK / Follow the U-shaped walkway to the refill console."},
	{"id":"bridge","dock":Vector3(20,0,-77),"action":"Release the final bridge gate","objective":"ASCENT / Climb the long service ramp. Prepare for the final hanging bridge."},
	{"id":"repair","dock":Vector3(1,0,-78),"action":"Repair the sapling stabilizer","objective":"FINAL CROSSING / Cross the short suspension bridge and reach the green repair terminal."}
]
const COMPLETE := 6
const LIFT := Vector3(10,-0.15,-30)
const SHELF := Vector3(1,0,-78) # Interface compatibility; cargo is already carried.
const SHORT_ROUTE := [Vector3(-16,0,1),Vector3(-16,0,-2),Vector3(-5,0,-24),Vector3(0,0,-30)]
const SERVICE_ROUTE := [Vector3(-16,0,1),Vector3(-11,0,1),Vector3(12,0,1),Vector3(12,0,-20),Vector3(4,0,-24),Vector3(0,0,-30)]
const LOWER_ROUTE := [Vector3(10,-6,-27.1),Vector3(10,-6,-17),Vector3(20,-6,-17),Vector3(20,-6,-35),Vector3(20,-6,-40)]
const RAMP_ROUTE := [Vector3(20,-6,-43),Vector3(20,0,-76),Vector3(20,0,-77)]
const FINAL_ROUTE := [Vector3(20,0,-78),Vector3(15,0,-78),Vector3(7,0,-78),Vector3(1,0,-78)]
static func docks() -> Array:
	return ENCOUNTERS.map(func(e): return e.dock)
