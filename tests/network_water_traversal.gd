extends SceneTree
const Driver=preload("res://tests/steering_driver.gd")
var level
var ticks := 0
var switched := false
var dipped := false
var done_ticks := 0
var finished := false
func _initialize() -> void: call_deferred("setup")
func setup() -> void:
	Engine.time_scale=2
	Engine.physics_ticks_per_second=120
	level=load("res://scenes/level_three.tscn").instantiate()
	root.add_child(level)
	current_scene=level
	level.save_enabled=false
	level.set_process(false)
	if level.authority():
		level.flags.training=true
		level.flags.battery=true
		level.flags.pump_a=true
		level.robot.teleport(Vector3(38,-2.9,-41))
		level.capture_checkpoint(9)
	physics_frame.connect(tick)
func tick() -> void:
	ticks+=1
	if ticks>20000:
		push_error("Water machinery traversal timed out")
		quit(1)
		return
	if not level.running: return
	if level.authority(): level.broadcast_snapshot()
	if not finished and level.recovery_serial>0 and level.checkpoint_id==13:
		finished=true
		level.set_physics_process(false)
		level.completed=true # Test teardown: preserve the scene as peers exit.
		if level.authority(): level.finish_waterworks.rpc(level.make_snapshot())
	if finished:
		done_ticks+=1
		if done_ticks>(160 if level.authority() else 80):
			if level.flags.pump_b and level.flags.basin and level.cargo and absf(level.water.position.y)<0.01:
				print("NETWORK PASS water lock + raft traversal + immersion recovery role=",level.role)
				quit(0)
			else:
				push_error("Water traversal checkpoint state mismatch")
				quit(1)
		return
	var data := {"drive":Vector2.ZERO,"brace":true,"jump":0,"interact":false,"pressure":0.0,"yaw":0.0,"pitch":0.0,"looked":true}
	var destination: Vector3=level.robot.position
	var desired_yaw := 0.0
	if not level.flags.lock: destination=Vector3(38,-3,-45)
	elif level.lock_time>=8 and not level.flags.pump_b: destination=Vector3(38,0,-54)
	elif level.flags.pump_b and not level.flags.basin:
		if level.authority() and not switched:
			switched=true
			level.capture_checkpoint(12)
			level.robot.teleport(Vector3(6,-5.3,-38),PI/2)
		if level.robot.position.x<20:
			destination=Vector3(0,-5.4,-38)
			desired_yaw=0
	elif level.flags.basin and level.basin_time>=14:
		destination=Vector3(0,0.6,-44)
		if level.authority() and not dipped and level.robot.position.z< -43.7:
			dipped=true
			level.capture_checkpoint(13)
			level.robot.teleport(Vector3(-10,-1.5,-50))
	var diff := Vector2(destination.x-level.robot.position.x,destination.z-level.robot.position.z)
	if diff.length()>0.25:
		data.drive=Driver.command(level.robot.position,level.robot.velocity,level.robot.heading(),destination)
		data.drive.y=clampf(data.drive.y*6/2.5,-0.8,1)
	else:
		data.drive=Vector2(clampf(-wrapf(desired_yaw-level.robot.heading(),-PI,PI)*1.5,-1,1),0)
	if level.engaged!="": data.pressure=clampf((float(level.Layout.STATIONS[level.engaged].target)-level.pressure)*0.5,-1,1)
	else: data.interact=ticks%150<100
	if level.authority():
		level.apply_input(level.role,data)
	else: level.submit_input.rpc_id(1,data)
	level.apply_presentation(1.0/60)
	if ticks%1200==0: print("WATER NAV role=",level.role," pos=",level.robot.position," lock=",level.lock_time," basin=",level.basin_time)
