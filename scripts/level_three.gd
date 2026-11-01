extends "res://scripts/level_one.gd"
const FLAG_NAMES := ["training","battery","pump_a","lock","pump_b","light_1","light_2","basin","exit"]
const Save = preload("res://scripts/waterworks_save.gd")
var flags := {"training":false,"battery":false,"pump_a":false,"lock":false,"pump_b":false,"light_1":false,"light_2":false,"basin":false,"exit":false}
var checkpoint_id := 1
var checkpoint_flags: Dictionary = flags.duplicate()
var checkpoint_seen: Array = [1]
var active_station := ""
var engaged := ""
var pressure := 0.0
var pressure_hold := 0.0
var pressure_input := 0.0
var previous_interact := false
var release_required := false
var engage_hold := 0.0
var clock := 0.0
var lock_time := 0.0
var basin_time := 0.0
var immersion_time := 0.0
var bridges: Array = []
var barriers: Dictionary = {}
var station_markers: Dictionary = {}
var target_labels: Dictionary = {}
var checkpoint_markers: Array = []
var jet_visuals: Array = []
var jet_signals: Array = []
var last_jet_warning := -1
var elevator_gate: Node3D
var water: MeshInstance3D
var lock_water: MeshInstance3D
var raft: AnimatableBody3D
var lock_platform: AnimatableBody3D
var shuttle: AnimatableBody3D
var trolley: RigidBody3D
var hitch: PinJoint3D
var coupled := false
var trolley_target := Transform3D.IDENTITY
var tow_limit := 6.0
var spotlight: SpotLight3D
var gallery_lights: Array = []
var instruments: Label
var saved_notice := 0.0
var save_enabled := true
var slot_path := Save.PATH
var checkpoint_cooldown := 0.0
var session_started := false
var recovery_serial := 0
var water_fx: Node3D

func _init() -> void:
	Layout=preload("res://scripts/level_three_layout.gd")
	level_number=3
	level_title="WATERWORKS"
	DOCKS=Layout.docks()
	OBJECTIVES=["Restart both pumps, then reach the surface elevator.","Waterworks restored. Next: The Sleeping City."]
	ACTIONS=["Operate nearby machinery"]
	cargo=true
	checkpoint_cargo=true
	checkpoint=Layout.START
	checkpoint_stage=0

func _ready() -> void:
	save_enabled=not "--no-save" in OS.get_cmdline_user_args()
	super._ready()
	instruments=text_label(hud,"",20)
	instruments.position=Vector2(760,540)
	ignore_hud_mouse(hud)

func platform(at: Vector3,size: Vector2) -> Node3D:
	return block(at-Vector3(0,0.18,0),Vector3(size.x,0.36,size.y),"344953")

func walkway(a: Vector3,b: Vector3,width: float=5,rails: bool=true) -> void:
	var z_axis := -(b-a).normalized()
	var x_axis := Vector3.UP.cross(z_axis).normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	var basis := Basis(x_axis,y_axis,z_axis)
	var length := a.distance_to(b)
	var deck := block((a+b)*0.5-y_axis*0.18,Vector3(width,0.36,length+0.1),"344953")
	deck.basis=basis
	if rails:
		for side in [-1,1]:
			var trim := maxf(0.1,length-width*1.2)
			var rail := block((a+b)*0.5+basis*Vector3(side*width*0.5,0.55,0),Vector3(0.12,1.1,trim),"52646d")
			rail.basis=basis
			rail.get_child(0).visible=false
			factory.rod((a+b)*0.5+basis*Vector3(side*width*0.5,1.2,-trim*0.5),(a+b)*0.5+basis*Vector3(side*width*0.5,1.2,trim*0.5),0.045,"yellow")
			factory.rod((a+b)*0.5+basis*Vector3(side*width*0.5,0.65,-trim*0.5),(a+b)*0.5+basis*Vector3(side*width*0.5,0.65,trim*0.5),0.025,"steel")
			var posts := maxi(1,ceili(trim/2.5))
			for i in range(posts+1):
				var z := lerpf(-trim*0.5,trim*0.5,float(i)/posts)
				factory.rod((a+b)*0.5+basis*Vector3(side*width*0.5,0.1,z),(a+b)*0.5+basis*Vector3(side*width*0.5,1.25,z),0.045,"yellow")

func route(points: Array,width: float=5) -> void:
	for i in range(points.size()-1): walkway(points[i],points[i+1],width)
	for i in range(1,points.size()-1): platform(points[i],Vector2(width+1,width+1))

