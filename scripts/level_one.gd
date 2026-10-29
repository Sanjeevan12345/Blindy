extends Node3D
## Level 1. Server owns physics, objectives and checkpoint state.
const PORT := 28760
const ROLE_NAMES := ["HEAD", "HANDS / BODY", "WHEEL"]
const Layout = preload("res://scripts/level_one_layout.gd")
var DOCKS: Array = Layout.docks()
var OBJECTIVES: Array = Layout.ENCOUNTERS.map(func(e): return e.objective) + ["A little further…"]
var ACTIONS: Array = Layout.ENCOUNTERS.map(func(e): return e.action)
var factory: Node3D
var gate_ids: Array[String] = []
var bridge: Node3D
var bridge_time := 0.0
var material_cache: Dictionary = {}
var robot: RigidBody3D
var camera: Camera3D
var world: Node3D
var gates: Array[Node3D] = []
var dock_markers: Array[MeshInstance3D] = []
var shelf_plant: Node3D
var lift: Node3D
var lift_gate: Node3D
var running := false
var solo := false
var role := 0
var roles: Dictionary = {1: 0}
var stage := 0
var cargo := false
var checkpoint_stage := 1
var checkpoint := Vector3(0,0.1,-3)
var checkpoint_cargo := false
var conveyor_checkpoint := false
var jump_practiced := false
var looked := false
var drove := false
var yaw := 0.0
var pitch := 0.0
var hold_progress := 0.0
var interact_held := false
var jump_sequence := 0
var last_jump := 0
var input_age := {0: 0.0, 1: 0.0, 2: 0.0}
var network_tick := 0.0
var target_position := Vector3.ZERO
var target_rotation := Quaternion.IDENTITY
var recovery_fade: ColorRect
var checkpoint_heading := 0.0
var remote_grounded := false
var lift_time := 0.0
var completed := false
var announcement := "Central processor missing. Auxiliary controllers connected."
var announcement_time := 10.0
var near_obstacle := "CLEAR"
var lobby: PanelContainer
var lobby_text: Label
var address: LineEdit
var start_button: Button
var hud: Control
var blackout: ColorRect
var title: Label
var objective: Label
var telemetry: Label
var prompt: Label
var notice: Label
var progress: ProgressBar
var diagram: Control
var tone: AudioStreamPlayer
var music: AudioStreamPlayer
var hum: AudioStreamPlayer
var bump_cooldown := 0.0
var greenhouse_music := false
var automation := false
var server_port := PORT

func authority() -> bool:
	return solo or multiplayer.is_server()

func _ready() -> void:
	build_world()
	build_ui()
	build_audio()
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)
	multiplayer.connected_to_server.connect(func(): lobby_text.text = "Connected. Waiting for role assignment…")
	multiplayer.connection_failed.connect(connection_failed)
	multiplayer.server_disconnected.connect(server_lost)
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--port="):
			server_port = int(arg.get_slice("=",1))
	automation = "--autostart" in args
	if "--solo" in args:
		start_solo()
	elif "--host" in args:
		host_game()
	else:
		for arg in args:
			if arg.begins_with("--join="):
				address.text = arg.get_slice("=",1)
				join_game()

func material(color: String, emission: float = 0.0) -> Material:
	var key := color + str(emission)
	if key in material_cache:
		return material_cache[key]
	var m: Material
	if emission > 0:
		m = factory.emissive(color,emission)
	else:
		m = factory.surface(color,0.65,0.3,1.0 if color == "344953" else 0.0)
	material_cache[key] = m
	return m

func block(at: Vector3, size: Vector3, color: String, solid: bool = true, parent: Node3D = world) -> Node3D:
	var node: Node3D = StaticBody3D.new() if solid else Node3D.new()
	parent.add_child(node)
	node.position = at
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material(color)
	node.add_child(mesh)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		node.add_child(collision)
	return node

func sign_at(text: String, at: Vector3, color: String = "efbf75") -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = 48
	label.pixel_size = 0.007
	label.double_sided = false
	label.modulate = Color(color)
	world.add_child(label)
	var longest := 0
	for line in text.split("\n"):
		longest = maxi(longest,line.length())
	var width := clampf(longest*0.18,2.5,10.5)
	var height := text.split("\n").size()*0.43+0.24
	block(at+Vector3(0,0,0.06),Vector3(width,height,0.10),"253b46",false)

