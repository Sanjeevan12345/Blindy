extends SceneTree
## Run without --headless: verifies real mouse capture and dispatched input.
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	print(("PASS: " if value else "FAIL: ")+description)
	if not value:
		failures += 1

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func key(code: Key, held: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = held
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run() -> void:
	var level = load("res://scenes/main.tscn").instantiate()
	root.add_child(level)
	var box = level.lobby.get_child(0)
	var solo_button: Button
	for child in box.get_children():
		if child is Button and child.text.begins_with("Solo test — all controls"):
			solo_button = child
	solo_button.grab_focus()
	solo_button.pressed.emit()
	await frames(10)
	check(level.running and level.solo,"Solo lobby button starts gameplay")
	check(root.gui_get_focus_owner()==null,"Lobby focus released on game start")
	check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Mouse captured in solo")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(45,-20)
	motion.screen_relative = motion.relative
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await process_frame
	await frames(5)
	check(absf(level.yaw)>0.01 and absf(level.pitch)>0.01 and level.looked,"Dispatched mouse motion turns view and satisfies tutorial")
	check(absf(level.camera.rotation.y)>0.01,"Camera follows mouse yaw")
	key(KEY_ESCAPE,true)
	await frames(2)
	key(KEY_ESCAPE,false)
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Esc releases mouse")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(40,40)
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await process_frame
	await frames(2)
	var release := click.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await process_frame
	check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Click over HUD recaptures mouse")
	key(KEY_W,true)
	for i in range(160):
		var stopping_distance: float=pow(maxf(0,level.robot.signed_speed()),2)/(2*level.robot.braking)
		if level.robot.position.z<level.DOCKS[0].z+stopping_distance+0.4:
			break
		await physics_frame
	key(KEY_W,false)
	await frames(70)
	print("SOLO DOCK: pos=%s v=%s angular=%s grounded=%s looked=%s" % [level.robot.position,level.robot.velocity,level.robot.angular_velocity,level.robot.grounded,level.looked])
	check(level.drove and level.can_interact(),"Driving into docking zone enables lever")
	key(KEY_E,true)
	await frames(65)
	key(KEY_E,false)
	await frames(3)
	check(level.stage==1,"Holding physical E opens release gate through actual input loop")
	var old_yaw: float=level.robot.heading()
	key(KEY_RIGHT,true)
	await frames(30)
	key(KEY_RIGHT,false)
	await frames(60)
	check(wrapf(level.robot.heading()-old_yaw,-PI,PI)< -0.25,"Right arrow physically steers chassis clockwise")
	check(absf(wrapf(level.camera.rotation.y-level.robot.heading()-level.yaw,-PI,PI))<0.01 and absf(level.camera.rotation.z)<0.01,"Rendered camera follows chassis and keeps horizon level")
	print("Solo input checks: %d failures" % failures)
	quit(1 if failures else 0)