func bridge_between(a: Vector3,b: Vector3) -> void:
	var deck := preload("res://scripts/suspension_bridge.gd").new()
	deck.width=2.2
	deck.sway_amplitude=1.2
	world.add_child(deck)
	deck.build(a,b,factory,float(bridges.size()))
	bridges.append(deck)

func moving_deck(at: Vector3,size: Vector2) -> AnimatableBody3D:
	var deck := AnimatableBody3D.new()
	deck.sync_to_physics=false
	world.add_child(deck)
	deck.position=at
	block(Vector3(0,-0.18,0),Vector3(size.x,0.36,size.y),"526c70",false,deck)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size=Vector3(size.x,0.36,size.y)
	collision.shape=box
	collision.position.y=-0.18
	deck.add_child(collision)
	deck.sync_to_physics=true
	return deck

func water_surface(at: Vector3,size: Vector2) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size=size
	plane.subdivide_width=ceili(size.x*2)
	plane.subdivide_depth=ceili(size.y*2)
	mesh.mesh=plane
	var m := ShaderMaterial.new()
	m.shader=preload("res://materials/waterworks_water.gdshader")
	m.set_shader_parameter("surface_dimensions",size)
	mesh.material_override=m
	world.add_child(mesh)
	mesh.position=at
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.extra_cull_margin=0.04
	return mesh

func barrier(id: String,at: Vector3,size: Vector3) -> void:
	barriers[id]=block(at,size,"b99852")