func build_world() -> void:
	world = Node3D.new()
	world.name = "Factory"
	add_child(world)
	factory = preload("res://scripts/factory_art.gd").new()
	world.add_child(factory)
	for span in [Vector2(8,-48),Vector2(-52,-65),Vector2(-67,-86),Vector2(-88,-152)]:
		var length := absf(span.x-span.y)
		block(Vector3(0,-0.4,(span.x+span.y)*0.5),Vector3(12,0.8,length),"344953")
		for x in [-6.0,6.0]:
			# Rail collision leaves both jump gaps open and cannot be used as a bypass.
			block(Vector3(x,0.6,(span.x+span.y)*0.5),Vector3(0.18,1.2,length),"52646d")
	bridge = block(Vector3(0,-3,-50),Vector3(12,0.8,4.1),"344953")
	bridge.process_mode=Node.PROCESS_MODE_DISABLED
	block(Vector3(0,1,8),Vector3(12,2,0.4),"52646d")
	block(Vector3(0,1,-152),Vector3(12,2,0.4),"52646d")
	# Staggered stacks force the intended weave, keeping the turning bays broad.
	for data in [[Vector3(-2,0.8,-15),Vector3(8,1.6,3)], [Vector3(2,0.8,-24),Vector3(8,1.6,3)]]:
		block(data[0],data[1],"8d704c")
		for x in range(-3,4,2):
			factory.machine(Vector3(data[0].x+x,1.6,data[0].z),x)
	factory.flush()
	for entry in Layout.ENCOUNTERS:
		if not entry.has("gate"):
			continue
		var gate := block(Vector3(0,2.5,entry.gate),Vector3(11.8,5,0.25),"3a6975")
		gate.get_child(0).visible=false
		for x in range(-5,6):
			block(Vector3(x,0,0),Vector3(0.12,5,0.16),"3a6975",false,gate)
		for y in [-2.4,0.0,2.4]:
			block(Vector3(0,y,0),Vector3(11.8,0.13,0.2),"3a6975",false,gate)
		gates.append(gate)
		gate_ids.append(entry.id)
	block(Vector3(0,0.22,-60),Vector3(11.6,0.44,0.65),"bd8b45")
	for gap in Layout.GAPS:
		for z in [gap.x+0.4,gap.x+1.1,gap.x+1.8]:
			block(Vector3(0,0.02,z),Vector3(10.5,0.04,0.12),"e8b963",false)
			sign_at("GAP / MOVE + JUMP",Vector3(0,3.7,gap.x-0.2))
	block(Vector3(0,5.8,-72),Vector3(6,1.5,4),"606c72",false)
	for x in [-5,5]:
		block(Vector3(x,3,-72),Vector3(0.7,6,0.7),"606c72")
	sign_at("01 / EXIT → RELEASE",Vector3(0,3.8,0),"75e0df")
	sign_at("02 / SORTING AISLE",Vector3(0,4,-12))
	sign_at("EXTEND SERVICE BRIDGE",Vector3(0,3.8,-46))
	sign_at("03 / PRESS OFFLINE",Vector3(0,4,-73),"75e0df")
	sign_at("04 / LAST GREENHOUSE\nSTOP BEFORE RELEASING SEAL",Vector3(0,3.8,-103))
	sign_at("05 / SERVICE LIFT",Vector3(3,4,-150))
	block(Layout.SHELF-Vector3(0,0.64,0),Vector3(2,1.2,0.8),"526c62")
	var donor := preload("res://scenes/robot_visual.tscn").instantiate()
	world.add_child(donor)
	shelf_plant=donor.cradle
	shelf_plant.reparent(world)
	shelf_plant.position=Layout.SHELF
	donor.queue_free()
	block(Vector3(3,0.30,-142),Vector3(5,0.2,7),"a77e48").rotation.x=0.12
	lift=Node3D.new()
	lift.position=Layout.LIFT
	world.add_child(lift)
	block(Vector3.ZERO,Vector3(5,0.3,6),"4c766f",true,lift)
	for x in [-2.5,2.5]:
		block(Vector3(x,0.8,0),Vector3(0.15,1.6,6),"d1a460",true,lift)
	lift_gate=block(Vector3(0,1,3),Vector3(5,2,0.15),"d1a460",true,lift)
	lift_gate.visible=false
	lift_gate.process_mode=Node.PROCESS_MODE_DISABLED
	for i in range(DOCKS.size()):
		var dock: Vector3=DOCKS[i]
		var marker := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius=1.20
		ring.outer_radius=1.35
		marker.mesh=ring
		marker.scale.y=0.12
		marker.position=dock+Vector3(0,0.035,0)
		marker.material_override=material("50aeb8",0.7)
		world.add_child(marker)
		dock_markers.append(marker)
		if Layout.ENCOUNTERS[i].id != "pickup":
			block(dock+Vector3(1.55,0.7,0),Vector3(0.4,1.4,0.4),"4d6971")
			block(dock+Vector3(1.55,1.45,0),Vector3(0.55,0.2,0.5),"68d8df",false)
	robot=preload("res://scripts/robot.gd").new()
	robot.name="SharedRobot"
	add_child(robot)
	robot.auto_stabilize=true
	robot.fell.connect(restore_checkpoint)
	robot.set_simulation(false)
	robot.cradle.visible=false
	camera=Camera3D.new()
	camera.current=true
	camera.fov=78
	camera.near=0.05
	add_child(camera)

