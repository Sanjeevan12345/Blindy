extends SceneTree
var failures := 0

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		push_error("FAIL: " + description)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func run() -> void:
	var scene = load("res://scenes/prototype.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var bot = scene.robot
	await frames(90)
	check(bot.is_on_floor(), "Robot settles on starting platform")
	var start_z: float = bot.position.z
	bot.drive_input = Vector2(0, -1)
	await frames(72) # 3.5 m/s² acceleration replaces the instantaneous controller.
	check(bot.position.z < start_z - 1, "Wheel commands move robot")
	bot.drive_input = Vector2.ZERO
	await frames(120)
	check(absf(bot.velocity.z) < 0.05, "Release brakes robot")
	var floor_y: float = bot.position.y
	bot.jump_requested = true
	await frames(15)
	check(bot.position.y > floor_y + 0.4, "Body command jumps")
	await frames(90)
	bot.cargo_tilt = 0.6
	bot.balance_input = -1
	await frames(20)
	check(absf(bot.cargo_tilt) < 0.4, "Hands counterbalance cargo")
	bot.balance_input = 0
	bot.cargo_tilt = 0.9
	await frames(2)
	check(bot.water < 100 and bot.spills > 0, "Excess tilt spills water")
	bot.brace = true
	await frames(60)
	check(absf(bot.cargo_tilt) < 0.2, "Bracing settles cradle")
	bot.brace = false
	bot.position.y = -8
	await frames(60) # Recovery now includes a short fade and physics teleport.
	check(bot.position.y > -1 and bot.water == 100, "Falling resets robot and water")
	bot.reset_robot()
	await frames(90)
	bot.drive_input = Vector2(0, -1)
	var jumped := false
	for i in range(600):
		if bot.position.z < -3.8 and not jumped:
			bot.jump_requested = true
			jumped = true
		var stopping_distance: float=pow(maxf(0,bot.signed_speed()),2)/(2*bot.braking)
		if bot.position.z < -23.5+stopping_distance+0.35:
			break
		await physics_frame
	bot.drive_input = Vector2.ZERO
	await frames(50)
	scene._process(0)
	check(bot.finished, "Full course traversal triggers delivery (position: %s)" % bot.position)
	bot.reset_robot()
	check(not bot.finished and bot.water == 100 and bot.spills == 0, "Restart clears state")
	print("Smoke checks complete: %d failures" % failures)
	quit(1 if failures else 0)