func build_world() -> void:
	world=Node3D.new()
	world.name="Waterworks"
	add_child(world)
	factory=preload("res://scripts/waterworks_art.gd").new()
	world.add_child(factory)
	route([Vector3(0,0,40),Vector3.ZERO],5)
	platform(Vector3.ZERO,Vector2(14,14))
	platform(Layout.START-Vector3(0,0.1,0),Vector2(10,10))
	route(Layout.A_OUT.slice(0,5),5.5)
	for corner in [Vector3(-32,0,0),Vector3(-32,0,-18),Vector3(-48,0,-18)]: platform(corner,Vector2(8,8))
	bridge_between(Vector3(-48,0,-18),Vector3(-48,0,-32))
	walkway(Vector3(-48,0,-32),Vector3(-48,0,-44),5)
	platform(Vector3(-48,0,-44),Vector2(7,7))
	# The gap has no hidden collision deck underneath it.
	walkway(Vector3(-48,0,-44),Vector3(-42.75,0,-44),5)
	walkway(Vector3(-41.25,0,-44),Vector3(-32,0,-44),5)
	platform(Vector3(-32,0,-44),Vector2(8,8))
	route(Layout.A_RETURN,5)
	barrier("battery",Vector3(-48,1.7,-21),Vector3(3.2,3.4,0.2))
	barrier("a_return",Vector3(-28,1.7,-40),Vector3(4,3.4,0.2))
	barriers.a_return.rotation.y=PI/4
	route([Vector3.ZERO,Vector3(16,0,0),Vector3(16,0,-22),Vector3(29.9,0,-22)],5)
	platform(Vector3(28,0,-22),Vector2(4,7))
	platform(Vector3(40,0,-22),Vector2(4,7))
	shuttle=moving_deck(Vector3(32,0,-22),Vector2(4,4))
	walkway(Vector3(38,0,-22),Vector3(38,0,-24),5)
	walkway(Vector3(38,0,-24),Vector3(38,-3,-42),5)
	platform(Vector3(38,-3,-41),Vector2(7,5))
	lock_platform=moving_deck(Vector3(38,-3,-45),Vector2(6,6))
	# Side guards travel with the platform; boarding edges are controlled gates.
	for x in [-3,3]: block(Vector3(x,0.6,0),Vector3(0.12,1.2,6),"b99852",true,lock_platform)
	barrier("lock_in",Vector3(38,-1.5,-42),Vector3(6,3,0.2))
	barrier("lock_out",Vector3(38,1.5,-48),Vector3(6,3,0.2))
	walkway(Vector3(38,0,-48.1),Vector3(38,0,-54),5)
	platform(Vector3(38,0,-54),Vector2(8,8))
	route(Layout.B_RETURN,5)
	barrier("b_return",Vector3(43,1.7,-54),Vector3(0.2,3.4,5))
	# Dark return gallery has opaque walls and a roof, not global darkness.
	for spec in [[Vector3(50,2,-18),Vector3(5.5,4,16)],[Vector3(38,2,-10),Vector3(24,4,5.5)]]:
		var at: Vector3=spec[0]
		var size: Vector3=spec[1]
		block(at+Vector3(0,size.y*0.5,0),Vector3(size.x,0.2,size.z),"1b282f")
	for z in range(-22,-13,4):
		for x in [47.25,52.75]: block(Vector3(x,1.8,z),Vector3(0.15,3.6,3.8),"1b282f")
	for x in range(32,48,4):
		for z in [-12.75,-7.25]: block(Vector3(x,1.8,z),Vector3(3.8,3.6,0.15),"1b282f")
	for at in [Vector3(50,2,-20),Vector3(32,2,-10)]:
		var light := OmniLight3D.new()
		world.add_child(light)
		light.position=at
		light.omni_range=12
		light.light_color=Color("ffd293")
		gallery_lights.append(light)
	sign_at("SERVICE LINE ↑",Vector3(50,1.8,-24),"acdad5",PI)
	sign_at("RETURN TO HUB →",Vector3(50,1.8,-12),"acdad5",PI)
	sign_at("← HUB",Vector3(28,1.8,-10),"acdad5",PI/2)
	route([Vector3.ZERO,Vector3(6,0,-8),Vector3(6,-5.4,-38),Vector3(3,-5.4,-38)],5)
	barrier("basin_access",Vector3(6,1.6,-9),Vector3(5,3.2,0.2))
	raft=moving_deck(Vector3(0,-5.4,-38),Vector2(6,6))
	block(Vector3(0,0.55,3),Vector3(6,1.1,0.12),"b99852",true,raft)
	block(Vector3(-3,0.55,0),Vector3(0.12,1.1,6),"b99852",true,raft)
	barrier("raft_entry",Vector3(3,-4.2,-38),Vector3(0.2,2.4,6))
	barrier("raft_exit",Vector3(0,1.8,-41),Vector3(6,2.4,0.2))
	walkway(Vector3(0,0.6,-41),Vector3(0,0.6,-60),5)
	bridge_between(Vector3(0,0.6,-60),Vector3(0,0.6,-70))
	route([Vector3(0,0.6,-70),Vector3(0,0.6,-84),Vector3(16,0.6,-84)],5)
	platform(Vector3(16,0.6,-84),Vector2(8,8))
	walkway(Vector3(16,0.6,-84),Vector3(16,3.65,-101),5)
	walkway(Vector3(16,3.6,-101),Vector3(16,3.6,-104),5)
	platform(Vector3(16,3.6,-104),Vector2(6,6))
	walkway(Vector3(16,3.6,-104),Layout.LIFT,5)
	platform(Layout.LIFT,Vector2(9,8))
	lift=moving_deck(Layout.LIFT,Vector2(6,6))
	elevator_gate=block(Vector3(3,1.1,0),Vector3(0.15,2.2,6),"b99852",false,lift)
	for x in [-3,3]:
		factory.box(Layout.LIFT+Vector3(x,3.2,-3),Vector3(0.4,6.4,0.4),"yellow")
	factory.box(Layout.LIFT+Vector3(0,6.2,-3),Vector3(6.4,0.5,0.5),"amber")
	water=water_surface(Vector3(0,-6,-48),Vector2(48,70))
	lock_water=water_surface(Vector3(38,-3.6,-45),Vector2(6,6))
	for id in Layout.STATIONS:
		var station: Dictionary=Layout.STATIONS[id]
		var at: Vector3=station.at
		station_markers[id]=block(at+Vector3(0,0.025,0),Vector3(1.8,0.04,1.8),"4fcbd7",false)
		var arrow := Label3D.new()
		world.add_child(arrow)
		arrow.text="↑"
		arrow.font_size=120
		arrow.pixel_size=0.012
		arrow.position=at+Vector3(0,0.065,0)
		arrow.rotation=Vector3(-PI/2,float(station.yaw),0)
		if id not in ["lock","basin"]:
			var console_offset := Vector3(-1.7,0.7,1.7) if id=="training" else Vector3(2,0.7,-2)
			block(at+console_offset,Vector3(0.4,1.4,0.4),"4a6972")
		if station.target>0:
			var label := Label3D.new()
			world.add_child(label)
			label.position=at+Vector3(1.8,2.0,-0.3)
			label.text="%s\nTARGET %.0f–%.0f%%" % [id.to_upper(),station.target-5,station.target+5]
			label.font_size=44
			label.pixel_size=0.008
			label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
			target_labels[id]=label
	for i in range(14):
		var at: Vector3=Layout.CHECKPOINTS[i]
		checkpoint_markers.append(block(at+Vector3(0,0.015,0),Vector3(0.8,0.03,0.8),"58bed0",false))
	for i in range(2):
		var jet := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius=0.25
		mesh.bottom_radius=0.5
		mesh.height=5
		jet.mesh=mesh
		jet.material_override=material("7bbdc9",0.5)
		world.add_child(jet)
		jet.position=Vector3(16,1.2,-9-i*9)
		jet.rotation.z=PI/2
		jet_visuals.append(jet)
		jet_signals.append(block(Vector3(18,2.4,-7-i*9),Vector3(0.5,0.5,0.5),"63d3b5",false))
		sign_at("DISCHARGE\nAMBER: WAIT",Vector3(19,2.8,-7-i*9))
	sign_at("A / FILTRATION ←     → B / PRESSURE",Vector3(0,4,-5))
	sign_at("SURFACE ELEVATOR",Layout.LIFT+Vector3(0,4,-3))
	sign_at("COUPLE TROLLEY / E",Vector3(-16,3,2))
	factory.flush()
	preload("res://scripts/cinematic_kit.gd").new().install(self)
	robot=preload("res://scripts/robot.gd").new()
	robot.name="SharedRobot"
	add_child(robot)
	robot.kill_height=-15
	robot.auto_stabilize=true
	robot.teleport(Layout.START)
	robot.fell.connect(restore_checkpoint)
	robot.set_simulation(false)
	tow_limit=robot.forward_limit
	build_trolley()
	update_machinery()
	camera=Camera3D.new()
	camera.current=true
	camera.fov=78
	camera.near=0.05
	add_child(camera)
	spotlight=SpotLight3D.new()
	camera.add_child(spotlight)
	spotlight.light_energy=7
	spotlight.spot_range=20
	spotlight.spot_angle=38
	spotlight.shadow_enabled=true
	spotlight.light_color=Color("d1e6dc")
	water_fx=preload("res://scripts/waterworks_water.gd").new()
	add_child(water_fx)
	water_fx.configure(self)