func encounter_id() -> String:
	return "complete" if stage >= Layout.COMPLETE else Layout.ENCOUNTERS[stage].id

func encounter_index(id: String) -> int:
	for i in range(Layout.ENCOUNTERS.size()):
		if Layout.ENCOUNTERS[i].id == id:
			return i
	return Layout.COMPLETE

func hold_duration() -> float:
	return 1.5 if encounter_id() in ["seal","power"] else 0.7

func text_label(parent: Node, text: String, size: int = 20) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",size)
	parent.add_child(label)
	return label

func button(parent: Node, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 44
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)
	blackout = ColorRect.new()
	blackout.color = Color("0a1822")
	blackout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(blackout)
	var column := VBoxContainer.new()
	column.position = Vector2(32,24)
	column.add_theme_constant_override("separation",12)
	hud.add_child(column)
	title = text_label(column,"BLINDY / ASSEMBLY REQUIRED",28)
	title.modulate = Color("efbf75")
	objective = text_label(column,"",21)
	telemetry = text_label(column,"",20)
	telemetry.custom_minimum_size.y = 120
	prompt = text_label(column,"",22)
	progress = ProgressBar.new()
	progress.custom_minimum_size = Vector2(580,12)
	progress.show_percentage = false
	column.add_child(progress)
	notice = text_label(column,"",20)
	notice.modulate = Color("b4e6d9")
	prompt.reparent(hud)
	prompt.position = Vector2(32,620)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.size.x = 900
	progress.reparent(hud)
	progress.position = Vector2(32,675)
	notice.reparent(hud)
	notice.position = Vector2(32,710)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.size.x = 1100
	telemetry.add_theme_font_size_override("font_size",17)
	text_label(column,"Esc: release mouse  •  Click: capture mouse  •  F3: graphics quality",16)
	diagram = Control.new()
	diagram.position = Vector2(830,370)
	diagram.draw.connect(draw_schematic)
	hud.add_child(diagram)
	recovery_fade = ColorRect.new()
	recovery_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	recovery_fade.color=Color(0,0,0,0)
	recovery_fade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hud.add_child(recovery_fade)
	hud.visible = false
	lobby = PanelContainer.new()
	lobby.position = Vector2(330,160)
	lobby.custom_minimum_size = Vector2(620,420)
	layer.add_child(lobby)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	lobby.add_child(box)
	text_label(box,"BLINDY / ASSEMBLY REQUIRED",28)
	lobby_text = text_label(box,"Three players. One robot. Rescue the last sapling.\nHost: HEAD · second player: HANDS · third: WHEEL",18)
	address = LineEdit.new()
	address.text = "127.0.0.1"
	address.placeholder_text = "Host IP address"
	box.add_child(address)
	button(box,"Host three-player session",host_game)
	button(box,"Join session",join_game)
	start_button = button(box,"Start / resume with three players",start_network)
	start_button.disabled = true
	button(box,"Solo test — all controls on one keyboard",start_solo)
	text_label(box,"Direct IP / LAN · UDP %d · use external voice chat\nSolo: W/S throttle · A/D steer · mouse look · Space jump · E interact" % server_port,16)

