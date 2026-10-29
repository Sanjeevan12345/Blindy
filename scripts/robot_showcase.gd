extends Node3D
## Art inspection room: arrows orbit, up/down zoom, F2 returns to gameplay.
var camera: Camera3D
var angle := -0.58
var distance := 6.9

func _ready() -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("192831")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("bacbd4")
	world.environment.ambient_light_energy = 0.45
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35,-35,0)
	key.light_color = Color("ffe1b8")
	key.light_energy = 0.95
	key.shadow_enabled = true
	add_child(key)
	for entry in [[Vector3(-3,3,-2),Color("b5e4ff"),0.65],[Vector3(2,4,2),Color("ffd59c"),1.0]]:
		var light := OmniLight3D.new()
		light.position = entry[0]
		light.light_color = entry[1]
		light.light_energy = entry[2]
		light.omni_range = 9
		add_child(light)
	var asset := preload("res://scenes/robot_visual.tscn").instantiate()
	add_child(asset)
	var floor_mesh := MeshInstance3D.new()
	var plane := CylinderMesh.new()
	plane.top_radius = 2.3
	plane.bottom_radius = 2.3
	plane.height = 0.10
	plane.radial_segments = 96
	floor_mesh.mesh = plane
	floor_mesh.position.y = -0.07
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("293c47")
	mat.roughness = 0.8
	floor_mesh.material_override = mat
	add_child(floor_mesh)
	camera = Camera3D.new()
	camera.fov = 39
	camera.current = true
	add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.position = Vector2(42,28)
	title.text = "BLINDY\nA LITTLE FURTHER"
	title.add_theme_font_size_override("font_size",30)
	title.modulate = Color("efc584")
	layer.add_child(title)
	var detail := Label.new()
	detail.position = Vector2(42,620)
	detail.text = "ROBOT / ART INSPECTION\nWeathered alloy · cyan optics · living cargo\n\n← →  Orbit     ↑ ↓  Zoom     F2  Play course"
	detail.add_theme_font_size_override("font_size",18)
	detail.modulate = Color("b4cdd3")
	layer.add_child(detail)
	update_camera()

func update_camera() -> void:
	camera.position = Vector3(sin(angle)*distance,3.1,-cos(angle)*distance)
	camera.look_at(Vector3(0,1.85,0))

func _process(delta: float) -> void:
	if Input.is_physical_key_pressed(KEY_LEFT):
		angle -= delta
	if Input.is_physical_key_pressed(KEY_RIGHT):
		angle += delta
	if Input.is_physical_key_pressed(KEY_UP):
		distance -= delta*2
	if Input.is_physical_key_pressed(KEY_DOWN):
		distance += delta*2
	distance = clampf(distance,4.4,9)
	update_camera()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F2:
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		elif event.physical_keycode == KEY_ESCAPE:
			get_tree().quit()