func build_trolley() -> void:
	trolley=RigidBody3D.new()
	trolley.name="BatteryTrolley"
	trolley.mass=25
	trolley.axis_lock_angular_x=true
	trolley.axis_lock_angular_z=true
	trolley.linear_damp=0.8
	world.add_child(trolley)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size=Vector3(1.2,0.6,1.4)
	shape.shape=box
	trolley.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size=box.size
	visual.mesh=mesh
	visual.material_override=material("c58c32")
	trolley.add_child(visual)
	for x in [-0.65,0.65]:
		for z in [-0.45,0.45]:
			var wheel := MeshInstance3D.new()
			var tire := CylinderMesh.new()
			tire.top_radius=0.24
			tire.bottom_radius=0.24
			tire.height=0.15
			wheel.mesh=tire
			wheel.material_override=material("232c30")
			wheel.rotation.z=PI/2
			wheel.position=Vector3(x,-0.22,z)
			trolley.add_child(wheel)
	reset_trolley()

func reset_trolley() -> void:
	set_coupled(false)
	trolley.freeze=true
	trolley.position=Vector3(-16,0.5,2.2) if not flags.battery else Vector3(-45.5,0.5,-17)
	trolley.rotation=Vector3.ZERO
	trolley.linear_velocity=Vector3.ZERO
	trolley.angular_velocity=Vector3.ZERO

func set_coupled(value: bool) -> void:
	if is_instance_valid(hitch):
		hitch.node_a=NodePath()
		hitch.node_b=NodePath()
		hitch.queue_free()
		hitch=null
	coupled=value
	robot.forward_limit=2.0 if value else tow_limit
	robot.reverse_limit=2.0 if value else 3.0
	trolley.freeze=not value
	if value:
		robot.jump_buffer=0
		robot.jump_requested=false
		hitch=PinJoint3D.new()
		world.add_child(hitch)
		hitch.global_position=robot.global_transform*Vector3(0,0.5,1.2)
		hitch.node_a=hitch.get_path_to(robot)
		hitch.node_b=hitch.get_path_to(trolley)
		hitch.exclude_nodes_from_collision=true

func begin_session() -> void:
	super.begin_session()
	announce("Surface transport unavailable. Hydraulic reserve empty. Restart both pump wings.")
	looked=true
	drove=true
	robot.auto_stabilize=true
	trolley.collision_layer=1 if authority() else 0
	trolley.collision_mask=trolley.collision_layer
	if authority() and not session_started:
		session_started=true
		if Campaign.resume_three:
			var saved := Save.read_slot(slot_path)
			if not saved.is_empty(): load_checkpoint(saved)
			else: announce("No valid Waterworks save found. Starting at arrival.")
		else: capture_checkpoint(1)
		Campaign.resume_three=false
	if completed and authority() and not solo: call_deferred("send_saved_completion")