func draw_schematic() -> void:
	var c := Color("62cbd7")
	if role == 1:
		diagram.draw_style_box(panel_style(),Rect2(-100,-170,300,330))
		diagram.draw_rect(Rect2(-25,-130,110,62),c,false,3)
		for x in [0,55]:
			diagram.draw_circle(Vector2(x,-100),12,c)
		diagram.draw_rect(Rect2(-35,-50,130,110),c,false,3)
		diagram.draw_line(Vector2(-35,-20),Vector2(-75,40),c,7)
		diagram.draw_line(Vector2(95,-20),Vector2(135,40),c,7)
		diagram.draw_circle(Vector2(30,100),34,c,false,4)
		if cargo:
			diagram.draw_circle(Vector2(30,10),28,Color("9bcf70"))
	else:
		diagram.draw_circle(Vector2(30,-20),110,c,false,4)
		var pointer := Vector2(-sin(robot.heading()),-cos(robot.heading()))*80
		diagram.draw_line(Vector2(30,-20),Vector2(30,-20)+pointer,Color("efbf75"),5)

func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("112b38")
	return style

func host_game() -> void:
	if running or (multiplayer.multiplayer_peer is ENetMultiplayerPeer):
		return
	var peer := ENetMultiplayerPeer.new()
	# This game sends every command through the host; client-to-client relaying
	# is unnecessary and can race when several clients close simultaneously.
	multiplayer.server_relay=false
	var error := peer.create_server(server_port,2)
	if error != OK:
		lobby_text.text = "Cannot host on UDP %d (error %d)." % [server_port,error]
		return
	multiplayer.multiplayer_peer = peer
	roles = {1:0}
	role = 0
	lobby_text.text = "Hosting. You are HEAD. Waiting for HANDS and WHEEL…"

func join_game() -> void:
	if running or (multiplayer.multiplayer_peer is ENetMultiplayerPeer):
		return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address.text.strip_edges(),server_port)
	if error != OK:
		lobby_text.text = "Cannot connect (error %d)." % error
		return
	multiplayer.multiplayer_peer = peer
	lobby_text.text = "Connecting…"

func peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	var used := roles.values()
	for candidate in [1,2]:
		if candidate not in used:
			roles[id] = candidate
			break
	update_roster.rpc(roles)
	if automation and roles.size() == 3:
		start_network()

func peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	if roles.get(id,-1) == 1:
		last_jump = 0
	roles.erase(id)
	# Keep the ending visible when clients close their completed session.
	if completed:
		return
	robot.drive_input = Vector2.ZERO
	interact_held = false
	robot.brace = false
	robot.set_simulation(false)
	if running:
		running = false
		pause_session()
	call_deferred("broadcast_disconnect")

func broadcast_disconnect() -> void:
	# Allow simultaneous ENet disconnect events to drain before sending again.
	update_roster(roles)
	for peer_id in multiplayer.get_peers():
		pause_session.rpc_id(peer_id)
		update_roster.rpc_id(peer_id,roles)

@rpc("authority","call_local","reliable")
func update_roster(roster: Dictionary) -> void:
	roles = roster
	role = int(roles.get(multiplayer.get_unique_id(),0))
	lobby_text.text = "Your role: %s\nConnected: %d / 3. Host starts when everyone is ready.\nReconnect fills the vacant role; host can resume." % [ROLE_NAMES[role],roles.size()]
	start_button.disabled = not multiplayer.is_server() or roles.size() != 3

