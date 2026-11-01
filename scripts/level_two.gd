extends "res://scripts/level_one.gd"
## Handle With Care: two routes rejoin before a required vertical loop.
var bridges: Array[AnimatableBody3D] = []
var wave_time := 0.0
var turn_time := 3.0
var freight_time := 4.0
var turning := false
var riding := false
var turn_start_heading := 0.0
var balance_practiced := false
var checkpoint_water := 100.0
var route_taken := ""
var lower_gate: Node3D
var final_gate: Node3D
var balance_label: Label
var balance_meter: ProgressBar

func _init() -> void:
	Layout=preload("res://scripts/level_two_layout.gd")
	DOCKS=Layout.docks()
	OBJECTIVES=Layout.ENCOUNTERS.map(func(e): return e.objective)+["Stabilizer repaired. Host: press N for Level 3 — Waterworks."]
	ACTIONS=Layout.ENCOUNTERS.map(func(e): return e.action)
	level_number=2
	level_title="HANDLE WITH CARE"
	checkpoint=Layout.START
	checkpoint_stage=0
	checkpoint_cargo=true
	cargo=true

func _ready() -> void:
	super._ready()
	# These indicators are private to hands, except in the combined solo test.
	balance_label=text_label(hud,"",19)
	balance_label.position=Vector2(760,550)
	balance_meter=ProgressBar.new()
	balance_meter.position=Vector2(760,610)
	balance_meter.custom_minimum_size=Vector2(330,18)
	balance_meter.show_percentage=false
	hud.add_child(balance_meter)
	ignore_hud_mouse(hud)

func platform(at: Vector3,size: Vector2) -> Node3D:
	return block(at-Vector3(0,0.18,0),Vector3(size.x,0.36,size.y),"344953")

func walkway(a: Vector3,b: Vector3,width: float=5.0,rails: bool=true) -> Node3D:
	var direction := (b-a).normalized()
	var z_axis := -direction
	var x_axis := Vector3.UP.cross(z_axis).normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	var basis := Basis(x_axis,y_axis,z_axis)
	var length := a.distance_to(b)
	var floor_body := block((a+b)*0.5-y_axis*0.18,Vector3(width,0.36,length+0.18),"344953")
	floor_body.basis=basis
	if rails:
		for side in [-1,1]:
			var trim := maxf(0.1,length-width*1.2)
			var rail := block((a+b)*0.5+basis*Vector3(side*width*0.5,0.65,0),Vector3(0.12,1.3,trim),"52646d")
			rail.basis=basis
			factory.rod((a+b)*0.5+basis*Vector3(side*width*0.5,1.25,-trim*0.5),(a+b)*0.5+basis*Vector3(side*width*0.5,1.25,trim*0.5),0.04,"yellow")
	return floor_body

func hanging_bridge(a: Vector3,b: Vector3,phase: float) -> void:
	var deck := preload("res://scripts/suspension_bridge.gd").new()
	world.add_child(deck)
	deck.build(a,b,factory,phase)
	bridges.append(deck)