func send_saved_completion() -> void:
	finish_waterworks.rpc(make_snapshot())

func local_input() -> Dictionary:
	var data := super.local_input()
	data.pressure=pressed(KEY_L)-pressed(KEY_J)
	return data

func apply_input(input_role: int,data: Dictionary) -> void:
	super.apply_input(input_role,data)
	if input_role==1:
		var value := float(data.get("pressure",0))
		pressure_input=clampf(value,-1,1) if is_finite(value) else 0.0
		if coupled: robot.jump_requested=false

func available(id: String) -> bool:
	match id:
		"training": return not flags.training
		"battery": return flags.training and not flags.battery and coupled
		"pump_a": return flags.battery and not flags.pump_a
		"lock": return flags.training and not flags.lock and lock_time<=0
		"pump_b": return flags.lock and lock_time>=8 and not flags.pump_b
		"light_1","light_2": return flags.pump_b and not flags[id]
		"basin": return flags.pump_a and flags.pump_b and not flags.basin
		"exit": return flags.basin and basin_time>=14 and not flags.exit
	return false

func station_at(id: String) -> Vector3:
	if id=="basin": return raft.position
	if id=="lock": return lock_platform.position
	return Layout.STATIONS[id].at

func station_valid(id: String) -> bool:
	if id=="" or not available(id) or robot.recovering: return false
	var at := station_at(id)
	return Vector2(robot.position.x-at.x,robot.position.z-at.z).length()<=1.4 and absf(robot.position.y-at.y)<0.5 and (robot.grounded if authority() else remote_grounded) and robot.velocity.length()<0.18 and robot.angular_velocity.length()<0.15 and absf(wrapf(robot.heading()-float(Layout.STATIONS[id].yaw),-PI,PI))<=deg_to_rad(12)

func nearby_station() -> String:
	var best := ""
	var distance := 4.0
	for id in Layout.STATIONS:
		if available(id):
			var d := robot.position.distance_to(station_at(id))
			if d<distance:
				distance=d
				best=id
	return best

func can_interact() -> bool: return station_valid(active_station)
func hold_duration() -> float: return 0.8
func dock_distance() -> float:
	return robot.position.distance_to(station_at(active_station)) if active_station!="" else INF
func interaction_hint() -> String:
	if completed: return "LEVEL 3 COMPLETE — WATERWORKS\nNext chapter: The Sleeping City."
	if coupled and active_station=="battery" and station_valid("battery"): return "HANDS: hold E to dock the battery and power the bridge gate."
	if coupled: return "TOWING: 2 m/s limit · Jump disabled · Stop and hold E to detach or dock."
	if not flags.battery and trolley.position.distance_to(robot.position)<3 and not coupled: return "HANDS: stop beside the rear coupling and hold E to attach trolley."
	if engaged!="": return "VALVE ENGAGED: J decreases / L increases · Hold target 3 seconds · Fresh E disengages."
	if active_station!="":
		if not station_valid(active_station): return "Move to %s circle, align with its arrow, then stop." % active_station.to_upper()
		return "HANDS: hold E — "+active_station.replace("_"," ").to_upper()
	if not flags.training: return "Reach the central hub and calibrate the training valve."
	if not flags.pump_a or not flags.pump_b: return "Choose a pump wing. A: filtration and battery · B: jets and water lock."
	return "Both pumps online. Return to the hub and descend to the basin raft."

func complete_station(id: String) -> void:
	flags[id]=true
	engaged=""
	pressure_hold=0
	engage_hold=0
	release_required=true
	play_tone()
	match id:
		"training": capture_checkpoint(2)
		"battery":
			reset_trolley()
			capture_checkpoint(4)
		"pump_a": capture_checkpoint(5)
		"lock": lock_time=0.001
		"pump_b": capture_checkpoint(10)
		"basin":
			basin_time=0.001
			announce("Organic specimen detected. Restoring irrigation reserve.")
		"exit":
			completed=true
			stage=Layout.COMPLETE
			robot.finished=true
			robot.set_simulation(false)
			persist_checkpoint(true)
			if not solo: finish_waterworks.rpc(make_snapshot())
		_: capture_checkpoint(checkpoint_id)

func checkpoint_allowed(id: int) -> bool:
	if id==1: return true
	if id==2 or id==3 or id==6 or id==7 or id==8 or id==9: return flags.training
	if id==4: return flags.battery
	if id==5: return flags.pump_a
	if id==10 or id==11: return flags.pump_b
	if id==12: return flags.pump_a and flags.pump_b
	if id>=13: return flags.basin and basin_time>=14
	return false