@rpc("authority","call_local","reliable")
func pause_session() -> void:
	running = false
	lobby.visible = true
	hud.visible = false
	robot.set_simulation(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func server_lost() -> void:
	pause_session()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	lobby_text.text = "Host disconnected. Restart the game to create or join a new session."

func connection_failed() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	lobby_text.text = "Connection failed. Check address and UDP port %d, then try Join again." % server_port

func start_network() -> void:
	if multiplayer.is_server() and roles.size() == 3:
		begin_session.rpc()

func start_solo() -> void:
	if (multiplayer.multiplayer_peer is ENetMultiplayerPeer):
		return
	solo = true
	role = 0
	begin_session()

@rpc("authority","call_local","reliable")
func begin_session() -> void:
	running = true
	lobby.visible = false
	hud.visible = true
	blackout.visible = role != 0
	camera.cull_mask = 0 if role != 0 else 1048575
	diagram.visible = role != 0
	# The overlay is display-only. GUI controls must not swallow mouse motion.
	ignore_hud_mouse(hud)
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	robot.set_simulation(authority() and stage < Layout.COMPLETE,not authority())
	if DisplayServer.get_name() != "headless":
		get_window().title="Blindy — " + ("Solo test" if solo else ROLE_NAMES[role])
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	announce("Central processor missing. Auxiliary controllers connected.")

func announce(text: String) -> void:
	announcement = text
	announcement_time = 9

func ignore_hud_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		ignore_hud_mouse(child)

func _input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventMouseMotion and (solo or role == 0) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw = wrapf(yaw-event.relative.x*0.002,-PI,PI)
		pitch = clampf(pitch-event.relative.y*0.002,-0.95,0.95)
		if event.relative.length() > 2:
			looked = true
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.physical_keycode == KEY_SPACE and (solo or role == 1):
			jump_sequence += 1
		elif event.physical_keycode == KEY_F3:
			factory.set_quality(not factory.quality_high)
		elif event.physical_keycode == KEY_R and solo:
			restore_checkpoint()

func pressed(key: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(key) else 0.0

func local_input() -> Dictionary:
	return {"drive":Vector2(clampf(pressed(KEY_D)+pressed(KEY_RIGHT)-pressed(KEY_A)-pressed(KEY_LEFT),-1,1),clampf(pressed(KEY_S)+pressed(KEY_DOWN)-pressed(KEY_W)-pressed(KEY_UP),-1,1)), "brace":pressed(KEY_SHIFT)>0, "jump":jump_sequence, "interact":pressed(KEY_E)>0, "yaw":yaw, "pitch":pitch, "looked":looked}

@rpc("any_peer","call_remote","unreliable_ordered",1)
func submit_input(data: Dictionary) -> void:
	if not multiplayer.is_server() or not running:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender not in roles:
		return
	apply_input(int(roles[sender]),data)

func apply_input(input_role: int, data: Dictionary) -> void:
	input_age[input_role] = 0.0
	if input_role == 0:
		var y := float(data.get("yaw",0))
		var p := float(data.get("pitch",0))
		if is_finite(y) and is_finite(p):
			yaw = wrapf(y,-PI,PI)
			pitch = clampf(p,-0.95,0.95)
		looked = looked or bool(data.get("looked",false))
	elif input_role == 1:
		robot.brace = bool(data.get("brace",false))
		interact_held = bool(data.get("interact",false))
		var sequence := int(data.get("jump",0))
		if sequence > last_jump:
			if sequence > 0:
				robot.jump_requested = true
				jump_practiced = true
			last_jump = sequence
	elif input_role == 2:
		var drive: Vector2 = data.get("drive",Vector2.ZERO)
		if is_finite(drive.x) and is_finite(drive.y):
			# Wheel's forward is robot heading; head look is independent.
			robot.drive_input = drive.clamp(Vector2(-1,-1),Vector2(1,1))
			drove = drove or drive.length() > 0.1

func can_interact() -> bool:
	return stage < Layout.COMPLETE and dock_distance() <= 1.4 and robot.velocity.length() < 0.18 and robot.angular_velocity.length() < 0.15 and not robot.recovering and robot.is_on_floor() and (stage != 0 or (looked and drove)) and (encounter_id() != "departure" or cargo)

func dock_distance() -> float:
	if stage >= DOCKS.size():
		return INF
	var target: Vector3 = DOCKS[stage]
	return Vector2(robot.position.x-target.x,robot.position.z-target.z).length()

func interaction_hint() -> String:
	if completed:
		return "LEVEL COMPLETE — ASSEMBLY REQUIRED\nThe sapling is safe. Level 2: Handle With Care (coming next)."
	if stage == Layout.COMPLETE:
		return "Lift ascending…"
	if stage == 0 and not looked:
		return "HEAD: look around with the mouse. Find the illuminated EXIT sign."
	if dock_distance() > 1.4:
		return "Move closer to the active cyan docking circle."
	if robot.velocity.length() >= 0.18 or robot.angular_velocity.length() >= 0.15:
		return "Stop to interact — release throttle and steering."
	if not robot.is_on_floor():
		return "Land before interacting."
	return "HANDS: hold E — " + ACTIONS[stage]

func advance_objective() -> void:
	if not can_interact():
		return
	var id := encounter_id()
	stage += 1
	hold_progress=0
	play_tone()
	match id:
		"release":
			save_checkpoint(Vector3(0,0.1,-4),stage,false)
			announce("Cradle released. Follow amber lights. Steer around the sorting stacks.")
		"sorting":
			announce("Sorting gate open. The service bridge is retracted. Find its console.")
		"bridge":
			bridge_time=0
			announce("Bridge extending. Wait for the gate to open, then cross together.")
		"shutter":
			announce("Shutter open. Another broken conveyor ahead. Call your jump.")
		"seal":
			announce("Greenhouse seal released. There is something alive inside.")
		"pickup":
			cargo=true
			save_checkpoint(Vector3(-2,0.1,-118),stage,true)
			announce("If anything survives, bring it to the surface.")
			animate_pickup()
		"power":
			save_checkpoint(Vector3(3,0.1,-136),stage,true)
			announce("Lift power restored. Park inside the amber doorway.")
		"departure":
			robot.finished=true
			robot.velocity=Vector3.ZERO
			robot.set_simulation(false)
			announce("Greenhouse specimen removed. Please return to safety.")

func animate_pickup() -> void:
	robot.cradle.visible = true
	robot.cradle.global_position = shelf_plant.global_position
	create_tween().tween_property(robot.cradle,"position",Vector3(0,1.57,-0.76),0.75).set_trans(Tween.TRANS_SINE)

func save_checkpoint(at: Vector3, objective_stage: int, has_cargo: bool, safe_heading: float=0.0) -> void:
	checkpoint = at
	checkpoint_heading = safe_heading
	robot.checkpoint_heading = safe_heading
	checkpoint_stage = objective_stage
	checkpoint_cargo = has_cargo
	robot.checkpoint_position = at

func restore_checkpoint() -> void:
	stage = checkpoint_stage if stage > 0 else 0
	cargo = checkpoint_cargo if stage > 0 else false
	robot.checkpoint_position = checkpoint if stage > 0 else robot.START
	robot.checkpoint_heading = checkpoint_heading
	robot.reset_robot()
	if running and authority():
		robot.set_simulation(true)
	lift.position=Layout.LIFT
	lift_gate.visible=false
	lift_gate.process_mode=Node.PROCESS_MODE_DISABLED
	hold_progress = 0
	lift_time = 0
	completed = false
	bridge_time = 2.0 if stage >= encounter_index("shutter") else 0.0
	robot.cradle.position = Vector3(0,1.57,-0.76)
	announce("Checkpoint restored. All controllers connected. Try again.")

func update_level(delta: float) -> void:
	if stage >= encounter_index("shutter"):
		bridge_time=minf(2.0,bridge_time+delta)
	if encounter_id() == "shutter" and robot.position.z < -62 and robot.position.z > -65 and checkpoint.z > -61.6:
		save_checkpoint(Layout.GAP_CHECKPOINTS[0],stage,false)
		announce("Conveyor checkpoint. Build speed, then call your jump.")
	if encounter_id() == "seal" and robot.position.z < -83 and robot.position.z > -86 and checkpoint.z > -82.6:
		save_checkpoint(Layout.GAP_CHECKPOINTS[1],stage,false)
		announce("Second conveyor checkpoint. Wide landing ahead.")
	if can_interact() and interact_held:
		hold_progress+=delta
		if hold_progress>=hold_duration():
			advance_objective()
	else:
		hold_progress=0
	if stage == Layout.COMPLETE:
		lift_time+=delta
		var rise := smoothstep(0,1,clampf((lift_time-1)/5,0,1))*7
		lift.position.y=0.4+rise
		robot.position.y=0.55+rise
		if lift_time>6 and not completed:
			completed=true
			announcement="Three minds. One small life. A little further."
			if not solo:
				confirm_completion.rpc(robot.position,robot.quaternion)
	near_obstacle=proximity()

func proximity() -> String:
	var origin := robot.position+Vector3(0,0.8,0)
	var hits: Array[String] = []
	for pair in [[Vector3(0,0,-1),"FRONT"],[Vector3(-1,0,0),"LEFT"],[Vector3(1,0,0),"RIGHT"]]:
		var query := PhysicsRayQueryParameters3D.create(origin,origin+Basis(Vector3.UP,robot.heading())*pair[0]*1.6)
		query.exclude = [robot.get_rid()]
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			hits.append(pair[1])
	return "CLEAR" if hits.is_empty() else "NEAR: " + ", ".join(hits)

func _physics_process(delta: float) -> void:
	if not running:
		return
	if authority():
		for key in input_age:
			input_age[key] += delta
		if input_age[2] > 0.5:
			robot.drive_input = Vector2.ZERO
		if input_age[1] > 0.5:
			interact_held = false
			robot.brace = false
		update_level(delta)
		bump_cooldown -= delta
		if robot.get_slide_collision_count()>0 and robot.drive_input.length()>0.1 and Vector2(robot.velocity.x,robot.velocity.z).length()<0.3 and bump_cooldown<=0:
			play_tone()
			bump_cooldown = 1.5
	else:
		robot.position = robot.position.lerp(target_position,minf(1,delta*18))
		robot.quaternion = robot.quaternion.slerp(target_rotation,minf(1,delta*18))
		robot.wheel.rotation.x -= robot.signed_speed()/robot.tire_radius*delta
		robot.cradle.rotation.z = 0

func _process(delta: float) -> void:
	if not running:
		return
	if completed:
		apply_presentation(delta)
		return
	network_tick += delta
	if network_tick >= 1.0/30:
		network_tick = 0
		var data := local_input()
		if solo:
			for r in [0,1,2]:
				apply_input(r,data)
		elif multiplayer.is_server():
			apply_input(role,data)
		else:
			submit_input.rpc_id(1,data)
		if not solo and multiplayer.is_server():
			broadcast_snapshot()
	apply_presentation(delta)

func broadcast_snapshot() -> void:
	if completed:
		return
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer == null:
		return
	var snapshot := make_snapshot()
	for id in multiplayer.get_peers():
		var packet_peer := peer.get_peer(id)
		if packet_peer != null and packet_peer.get_state()==ENetPacketPeer.STATE_CONNECTED:
			receive_state.rpc_id(id,snapshot)

@rpc("authority","call_remote","reliable")
func confirm_completion(final_position: Vector3, final_orientation: Quaternion) -> void:
	completed=true
	cargo=true
	stage=Layout.COMPLETE
	lift_time=6.1
	target_position=final_position
	target_rotation=final_orientation
	robot.position=final_position
	robot.quaternion=final_orientation
	robot.velocity=Vector3.ZERO
	robot.angular_velocity=Vector3.ZERO
	announcement="Three minds. One small life. A little further."

func make_snapshot() -> Dictionary:
	return {"position":robot.position,"velocity":robot.velocity,"orientation":robot.quaternion,"angular_velocity":robot.angular_velocity,"recovering":robot.recovering,"recovery_time":robot.recovery_time,"checkpoint_heading":checkpoint_heading,"visual_offset":robot.visual.position,"visual_rotation":robot.visual.rotation,"stage":stage,"cargo":cargo,"yaw":yaw,"pitch":pitch,"looked":looked,"drove":drove,"grounded":robot.is_on_floor(),"hold":hold_progress,"lift":lift_time,"complete":completed,"announcement":announcement,"announcement_time":announcement_time,"proximity":near_obstacle,"checkpoint":checkpoint,"checkpoint_stage":checkpoint_stage,"checkpoint_cargo":checkpoint_cargo,"bridge_time":bridge_time}

@rpc("authority","call_remote","unreliable_ordered",2)
func receive_state(state: Dictionary) -> void:
	if state.stage != stage:
		play_tone()
	if state.cargo and not cargo:
		animate_pickup()
	target_position = state.position
	target_rotation = state.orientation
	robot.visual.position = state.visual_offset
	robot.visual.rotation = state.visual_rotation
	robot.angular_velocity = state.angular_velocity
	robot.recovering = state.recovering
	robot.recovery_time = state.recovery_time
	checkpoint_heading = state.checkpoint_heading
	if robot.position.distance_to(target_position)>3:
		robot.position = target_position
	robot.velocity = state.velocity
	stage = state.stage
	cargo = state.cargo
	yaw = state.yaw
	pitch = state.pitch
	looked = state.looked
	drove = state.drove
	remote_grounded = state.grounded
	hold_progress = state.hold
	lift_time = state.lift
	completed = state.complete
	announcement = state.announcement
	announcement_time = state.announcement_time
	near_obstacle = state.proximity
	checkpoint = state.checkpoint
	checkpoint_stage = state.checkpoint_stage
	checkpoint_cargo = state.checkpoint_cargo
	bridge_time = state.bridge_time

func apply_presentation(delta: float) -> void:
	if authority():
		announcement_time = maxf(0,announcement_time-delta)
	for i in range(gates.size()):
		var opened := stage > encounter_index(gate_ids[i])
		if gate_ids[i] == "bridge":
			opened = opened and bridge_time >= 2.0
		gates[i].visible = not opened
		gates[i].process_mode = Node.PROCESS_MODE_DISABLED if opened else Node.PROCESS_MODE_INHERIT
	for i in range(dock_markers.size()):
		dock_markers[i].visible = i == stage
	bridge.position.y = lerpf(-3.0,-0.4,bridge_time/2.0)
	bridge.process_mode = Node.PROCESS_MODE_INHERIT if bridge_time >= 2.0 else Node.PROCESS_MODE_DISABLED
	robot.cradle.visible = cargo
	shelf_plant.visible = not cargo and stage <= encounter_index("pickup")
	robot.visual.head.visible = false if role == 0 else true
	# Keep the camera ahead of the head shell; body/cargo stay below its view.
	camera.position = robot.global_transform*Vector3(0,2.84,-0.49)
	camera.rotation = Vector3(pitch,robot.heading()+yaw,0)
	robot.visual.head.rotation.y = yaw
	robot.visual.head.rotation.x = pitch
	recovery_fade.color.a = clampf(1.0-robot.recovery_time/0.4,0,1) if robot.recovering else 0.0
	if stage == Layout.COMPLETE:
		lift.position.y = 0.4+smoothstep(0,1,clampf((lift_time-1)/5,0,1))*7
		lift_gate.visible = true
		lift_gate.process_mode = Node.PROCESS_MODE_INHERIT
	var role_text: String = "SOLO TEST / ALL CONTROLS" if solo else ROLE_NAMES[role]
	title.text = "ASSEMBLY REQUIRED / " + role_text
	objective.text = OBJECTIVES[stage]
	var grounded: bool = robot.is_on_floor() if authority() else remote_grounded
	if solo or role == 0:
		telemetry.text = "HEAD: mouse look. Describe the route to your teammates.\nAmber lights: destination. Cyan circles: stop and interact.\n" + ("SOLO: W/S throttle · A/D steer · Space jump · E hold interact · Shift brace · R checkpoint" if solo else "Your teammates control movement, jumping and interaction.")
	elif role == 1:
		telemetry.text = "HANDS / BODY\nSpace: jump · Hold E: interact · Shift: brace\nJump: %s\nCargo: %s" % ["READY" if grounded else "AIRBORNE", "SECURED / automatic stabilization" if cargo else "EMPTY"]
	else:
		telemetry.text = "WHEEL / W,S or ↑,↓: throttle · A,D or ←,→: steer\nSpeed: %.1f m/s · Heading: %.0f°\nTilt: %.1f° · %s\n%s" % [Vector2(robot.velocity.x,robot.velocity.z).length(),fposmod(-rad_to_deg(robot.heading()),360.0),robot.tilt_degrees(),near_obstacle,"FRAGILE CARGO SECURED" if cargo else "Cargo bay empty"]
	prompt.text = interaction_hint() if authority() or role != 0 else OBJECTIVES[stage]
	# Remote interaction hints use replicated grounding rather than client physics.
	if not authority() and stage < Layout.COMPLETE and dock_distance()<=1.4 and robot.velocity.length()<0.18 and robot.angular_velocity.length()<0.15 and not robot.recovering and remote_grounded:
		prompt.text = "HANDS: hold E — " + ACTIONS[stage]
	progress.value = hold_progress/hold_duration()*100
	progress.visible = hold_progress>0
	notice.text = announcement if announcement_time>0 or completed else ""
	diagram.queue_redraw()
	if robot.position.z < -104 and not greenhouse_music:
		greenhouse_music = true
		music.play()
		hum.volume_db = -38
	if authority() and stage == Layout.COMPLETE:
		robot.visual.head.visible = role != 0

func synth(frequency: float, seconds: float, amplitude: float) -> AudioStreamWAV:
	var rate := 22050
	var bytes := PackedByteArray()
	bytes.resize(int(seconds*rate)*2)
	for i in range(bytes.size()/2):
		var t := float(i)/rate
		var envelope := minf(1,t*20)*minf(1,(seconds-t)*10)
		var value := int(sin(TAU*frequency*t)*amplitude*envelope*32760)
		bytes.encode_s16(i*2,value)
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = rate
	audio.data = bytes
	return audio

func build_audio() -> void:
	tone = AudioStreamPlayer.new()
	tone.stream = synth(180,0.16,0.18)
	add_child(tone)
	music = AudioStreamPlayer.new()
	music.stream = synth(523.25,3,0.08)
	add_child(music)
	hum = AudioStreamPlayer.new()
	var loop := synth(60,4,0.06)
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = 4*22050
	hum.stream = loop
	hum.volume_db = -22
	add_child(hum)
	hum.play()

func play_tone() -> void:
	if is_instance_valid(tone):
		tone.play()

func _exit_tree() -> void:
	for player in [tone,music,hum]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null

