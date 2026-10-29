extends SceneTree
var bot
var failures := 0
var recoveries := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, text: String) -> void:
	print(("PASS: " if value else "FAIL: ")+text)
	if not value: failures+=1
func seconds(duration: float) -> void:
	for i in range(roundi(duration*Engine.physics_ticks_per_second)):
		await physics_frame
func reset(at: Vector3=Vector3(0,0.08,0), yaw: float=0) -> void:
	bot.checkpoint_position=at
	bot.checkpoint_heading=yaw
	bot.brace=false
	bot.reset_robot()
	await seconds(1)
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=Vector3(200,1,200)
	collider.shape=shape
	floor_body.position.y= -0.5
	floor_body.add_child(collider)
	world.add_child(floor_body)
	bot=load("res://scripts/robot.gd").new()
	world.add_child(bot)
	bot.auto_stabilize=true
	bot.fell.connect(func(): recoveries+=1)
	await reset()
	print("SETTLED: pos=%s tilt=%.2f grounded=%s" % [bot.position,bot.tilt_degrees(),bot.grounded])
	check(bot.is_on_floor() and bot.tilt_degrees()<5,"Robot settles upright on tire")
	var start: Vector3=bot.position
	bot.drive_input=Vector2(1,0)
	await seconds(1)
	check(bot.heading()< -0.4,"Right steering turns clockwise")
	check(Vector2(bot.position.x-start.x,bot.position.z-start.z).length()<0.25,"Stationary steering does not strafe")
	await reset(Vector3(0,0.08,0),-PI/2)
	bot.drive_input=Vector2(0,-1)
	await seconds(1)
	print("ACCEL: v=%s tilt=%.1f" % [bot.velocity,bot.tilt_degrees()])
	check(bot.velocity.x>2.5 and absf(bot.velocity.z)<0.4,"Forward drive follows rotated chassis")
	var accel_speed: float=bot.signed_speed()
	check(accel_speed<4.2,"Acceleration is gradual, not instantaneous")
	bot.drive_input=Vector2.ZERO
	await seconds(0.1)
	check(bot.velocity.length()>1,"Release preserves momentum while braking")
	await seconds(1.4)
	check(bot.velocity.length()<0.18,"Progressive brakes reach a docking stop")
	await reset()
	bot.drive_input=Vector2(0,-1)
	await seconds(3)
	check(bot.signed_speed()<=6.1 and bot.signed_speed()>5.4,"Forward speed limit is 6 m/s")
	bot.drive_input=Vector2(0,1)
	await seconds(0.2)
	check(bot.signed_speed()>0,"Opposite throttle brakes before reversing")
	await seconds(3)
	check(bot.signed_speed()< -2.6 and bot.signed_speed()>= -3.1,"Reverse speed limit is 3 m/s")
	var before: float=bot.heading()
	bot.drive_input=Vector2(1,1)
	await seconds(0.5)
	check(wrapf(bot.heading()-before,-PI,PI)< -0.1,"Right steering stays clockwise while reversing")
	await reset()
	bot.brace=true
	bot.drive_input=Vector2(0,-1)
	await seconds(2)
	check(bot.signed_speed()<2.6 and bot.center_of_mass.y<1,"Bracing lowers COM and limits speed")
	await reset()
	bot.drive_input=Vector2(0,-1)
	await seconds(1)
	bot.jump_requested=true
	await seconds(0.12)
	var airborne_horizontal := Vector2(bot.velocity.x,bot.velocity.z)
	check(not bot.is_on_floor() and bot.velocity.y>2,"Grounded jump launches")
	bot.drive_input=Vector2(1,1)
	bot.jump_requested=true
	await seconds(0.2)
	check(Vector2(bot.velocity.x,bot.velocity.z).distance_to(airborne_horizontal)<0.15,"No drive force or braking in air")
	check(bot.velocity.y<3.5,"Repeated airborne jump does not add impulse")
	await seconds(1.5)
	await reset()
	bot.teleport(Vector3(0,0.11,0))
	bot.velocity=Vector3(0,-0.5,0)
	# Teleport is applied by the integrator; queue jump just before the tire lands.
	await seconds(0.05)
	bot.jump_requested=true
	await seconds(0.15)
	check(bot.velocity.y>2,"Jump buffer launches on imminent landing")
	await reset(Vector3(0,0.08,-99.0))
	bot.drive_input=Vector2(0,-1)
	for i in range(120):
		await physics_frame
		if not bot.grounded:
			break
	bot.jump_requested=true
	await seconds(0.035)
	check(bot.velocity.y>2,"Coyote jump works just after leaving an edge")
	await reset()
	var stable_count := recoveries
	bot.quaternion=Quaternion(Vector3.FORWARD,deg_to_rad(25))
	await seconds(1.5)
	check(recoveries==stable_count and bot.tilt_degrees()<10,"Brief moderate lean stabilizes without checkpoint reset")
	await reset()
	bot.apply_central_impulse(Vector3(240,0,0))
	await seconds(0.05)
	check(absf(bot.velocity.x)>1,"Finite tire grip permits lateral slip")
	await reset()
	var old_count := recoveries
	bot.quaternion=Quaternion(Vector3.FORWARD,deg_to_rad(80))
	await seconds(2.5)
	check(recoveries>old_count and bot.tilt_degrees()<10,"Sustained tip recovers to checkpoint")
	await reset(Vector3(0,0.08,0),0.7)
	bot.jump_requested=true
	bot.reset_robot()
	await seconds(0.1)
	check(absf(bot.heading()-0.7)<0.05 and bot.angular_velocity.length()<0.1 and bot.jump_buffer==0,"Reset restores heading and clears momentum/jump")
	var speeds: Array=[]
	for rate in [30,60,120]:
		Engine.physics_ticks_per_second=rate
		await reset()
		bot.drive_input=Vector2(0,-1)
		await seconds(1)
		speeds.append(bot.signed_speed())
	Engine.physics_ticks_per_second=60
	print("TICK-RATE SPEEDS: ",speeds)
	check(float(speeds.max())-float(speeds.min())<0.4,"Acceleration comparable at 30/60/120 Hz")
	print("Steering physics checks: %d failures" % failures)
	quit(1 if failures else 0)