func safe_heading(id: int) -> float:
	return {4:0.0,5:0.0,8:0.0,9:0.0,10:-PI/2,11:PI,12:PI/2,13:0.0,14:0.0}.get(id,0.0)

func capture_checkpoint(id: int) -> void:
	checkpoint_id=id
	checkpoint_flags=flags.duplicate()
	# A transit phase is never a persisted checkpoint state.
	if basin_time<14: checkpoint_flags.basin=false
	if lock_time<8: checkpoint_flags.lock=false
	checkpoint=Layout.CHECKPOINTS[id-1]+Vector3(0,0.1,0)
	checkpoint_heading=safe_heading(id)
	checkpoint_cargo=true
	checkpoint_cooldown=2
	if id not in checkpoint_seen: checkpoint_seen.append(id)
	persist_checkpoint()

func save_data(finished: bool=false) -> Dictionary:
	return {"version":Save.VERSION,"level":3,"checkpoint":checkpoint_id,"flags":checkpoint_flags.duplicate(),"complete":finished,"heading":checkpoint_heading,"cargo":true}

func persist_checkpoint(finished: bool=false) -> void:
	if not authority() or not save_enabled: return
	var error := Save.write_slot(save_data(finished),slot_path)
	if error==OK: saved_notice=3
	else: announce("Checkpoint active, but disk save failed (%d)." % error)

func load_checkpoint(data: Dictionary) -> void:
	checkpoint_id=int(data.checkpoint)
	checkpoint_flags=data.flags.duplicate()
	checkpoint_seen=[checkpoint_id]
	checkpoint=Layout.CHECKPOINTS[checkpoint_id-1]+Vector3(0,0.1,0)
	checkpoint_heading=safe_heading(checkpoint_id)
	restore_checkpoint()
	if data.get("complete",false):
		flags.exit=true
		completed=true
		stage=Layout.COMPLETE
		robot.finished=true
		robot.set_simulation(false)

func restore_checkpoint() -> void:
	recovery_serial+=1
	flags=checkpoint_flags.duplicate()
	completed=false
	stage=0
	cargo=true
	engaged=""
	pressure=0
	pressure_hold=0
	engage_hold=0
	pressure_input=0
	interact_held=false
	previous_interact=false
	release_required=true
	immersion_time=0
	lock_time=8.0 if flags.lock else 0.0
	basin_time=14.0 if flags.basin else 0.0
	clock=0
	reset_trolley()
	update_machinery()
	robot.checkpoint_position=checkpoint
	robot.checkpoint_heading=checkpoint_heading
	robot.reset_robot()
	robot.auto_stabilize=true
	if running and authority(): robot.set_simulation(true)
	checkpoint_cooldown=2
	announce("Safe checkpoint restored. Sapling secured.")

@rpc("authority","call_remote","reliable")
func finish_waterworks(state: Dictionary) -> void:
	receive_state(state)
	robot.position=state.position
	robot.quaternion=state.orientation
	robot.finished=true
	robot.set_simulation(false,true)

func jet_phase() -> float: return fposmod(clock,7.0)
func shuttle_x() -> float:
	var t := fposmod(clock,18.0)
	if t<3: return 32
	if t<9: return 32+t-3
	if t<12: return 38
	return 38-(t-12)

func update_machinery() -> void:
	var phase := fposmod(clock,18.0)
	shuttle.set_meta("surface_velocity",Vector3(1 if phase>=3 and phase<9 else (-1 if phase>=12 else 0),0,0))
	lock_platform.set_meta("surface_velocity",Vector3(0,3*6*(lock_time/8)*(1-lock_time/8)/8 if lock_time>0 and lock_time<8 else 0,0))
	raft.set_meta("surface_velocity",Vector3(0,6*6*(basin_time/14)*(1-basin_time/14)/14 if basin_time>0 and basin_time<14 else 0,0))
	shuttle.transform=Transform3D(Basis.IDENTITY,Vector3(shuttle_x(),0,-22))
	lock_platform.transform=Transform3D(Basis.IDENTITY,Vector3(38,-3+3*smoothstep(0,1,lock_time/8),-45))
	lock_water.position.y=-3.6+3*smoothstep(0,1,lock_time/8)
	raft.transform=Transform3D(Basis.IDENTITY,Vector3(0,-5.4+6*smoothstep(0,1,basin_time/14),-38))
	water.position.y=-6+6*smoothstep(0,1,basin_time/14)
	if is_instance_valid(lift):
		var rise := 7*smoothstep(0,1,clampf(lift_time/6,0,1)) if completed else 0.0
		lift.transform=Transform3D(Basis.IDENTITY,Layout.LIFT+Vector3(0,rise,0))
		elevator_gate.visible=completed
	var open_states := {"battery":flags.battery,"a_return":flags.pump_a,"b_return":flags.pump_b,"lock_in":not flags.lock,"lock_out":flags.lock and lock_time>=8,"basin_access":flags.pump_a and flags.pump_b,"raft_entry":not flags.basin,"raft_exit":flags.basin and basin_time>=14}
	for id in barriers:
		var opened: bool=open_states[id]
		barriers[id].visible=not opened
		barriers[id].process_mode=Node.PROCESS_MODE_DISABLED if opened else Node.PROCESS_MODE_INHERIT
	for i in range(jet_visuals.size()):
		jet_visuals[i].visible=jet_phase()>=5
		jet_signals[i].get_child(0).material_override=material("dd7755" if jet_phase()>=5 else ("ffbf53" if jet_phase()>=3 else "63d3b5"),1.5)
	for i in range(gallery_lights.size()): gallery_lights[i].light_energy=4 if flags["light_%d" % (i+1)] else 0
	for deck in bridges: deck.set_wave(clock)

