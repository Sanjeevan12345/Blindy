extends Node3D

const Robot = preload("res://scripts/robot.gd")
var robot: RigidBody3D
var camera: Camera3D
var status: Label
var message: Label
var balance_bar: ProgressBar
var water_bar: ProgressBar
var elapsed := 0.0
var look_offset := 0.0

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("101f2a"))
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("101f2a")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("9dc5d3")
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_color = Color("ffd6a0")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	add_child(sun)
	build_course()
	robot = Robot.new()
	robot.name = "Robot"
	add_child(robot)
	camera = Camera3D.new()
	camera.fov = 58
	add_child(camera)
	camera.current = true
	build_hud()

func block(pos: Vector3, size: Vector3, color: Color, solid: bool = true) -> Node3D:
	var body: Node3D = StaticBody3D.new() if solid else Node3D.new()
	body.position = pos
	add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	mesh.material_override = material
	body.add_child(mesh)
	if solid:
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		body.add_child(collider)
	return body

func signpost(text: String, pos: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.font_size = 36
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("b9edf1")
	add_child(label)

func build_course() -> void:
	# Connected platforms with a short, forgiving jump gap.
	block(Vector3(0, -0.4, 2), Vector3(12, 0.8, 14), Color("354956"))
	block(Vector3(0, -0.4, -10), Vector3(8, 0.8, 7), Color("354956"))
	block(Vector3(0, -0.4, -20), Vector3(12, 0.8, 13), Color("354956"))
	for z in range(-25, 9, 2):
		block(Vector3(-5.8, 0.13, z), Vector3(0.12, 0.10, 0.7), Color("e6ac56"), false)
		block(Vector3(5.8, 0.13, z), Vector3(0.12, 0.10, 0.7), Color("e6ac56"), false)
	# Staggered obstructions encourage steering and steadying the pot.
	block(Vector3(-2.5, 0.75, -0.8), Vector3(3.4, 1.5, 1.5), Color("576774"))
	block(Vector3(2.5, 0.75, -3.2), Vector3(3.4, 1.5, 1.2), Color("576774"))
	block(Vector3(0, 0.12, -17), Vector3(7, 0.2, 3), Color("bf8747")).rotation.x = 0.16
	block(Vector3(0, 0.12, -20), Vector3(7, 0.2, 3), Color("bf8747")).rotation.x = -0.16
	# Factory shell, supports and overhead beams.
	for x in [-7.0, 7.0]:
		block(Vector3(x, -0.8, -8), Vector3(0.5, 1, 37), Color("243743"), false)
		for z in [5, -5, -15, -25]:
			block(Vector3(x * 0.88, 3.8, z), Vector3(0.45, 8, 0.45), Color("405765"), false)
			block(Vector3(0, 7.2, z), Vector3(13, 0.3, 0.3), Color("405765"), false)
	block(Vector3(-2, 2, -25), Vector3(0.55, 4, 0.7), Color("e4b65d"))
	block(Vector3(2, 2, -25), Vector3(0.55, 4, 0.7), Color("e4b65d"))
	block(Vector3(0, 4, -25), Vector3(4.5, 0.5, 0.7), Color("e4b65d"))
	block(Vector3(0, 0.04, -24), Vector3(3.5, 0.08, 3), Color("60bfa7"), false)
	signpost("01 / ASSEMBLY REQUIRED", Vector3(-3.5, 3.8, 5))
	signpost("JUMP THE GAP", Vector3(0, 3.4, -6))
	signpost("DELIVER THE SAPLING", Vector3(0, 5.0, -25))

func build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(22, 20)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.075, 0.10, 0.94)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.border_width_left = 3
	style.border_color = Color("70d3d9")
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var title := Label.new()
	title.text = "BLINDY  /  A LITTLE FURTHER"
	title.add_theme_font_size_override("font_size", 25)
	title.modulate = Color("f0c273")
	column.add_child(title)
	var controls := Label.new()
	controls.text = "STAGE 1 · LOCAL MECHANICS PROTOTYPE\n\nWHEEL   W/S throttle · A/D or arrows steer / release to brake\nHANDS   Space  jump · J / L  balance · Shift  brace\nHEAD     U / O  orbit camera\nF2  inspect robot · R  restart · Esc  quit\n\nCarry the sapling to the green exit pad.\nBrace slows driving and protects the cargo."
	column.add_child(controls)
	status = Label.new()
	column.add_child(status)
	var balance_label := Label.new()
	balance_label.text = "CARGO LEAN  /  centre is safe"
	column.add_child(balance_label)
	balance_bar = ProgressBar.new()
	balance_bar.custom_minimum_size = Vector2(360, 16)
	balance_bar.show_percentage = false
	column.add_child(balance_bar)
	var water_label := Label.new()
	water_label.text = "WATER  /  spills are recoverable"
	column.add_child(water_label)
	water_bar = ProgressBar.new()
	water_bar.custom_minimum_size = Vector2(360, 16)
	column.add_child(water_bar)
	message = Label.new()
	message.position = Vector2(430, 28)
	message.add_theme_font_size_override("font_size", 22)
	message.modulate = Color("aff1d6")
	layer.add_child(message)

func down(key: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(key) else 0.0

func _process(delta: float) -> void:
	robot.drive_input = Vector2(clampf(down(KEY_D)+down(KEY_RIGHT)-down(KEY_A)-down(KEY_LEFT),-1,1),clampf(down(KEY_S)+down(KEY_DOWN)-down(KEY_W)-down(KEY_UP),-1,1))
	robot.balance_input = down(KEY_J) - down(KEY_L)
	robot.brace = Input.is_physical_key_pressed(KEY_SHIFT)
	look_offset += (down(KEY_O) - down(KEY_U)) * delta
	var offset := Vector3(9 * sin(look_offset + 0.65), 6.5, 9 * cos(look_offset + 0.65))
	camera.position = robot.position + offset
	camera.look_at(robot.position + Vector3(0, 1.3, 0))
	if not robot.finished:
		elapsed += delta
		if robot.position.z < -23 and absf(robot.position.x) < 1.6 and robot.is_on_floor():
			robot.finished = true
			message.text = "DELIVERY COMPLETE\n%s seconds · %d spills\nPress R to try again" % [str(snappedf(elapsed, 0.1)), robot.spills]
		elif robot.water <= 0:
			message.text = "Water depleted — keep going!\nPress R to refill and retry."
		elif absf(robot.cargo_tilt) > 0.5:
			message.text = "Cargo tipping!\nCounterbalance with J / L or hold Shift."
		else:
			message.text = "Reach the exit. Protect the sapling."
	status.text = "Speed  %.1f  |  Time  %.1fs  |  Spills  %d" % [Vector2(robot.velocity.x, robot.velocity.z).length(), elapsed, robot.spills]
	balance_bar.value = (robot.cargo_tilt + 1.1) / 2.2 * 100
	water_bar.value = robot.water

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F2:
			get_tree().change_scene_to_file("res://scenes/robot_showcase.tscn")
		elif event.physical_keycode == KEY_SPACE:
			robot.jump_requested = true
		elif event.physical_keycode == KEY_R:
			robot.reset_robot()
			elapsed = 0
		elif event.physical_keycode == KEY_ESCAPE:
			get_tree().quit()
