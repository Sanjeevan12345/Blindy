extends SceneTree
## Three-process integration runner. Pass --host or --join=127.0.0.1, --autostart.
var level
const Driver=preload("res://tests/steering_driver.gd")
var ticks := 0
var jump_id := 0
var fell_before := false
var fell_after := false
var tipped_after := false
var complete_ticks := 0
var route_stage := -1
var waypoint := 0
func _initialize() -> void:
	call_deferred("setup")
func setup() -> void:
	level=load("res://scenes/main.tscn").instantiate()
	root.add_child(level)
	print("NETWORK setup args=%s server=%s roster=%s" % [OS.get_cmdline_user_args(),level.multiplayer.is_server(),level.roles])
	level.set_process(false)
	physics_frame.connect(tick)
func tick() -> void:
	ticks+=1
	if level.completed or ("--boot-only" in OS.get_cmdline_user_args() and level.stage>=1):
		complete_ticks+=1
		if complete_ticks>(180 if level.multiplayer.is_server() else 90):
			print("NETWORK PASS role=%d: synchronized completion with cargo=%s" % [level.role,level.cargo])
			quit(0)
			return
		level.apply_presentation(1.0/60)
		return
	if ticks>18000:
		push_error("NETWORK TIMEOUT stage=%s pos=%s" % [level.stage,level.robot.position])
		quit(1)
		return
	if not level.running:
		if ticks%180==0:
			print("NETWORK waiting: %s" % level.lobby_text.text)
		return
	if "--finish-only" in OS.get_cmdline_user_args() and level.multiplayer.is_server() and level.stage==0:
		level.stage=level.Layout.COMPLETE
		level.cargo=true
		level.robot.finished=true
		level.robot.set_simulation(false)
		level.robot.position=Vector3(3,0.55,-147)
	var data := {"yaw":0.0,"pitch":0.0,"looked":true,"drive":Vector2.ZERO,"brace":false,"interact":true,"jump":jump_id}
	if level.role==1:
		var z: float=level.robot.position.z
		for jump_z in level.Layout.JUMPS:
			var lead: float=2.1 if jump_z == -60.0 else 1.2
			if z < jump_z+lead and z > jump_z+lead-0.7 and ticks%8==0:
				jump_id+=1
		data.jump=jump_id
	if level.role==2 and level.stage<level.Layout.COMPLETE:
		if route_stage != level.stage:
			route_stage=level.stage
			waypoint=0
		var route: Array=level.Layout.ROUTES[level.stage]
		var destination: Vector3=route[waypoint]
		var diff := Vector2(destination.x-level.robot.position.x,destination.z-level.robot.position.z)
		if diff.length()<1.0 and waypoint<route.size()-1:
			waypoint+=1
			destination=route[waypoint]
			diff=Vector2(destination.x-level.robot.position.x,destination.z-level.robot.position.z)
		data.drive=Driver.command(level.robot.position,level.robot.velocity,level.robot.heading(),destination)
	if level.multiplayer.is_server():
		level.apply_input(level.role,data)
		if level.encounter_id()=="shutter" and is_equal_approx(level.checkpoint.z,-61.6) and not fell_before:
			fell_before=true
			level.robot.position.y=-8
			print("NETWORK: testing conveyor fall recovery")
		if level.encounter_id()=="power" and not fell_after:
			fell_after=true
			level.robot.position.y=-8
			print("NETWORK: testing cargo fall recovery")
		if level.encounter_id()=="departure" and not tipped_after:
			tipped_after=true
			level.robot.quaternion=Quaternion.from_euler(Vector3(0,level.robot.heading(),deg_to_rad(80)))
			print("NETWORK: testing tipped chassis recovery with cargo")
		level.broadcast_snapshot()
	else:
		level.submit_input.rpc_id(1,data)
	level.apply_presentation(1.0/60)
	if ticks%180==0:
		print("NETWORK role=%d stage=%d pos=%s cargo=%s yaw=%.2f v=%s steer=%s waypoint=%d" % [level.role,level.stage,level.robot.position,level.cargo,level.robot.heading(),level.robot.velocity,level.robot.drive_input,waypoint])
