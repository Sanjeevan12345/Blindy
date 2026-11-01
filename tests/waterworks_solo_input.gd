extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	print(("PASS: " if value else "FAIL: ")+label)
	if not value: failures+=1
func frames(n: int) -> void:
	for i in range(n): await physics_frame
func key(code: Key,held: bool) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=held
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func run() -> void:
	var second=load("res://scenes/level_two.tscn").instantiate()
	root.add_child(second)
	current_scene=second
	second.start_solo()
	second.completed=true
	second.stage=second.Layout.COMPLETE
	key(KEY_N,true)
	await process_frame
	key(KEY_N,false)
	await frames(90)
	var level=current_scene
	check(level.level_number==3 and level.running and level.solo,"Physical N continues Level 2 into Waterworks")
	check(level.cargo and level.robot.auto_stabilize,"Campaign keeps cargo and stabilizer repair")
	check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Mouse remains captured after campaign handoff")
	var before: float=level.yaw
	var mouse := InputEventMouseMotion.new()
	mouse.relative=Vector2(30,0)
	Input.parse_input_event(mouse)
	Input.flush_buffered_events()
	await frames(2)
	check(level.yaw!=before,"Mouse look works in Level 3 solo")
	level.robot.teleport(Vector3(0,0.1,0),0)
	await frames(90)
	key(KEY_E,true)
	await frames(65)
	check(level.engaged=="training","Physical held E engages nearby valve")
	key(KEY_E,false)
	await frames(10)
	key(KEY_L,true)
	await frames(120)
	key(KEY_L,false)
	check(level.pressure>30 and level.pressure<50,"Physical L input raises valve pressure")
	await frames(200)
	check(level.flags.training,"Maintaining pressure completes training through real input loop")
	key(KEY_J,true)
	await frames(15)
	key(KEY_J,false)
	check(level.robot.auto_stabilize and level.robot.water==100,"Valve controls do not damage repaired cargo")
	level.solo=false
	level.role=1
	level.begin_session()
	level.apply_presentation(0)
	check(level.camera.cull_mask==0 and level.blackout.visible and level.instruments.visible,"Hands has private pressure instruments without room view")
	check(not level.target_labels.training.visible,"Hands cannot see the target gauge")
	level.role=2
	level.begin_session()
	level.apply_presentation(0)
	check(level.camera.cull_mask==0 and not level.instruments.visible,"Wheel retains a private mechanical dashboard")
	print("Waterworks graphical input checks: %d failures" % failures)
	quit(1 if failures else 0)