func in_gallery() -> bool:
	var p := robot.position
	return (p.x>47 and p.x<53 and p.z> -26 and p.z< -9) or (p.x>26 and p.x<51 and absf(p.z+10)<3)

func update_level(delta: float) -> void:
	clock+=delta
	if completed:
		lift_time=minf(6,lift_time+delta)
		update_machinery()
		robot.position=Layout.LIFT+Vector3(0,0.08+7*smoothstep(0,1,lift_time/6),0)
		return
	saved_notice=maxf(0,saved_notice-delta)
	checkpoint_cooldown=maxf(0,checkpoint_cooldown-delta)
	if flags.lock: lock_time=minf(8,lock_time+delta)
	if flags.basin: basin_time=minf(14,basin_time+delta)
	update_machinery()
	if input_age[1]>0.5: pressure_input=0
	active_station=nearby_station()
	var rising := interact_held and not previous_interact
	if not interact_held: release_required=false
	if engaged!="":
		if not station_valid(engaged) or (rising and not release_required):
			engaged=""
			pressure_hold=0
			engage_hold=0
			release_required=true
		else:
			pressure=clampf(pressure+pressure_input*20*delta,0,100)
			var target: float=Layout.STATIONS[engaged].target
			pressure_hold=pressure_hold+delta if absf(pressure-target)<=5 else 0.0
			if pressure_hold>=3: complete_station(engaged)
	elif not release_required:
		if interact_held and station_valid(active_station):
			engage_hold+=delta
			if engage_hold>=0.8:
				if Layout.STATIONS[active_station].target>0:
					engaged=active_station
					pressure=0
					pressure_hold=0
					release_required=true
				else: complete_station(active_station)
		elif interact_held and flags.training and not flags.battery and trolley.position.distance_to(robot.position)<3 and robot.velocity.length()<0.18 and robot.angular_velocity.length()<0.15:
			engage_hold+=delta
			if engage_hold>=0.8:
				set_coupled(not coupled)
				engage_hold=0
				release_required=true
		else: engage_hold=0
	previous_interact=interact_held
	hold_progress=engage_hold
	if coupled:
		robot.jump_requested=false
		if trolley.position.y< -2 or trolley.position.distance_to(robot.position)>6: start_recovery()
	if jet_phase()>=5 and robot.grounded:
		for z in [-9,-18]:
			if absf(robot.position.z-z)<1 and absf(robot.position.x-16)<3 and absf(robot.position.y)<0.5:
				robot.apply_central_force(Vector3.LEFT*robot.mass*2)
	var p := robot.position
	var submerged := (absf(p.x)<24 and p.z< -13 and p.z> -83 and p.y<water.position.y-0.7) or (absf(p.x-38)<3 and absf(p.z+45)<3 and p.y<lock_water.position.y-0.7)
	immersion_time=immersion_time+delta if submerged else 0.0
	if immersion_time>=0.35: start_recovery()
	if checkpoint_cooldown<=0 and not coupled and robot.grounded and not robot.recovering and not (flags.lock and lock_time<8) and not (flags.basin and basin_time<14):
		for i in range(14):
			var id := i+1
			if checkpoint_allowed(id) and p.distance_to(Layout.CHECKPOINTS[i])<1.0:
				if id!=checkpoint_id or flags!=checkpoint_flags: capture_checkpoint(id)
	near_obstacle=proximity()
	var phase := 0 if jet_phase()<3 else (1 if jet_phase()<5 else 2)
	if phase!=last_jet_warning and absf(robot.position.x-16)<8 and robot.position.z< -4 and robot.position.z> -24:
		if phase==1: play_tone()
	last_jet_warning=phase