func build_world() -> void:
	world=Node3D.new()
	world.name="MaintenanceShaft"
	add_child(world)
	factory=preload("res://scripts/maintenance_art.gd").new()
	world.add_child(factory)
	platform(Vector3(-16,0,14),Vector2(12,10))
	walkway(Vector3(-16,0,9),Vector3(-16,0,1),5)
	platform(Vector3(-16,0,1),Vector2(8,6))
	hanging_bridge(Vector3(-16,0,-2),Vector3(-5,0,-24),0)
	var service: Array=Layout.SERVICE_ROUTE
	for i in range(service.size()-1):
		walkway(service[i],service[i+1],5)
	for corner in [Vector3(12,0,1),Vector3(12,0,-20)]:
		platform(corner,Vector2(6,6))
	platform(Vector3(0,0,-30),Vector2(16,12))
	# Turntable has a flush, continuous deck: its ring turns without floor seams.
	var turntable := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius=3
	disk.bottom_radius=3
	disk.height=0.04
	disk.radial_segments=64
	turntable.mesh=disk
	turntable.position=Vector3(0,0.025,-30)
	turntable.material_override=material("a98449")
	world.add_child(turntable)
	bridge=turntable # Reuse the presentation handle for the turning marker ring.
	for i in range(12):
		var angle := TAU*i/12
		factory.box(Vector3(sin(angle)*2.8,0.06,-30+cos(angle)*2.8),Vector3(0.26,0.03,0.12),"cyan",Vector3(0,angle,0))
	lift=Node3D.new()
	lift.position=Layout.LIFT
	world.add_child(lift)
	block(Vector3.ZERO,Vector3(5,0.3,6),"4c766f",true,lift)
	lift_gate=block(Vector3(0,0.9,3),Vector3(5,1.8,0.15),"d1a460",true,lift)
	lift_gate.visible=false
	lift_gate.process_mode=Node.PROCESS_MODE_DISABLED
	walkway(Vector3(7.5,0,-30),Vector3(5,0,-30),4,false)
	var lower: Array=Layout.LOWER_ROUTE
	for i in range(lower.size()-1):
		walkway(lower[i],lower[i+1],5)
	for corner in [Vector3(10,-6,-17),Vector3(20,-6,-17),Vector3(20,-6,-40)]:
		platform(corner,Vector2(8,8))
	walkway(Vector3(20,-6,-40),Vector3(20,-6,-43),5)
	walkway(Vector3(20,-6,-43),Vector3(20,0.05,-76.1),5)
	platform(Vector3(20,0,-80),Vector2(8,8))
	hanging_bridge(Vector3(16.1,0,-78),Vector3(6.9,0,-78),1.7)
	platform(Vector3(1,0,-78),Vector2(12,10))
	lower_gate=block(Vector3(20,-3.5,-43.5),Vector3(5,5,0.15),"3a6975")
	final_gate=block(Vector3(15.9,2.5,-78),Vector3(0.15,5,3.5),"3a6975")
	# Visible gate structure, not invisible barriers.
	for gate in [lower_gate,final_gate]:
		gate.get_child(0).material_override=material("3d7279")
	sign_at("ARRIVAL / 02",Vector3(-20.25,4.2,14),"efbf75",PI/2)
	sign_at("SHORT ROUTE\nNARROW BRIDGE",Vector3(-18,2.8,-1),"e8bb77")
	sign_at("SERVICE ROUTE →\nFANS OFFLINE",Vector3(-9,2.8,3.0),"e8bb77")
	sign_at("TURN / THEN FREIGHT",Vector3(0,3.8,-33))
	sign_at("LOWER DECK / REFILL",Vector3(20,-2.6,-42))
	sign_at("REPAIR",Vector3(1,4.3,-81.4),"a4e5a7")
	shelf_plant=Node3D.new() # Level 2 starts with the carried sapling.
	world.add_child(shelf_plant)
	for i in range(DOCKS.size()):
		var at: Vector3=DOCKS[i]
		var marker := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius=1.15
		ring.outer_radius=1.3
		marker.mesh=ring
		marker.position=at+Vector3(0,0.04,0)
		marker.scale.y=0.10
		marker.material_override=material("50aeb8",1.0)
		world.add_child(marker)
		dock_markers.append(marker)
		if i!=2:
			var side := Vector3(0,0,1.7) if i in [1,5] else Vector3(1.7,0,0)
			block(at+side+Vector3(0,0.7,0),Vector3(0.4,1.4,0.45),"4d6971")
			block(at+side+Vector3(0,1.45,0),Vector3(0.55,0.2,0.55),"68d8df",false)
	factory.flush()
	preload("res://scripts/cinematic_kit.gd").new().install(self)
	robot=preload("res://scripts/robot.gd").new()
	robot.name="SharedRobot"
	add_child(robot)
	robot.kill_height= -22
	robot.auto_stabilize=false
	robot.teleport(Layout.START)
	robot.checkpoint_position=Layout.START
	robot.fell.connect(restore_checkpoint)
	robot.cradle.visible=true
	robot.set_simulation(false)
	camera=Camera3D.new()
	camera.current=true
	camera.fov=78
	camera.near=0.05
	add_child(camera)

func begin_session() -> void:
	super.begin_session()
	announce("Stabilizer fault. Hands: J/L counterbalance, Shift brace. Wheel: slow before turning.")
	if DisplayServer.get_name()!="headless":
		get_window().title="Blindy — Level 2 — "+("Solo test" if solo else ROLE_NAMES[role])

