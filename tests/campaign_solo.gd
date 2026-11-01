extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,text: String) -> void:
	print(("PASS: " if value else "FAIL: ")+text)
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
	var first=load("res://scenes/main.tscn").instantiate()
	root.add_child(first)
	current_scene=first
	first.start_solo()
	first.completed=true
	first.stage=first.Layout.COMPLETE
	key(KEY_N,true)
	await process_frame
	key(KEY_N,false)
	await frames(90)
	var second=current_scene
	check(second.level_number==2 and second.running and second.solo,"N continues a completed solo campaign into Level 2")
	check(second.cargo and not second.robot.auto_stabilize,"Sapling carried into manual-balance chapter")
	key(KEY_J,true)
	await frames(15)
	key(KEY_J,false)
	check(second.balance_practiced and second.robot.cargo_tilt>0,"Physical J input controls the cradle in solo")
	check(second.balance_label.visible and second.balance_meter.visible,"Solo displays the cargo balance instruments")
	second.robot.cargo_tilt=0.9
	await frames(3)
	check(second.robot.spills>0 and second.robot.water<100,"Unbalanced cargo can actually spill water")
	key(KEY_SHIFT,true)
	await frames(60)
	key(KEY_SHIFT,false)
	check(absf(second.robot.cargo_tilt)<0.3,"Physical brace input steadies the cradle")
	print("Solo campaign checks: %d failures" % failures)
	quit(1 if failures else 0)
