extends SceneTree
const Driver=preload("res://tests/steering_driver.gd")
var level
var ticks := 0
var waypoint := 0
var route_stage := -1
var complete_ticks := 0
var recovery_seen := false
var falling_tested := false
var use_service := false
var last_position := Vector3.ZERO
func _initialize() -> void:
	call_deferred("setup")
func setup() -> void:
	use_service="--route=service" in OS.get_cmdline_user_args()
	level=load("res://scenes/level_two.tscn").instantiate()
	root.add_child(level)
	level.set_process(false)
	if "--from-ramp" in OS.get_cmdline_user_args():
		level.stage=4
		level.balance_practiced=true
		level.looked=true
		level.drove=true
		level.robot.teleport(Vector3(20,-5.9,-40))
		level.save_checkpoint(Vector3(20,-5.9,-40),4,true)
	last_position=level.robot.position
	physics_frame.connect(tick)
func route() -> Array:
	match level.stage:
		0: return [level.DOCKS[0]]
		1: return level.Layout.SERVICE_ROUTE if use_service else level.Layout.SHORT_ROUTE
		2: return [level.DOCKS[2]]
		3: return level.Layout.LOWER_ROUTE
		4: return level.Layout.RAMP_ROUTE
		5: return level.Layout.FINAL_ROUTE
	return []
func tick() -> void:
	ticks+=1
	if ticks>27000:
		push_error("NETWORK TIMEOUT Level 2 stage=%d pos=%s" % [level.stage,level.robot.position])
		quit(1)
		return
	if not level.running:
		return
	if level.completed:
		complete_ticks+=1
		level.apply_presentation(1.0/60)
		if complete_ticks>(180 if level.multiplayer.is_server() else 90):
			print("NETWORK PASS role=%d Level 2 complete route=%s cargo=%s" % [level.role,level.route_taken,level.cargo])
			quit(0)
		return
	var data := {"yaw":0.0,"pitch":0.0,"looked":true,"drive":Vector2.ZERO,"brace":true,"interact":true,"jump":0,"balance":0.0}
	if level.role==1 or level.solo:
		data.balance=0.3 if not level.balance_practiced else clampf(-level.robot.cargo_tilt*2,-1,1)
	if (level.role==2 or level.solo) and not level.turning and not level.riding:
		if level.robot.position.distance_to(last_position)>4 or (recovery_seen and not level.robot.recovering):
			route_stage= -1
		recovery_seen=level.robot.recovering
		last_position=level.robot.position
		if route_stage!=level.stage:
			route_stage=level.stage
			waypoint=0
		var points := route()
		var destination: Vector3=points[waypoint]
		var diff := Vector2(destination.x-level.robot.position.x,destination.z-level.robot.position.z)
		if diff.length()<0.7 and waypoint<points.size()-1:
			waypoint+=1
			destination=points[waypoint]
		data.drive=Driver.command(level.robot.position,level.robot.velocity,level.robot.heading(),destination)
		# Bracing changes the motor's maximum; compensate the test's analog input.
		data.drive.y=clampf(data.drive.y*6/2.5,-1,1)
		if level.stage in [1,5]:
			data.drive.y=maxf(data.drive.y,-0.72)
	if level.multiplayer.is_server():
		if level.solo:
			for r in [0,1,2]: level.apply_input(r,data)
		else:
			level.apply_input(level.role,data)
		if level.stage==4 and not falling_tested:
			falling_tested=true
			level.robot.teleport(Vector3(20,-25,-40))
			print("NETWORK: Level 2 lower-deck fall recovery")
		level.broadcast_snapshot()
	else:
		level.submit_input.rpc_id(1,data)
	level.apply_presentation(1.0/60)
	if ticks%300==0:
		print("NETWORK role=%d stage=%d pos=%s water=%.0f tilt=%.2f route=%s waypoint=%d" % [level.role,level.stage,level.robot.position,level.robot.water,level.robot.cargo_tilt,level.route_taken,waypoint])