func local_input() -> Dictionary:
	var data := super.local_input()
	data.balance=pressed(KEY_J)-pressed(KEY_L)
	return data

func apply_input(input_role: int,data: Dictionary) -> void:
	super.apply_input(input_role,data)
	if input_role==1:
		var balance := float(data.get("balance",0))
		if is_finite(balance):
			robot.balance_input=clampf(balance,-1,1)
			balance_practiced=balance_practiced or absf(balance)>0.1

func can_interact() -> bool:
	return super.can_interact() and absf(robot.position.y-DOCKS[stage].y)<0.5 and not turning and not riding and (stage!=0 or balance_practiced)

func hold_duration() -> float:
	return 2.0 if encounter_id()=="repair" else 0.8

func interaction_hint() -> String:
	if completed:
		return "LEVEL 2 COMPLETE — HANDLE WITH CARE\nStabilizer online. Host: press N for Level 3 — Waterworks."
	if turning:
		return "Turntable aligning. Keep the cargo steady."
	if riding:
		return "Freight lift descending. Lower deck is six metres below."
	if stage==0 and not balance_practiced:
		return "HANDS: practise J/L to steady the cradle, then drive to the cyan console."
	if stage<Layout.COMPLETE and absf(robot.position.y-DOCKS[stage].y)>1:
		return "Follow the marked route to the correct deck."
	return super.interaction_hint()

func advance_objective() -> void:
	if not can_interact():
		return
	var id := encounter_id()
	stage+=1
	hold_progress=0
	play_tone()
	match id:
		"stabilize":
			save_checkpoint(Vector3(-16,0.1,1),stage,true)
			announce("Choose a route: short hanging bridge, or longer service walkway. Both reach the turntable.")
		"turntable":
			save_checkpoint(Vector3(0,0.1,-30),stage,true,-PI/2)
			turning=true
			turn_time=0
			turn_start_heading=robot.heading()
			robot.set_simulation(false)
			announce("Turntable aligning with the freight lift.")
		"freight":
			riding=true
			freight_time=0
			robot.set_simulation(false)
			announce("Freight clearance granted. Descending to the lower catwalk.")
		"refill":
			robot.water=100
			save_checkpoint(Vector3(20,-5.9,-40),stage,true)
			announce("Water replenished. Lower gate open. Follow the ramp back toward the repair station.")
		"bridge":
			save_checkpoint(Vector3(20,0.1,-78),stage,true,PI/2)
			announce("Final bridge released. Align before crossing. Hands: brace on the narrow deck.")
		"repair":
			robot.auto_stabilize=true
			robot.water=100
			robot.cargo_tilt=0
			robot.finished=true
			robot.set_simulation(false)
			completed=true
			announce("Stabilizer online. One small life, a little further.")
			if not solo:
				confirm_completion.rpc(robot.position,robot.quaternion)

func save_checkpoint(at: Vector3,objective_stage: int,has_cargo: bool,safe_heading: float=0) -> void:
	super.save_checkpoint(at,objective_stage,has_cargo,safe_heading)
	checkpoint_water=maxf(25,robot.water)

func restore_checkpoint() -> void:
	stage=checkpoint_stage
	cargo=true
	robot.checkpoint_position=checkpoint
	robot.checkpoint_heading=checkpoint_heading
	robot.reset_robot()
	robot.water=checkpoint_water
	robot.auto_stabilize=false
	if running and authority():
		robot.set_simulation(true)
	turning=false
	riding=false
	turn_time=3
	freight_time=4 if stage>=3 else 0
	hold_progress=0
	completed=false
	announce("Checkpoint restored. Cargo and route progress preserved.")