func start_recovery() -> void:
	if not robot.recovering:
		robot.recovering=true
		robot.recovery_time=0.4
		robot.drive_input=Vector2.ZERO

func flags_mask() -> int:
	var mask := 0
	var i := 0
	for key in FLAG_NAMES:
		if flags[key]: mask |= 1<<i
		i+=1
	return mask

func apply_flags_mask(mask: int) -> void:
	var i := 0
	for key in FLAG_NAMES:
		flags[key]=(mask & (1<<i))!=0
		i+=1

func make_snapshot() -> Dictionary:
	var state := super.make_snapshot()
	state.merge({"flags":flags_mask(),"clock":clock,"lock_time":lock_time,"basin_time":basin_time,"pressure":pressure,"pressure_hold":pressure_hold,"engaged":engaged,"station":active_station,"coupled":coupled,"trolley_transform":trolley.transform,"checkpoint_id":checkpoint_id,"saved_notice":saved_notice,"recovery_serial":recovery_serial})
	return state

func receive_state(state: Dictionary) -> void:
	if int(state.get("level",1))!=3: return
	super.receive_state(state)
	apply_flags_mask(int(state.flags))
	clock=state.clock
	lock_time=state.lock_time
	basin_time=state.basin_time
	pressure=state.pressure
	pressure_hold=state.pressure_hold
	engaged=state.engaged
	active_station=state.station
	coupled=state.coupled
	trolley_target=state.trolley_transform
	checkpoint_id=state.checkpoint_id
	saved_notice=state.saved_notice
	recovery_serial=state.recovery_serial

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if running and not authority():
		clock+=delta
		if flags.lock: lock_time=minf(8,lock_time+delta)
		if flags.basin: basin_time=minf(14,basin_time+delta)
		update_machinery()
		trolley.transform=trolley.transform.interpolate_with(trolley_target,minf(1,delta*18))
		if completed:
			lift_time=minf(6,lift_time+delta)
			robot.position=Layout.LIFT+Vector3(0,0.08+7*smoothstep(0,1,lift_time/6),0)

func apply_presentation(delta: float) -> void:
	if authority(): announcement_time=maxf(0,announcement_time-delta)
	robot.cradle.visible=true
	robot.visual.head.visible=role!=0
	camera.position=robot.global_transform*Vector3(0,2.84,-0.49)
	camera.rotation=Vector3(pitch,robot.heading()+yaw,0)
	robot.visual.head.rotation.y=yaw
	robot.visual.head.rotation.x=pitch
	spotlight.visible=(solo or role==0) and in_gallery()
	recovery_fade.color.a=clampf(1-robot.recovery_time/0.4,0,1) if robot.recovering else 0
	update_view(delta)
	objective.text="PUMPS: A %s / B %s · %s" % ["ONLINE" if flags.pump_a else "OFFLINE","ONLINE" if flags.pump_b else "OFFLINE","Reach the surface elevator" if flags.pump_a and flags.pump_b else "Choose either wing"]
	prompt.text=interaction_hint()
	progress.visible=engage_hold>0 or engaged!=""
	progress.value=pressure_hold/3*100 if engaged!="" else engage_hold/0.8*100
	for id in station_markers:
		station_markers[id].visible=available(id)
		if id in target_labels:
			target_labels[id].visible=solo or role==0
			target_labels[id].position.y=station_at(id).y+(2.75 if id in ["pump_a","pump_b"] else 2.0)
			if id in ["pump_a","pump_b"]:
				target_labels[id].position.x=station_at(id).x
	if is_instance_valid(instruments):
		instruments.visible=solo or role==1
		instruments.text="PRESSURE: %.0f%%\nJ decrease / L increase\nTarget hold: %.1f / 3 s\nCargo: stabilizer online" % [pressure,pressure_hold]
	if role==2 and not solo: telemetry.text+="\nDock heading: %s\n%s" % ["ALIGNED" if active_station!="" and absf(wrapf(robot.heading()-float(Layout.STATIONS[active_station].yaw),-PI,PI))<deg_to_rad(12) else "ALIGN WITH FLOOR ARROW","TROLLEY COUPLED / 2 m/s" if coupled else "TROLLEY DETACHED"]
	if saved_notice>0: notice.text="CHECKPOINT %d SAVED" % checkpoint_id
	if completed:
		objective.text="WATERWORKS RESTORED"
		notice.text="SURFACE TRANSPORT ONLINE — Next: The Sleeping City"