func update_level(delta: float) -> void:
	wave_time+=delta
	if turning:
		turn_time=minf(3,turn_time+delta)
		var amount := smoothstep(0,1,turn_time/3)
		robot.position=Vector3(0,0.06,-30)
		robot.rotation=Vector3(0,lerp_angle(turn_start_heading,-PI/2,amount),0)
		if turn_time>=3:
			turning=false
			robot.set_simulation(true)
		return
	if riding:
		freight_time=minf(4,freight_time+delta)
		var amount := smoothstep(0,1,freight_time/4)
		robot.position=Vector3(10,0.02-6*amount,-30)
		if freight_time>=4:
			riding=false
			robot.set_simulation(true)
			save_checkpoint(Vector3(10,-5.9,-25.5),stage,true,PI)
			announce("Lower deck reached. Follow the U-shaped catwalk to the refill station.")
		return
	if stage<3 and robot.position.y< -2 and not robot.recovering:
		restore_checkpoint()
		announce("Use the freight lift to reach the lower deck safely.")
	if robot.water<=0 and not robot.recovering:
		restore_checkpoint()
		announce("Water depleted. Returned to the last safe station.")
	if stage==1 and route_taken=="":
		if robot.position.x> -9 and robot.position.z> -10:
			route_taken="service"
		elif robot.position.z< -6 and robot.position.x< -7:
			route_taken="short"
	if can_interact() and interact_held:
		hold_progress+=delta
		if hold_progress>=hold_duration():
			advance_objective()
	else:
		hold_progress=0
	near_obstacle=proximity()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if running:
		if not authority():
			wave_time+=delta
			robot.cradle.rotation.z=robot.cargo_tilt
		for deck in bridges:
			deck.set_wave(wave_time)

func make_snapshot() -> Dictionary:
	var state := super.make_snapshot()
	state.merge({"wave":wave_time,"turn_time":turn_time,"freight_time":freight_time,"turning":turning,"riding":riding,"balance_practiced":balance_practiced,"cargo_tilt":robot.cargo_tilt,"water":robot.water,"spills":robot.spills,"checkpoint_water":checkpoint_water,"route":route_taken})
	return state

func receive_state(state: Dictionary) -> void:
	if int(state.get("level",1))!=2:
		return
	super.receive_state(state)
	wave_time=state.wave
	turn_time=state.turn_time
	freight_time=state.freight_time
	turning=state.turning
	riding=state.riding
	balance_practiced=state.balance_practiced
	robot.cargo_tilt=state.cargo_tilt
	robot.water=state.water
	robot.spills=state.spills
	checkpoint_water=state.checkpoint_water
	route_taken=state.route

func apply_presentation(delta: float) -> void:
	if authority():
		announcement_time=maxf(0,announcement_time-delta)
	for i in range(dock_markers.size()):
		dock_markers[i].visible=i==stage
	lower_gate.visible=stage<4
	lower_gate.process_mode=Node.PROCESS_MODE_INHERIT if stage<4 else Node.PROCESS_MODE_DISABLED
	final_gate.visible=stage<5
	final_gate.process_mode=Node.PROCESS_MODE_INHERIT if stage<5 else Node.PROCESS_MODE_DISABLED
	bridge.rotation.y= -PI/2*smoothstep(0,1,turn_time/3)
	lift.position.y= -0.15-6*smoothstep(0,1,freight_time/4) if stage>=3 else -0.15
	lift_gate.visible=riding
	lift_gate.process_mode=Node.PROCESS_MODE_INHERIT if riding else Node.PROCESS_MODE_DISABLED
	robot.cradle.visible=true
	robot.visual.head.visible=role!=0
	camera.position=robot.global_transform*Vector3(0,2.84,-0.49)
	camera.rotation=Vector3(pitch,robot.heading()+yaw,0)
	robot.visual.head.rotation.y=yaw
	robot.visual.head.rotation.x=pitch
	recovery_fade.color.a=clampf(1-robot.recovery_time/0.4,0,1) if robot.recovering else 0
	update_view(delta)
	if completed:
		notice.text="STABILIZER ONLINE — LEVEL 2 COMPLETE"
	if is_instance_valid(balance_label):
		balance_label.visible=solo or role==1
		balance_meter.visible=solo or role==1
		balance_label.text="CRADLE LEAN: %+.0f°\nJ / L balance · Shift brace\nWater: %.0f%% · Spills: %d" % [rad_to_deg(robot.cargo_tilt),robot.water,robot.spills]
		balance_meter.value=(robot.cargo_tilt+1.1)/2.2*100
	if role==1 and not solo:
		telemetry.text="HANDS / BODY\nJ/L: counterbalance · Shift: brace\nSpace: jump · Hold E: interact\nKeep the balance indicator centred."
