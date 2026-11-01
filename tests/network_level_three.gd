extends SceneTree
const Driver=preload("res://tests/steering_driver.gd")
var level
var tasks: Array = []
var task_index := 0
var waypoint := 0
var ticks := 0
var complete_ticks := 0
var task_ticks := 0
var b_first := false
var jumped := false
var counter := 0
var recovery_tested := false
var last_recovery := 0
var coordinator
func _initialize() -> void: call_deferred("setup")
func drive(points: Array) -> void: tasks.append({"kind":"drive","points":points})
func valve(id: String) -> void: tasks.append({"kind":"valve","id":id})
func setup() -> void:
	print("NETWORK SETUP ",OS.get_cmdline_user_args())
	b_first="--order=ba" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--speed="):
			Engine.time_scale=float(arg.get_slice("=",1))
			Engine.physics_ticks_per_second=roundi(60*Engine.time_scale)
	level=load("res://scenes/level_three.tscn").instantiate()
	root.add_child(level)
	current_scene=level
	level.save_enabled=false
	level.set_process(false)
	if "--solo" not in OS.get_cmdline_user_args() and "--host" not in OS.get_cmdline_user_args() and not "--join=127.0.0.1" in OS.get_cmdline_user_args(): level.start_solo()
	drive([Vector3(0,0,20),Vector3.ZERO])
	valve("training")
	if b_first:
		wing_b()
		wing_a()
	else:
		wing_a()
		wing_b()
	drive([Vector3(6,0,-8),Vector3(6,-5.4,-38),Vector3(0,-5.4,-38)])
	valve("basin")
	tasks.append({"kind":"wait","id":"basin"})
	drive([Vector3(0,0.6,-44),Vector3(0,0.6,-59),Vector3(0,0.6,-71),Vector3(0,0.6,-84),Vector3(16,0.6,-84),Vector3(16,3.6,-104),level.Layout.LIFT])
	valve("exit")
	if "--from-shuttle" in OS.get_cmdline_user_args():
		level.flags.training=true
		level.flags.pump_a=true
		level.robot.teleport(Vector3(28,0.1,-22))
		while tasks[task_index].kind!="shuttle": task_index+=1
	if "--from-lock" in OS.get_cmdline_user_args():
		level.flags.training=true
		level.robot.teleport(Vector3(38,-2.9,-41))
		while tasks[task_index].get("id","")!="lock": task_index+=1
	if "--from-basin" in OS.get_cmdline_user_args():
		level.flags.training=true
		level.flags.pump_a=true
		level.flags.pump_b=true
		level.flags.battery=true
		level.flags.lock=true
		level.lock_time=8
		level.robot.teleport(Vector3(6,-5.3,-38))
		while tasks[task_index].get("id","")!="basin": task_index+=1
		tasks[task_index-1].points=[Vector3(0,-5.4,-38)]
		task_index-=1
	coordinator=load("res://tests/three_navigation_sync.gd").new()
	coordinator.name="NavigationSync"
	coordinator.harness=self
	coordinator.level=level
	root.add_child(coordinator)
	print("NETWORK READY running=",level.running," role=",level.role," lobby=",level.lobby_text.text)
	physics_frame.connect(tick)
func wing_a() -> void:
	drive([Vector3(-16,0,0)])
	tasks.append({"kind":"couple"})
	drive([Vector3(-32,0,0),Vector3(-32,0,-18),Vector3(-48,0,-18)])
	valve("battery")
	drive([Vector3(-48,0,-32),Vector3(-49,0,-44)])
	tasks.append({"kind":"jump"})
	drive([Vector3(-32,0,-44)])
	valve("pump_a")
	drive(level.Layout.A_RETURN.slice(1))
func wing_b() -> void:
	drive([Vector3(16,0,0),Vector3(16,0,-6)])
	tasks.append({"kind":"jets"})
	drive([Vector3(16,0,-22),Vector3(28,0,-22)])
	tasks.append({"kind":"shuttle"})
	drive([Vector3(38,0,-24),Vector3(38,-3,-40),Vector3(38,-3,-45)])
	valve("lock")
	tasks.append({"kind":"wait","id":"lock"})
	drive([Vector3(38,0,-54)])
	valve("pump_b")
	drive([Vector3(58,0,-54),Vector3(58,0,-26),Vector3(50,0,-26),Vector3(50,0,-21)])
	valve("light_1")
	drive([Vector3(50,0,-10),Vector3(32,0,-10)])
	valve("light_2")
	drive([Vector3(26,0,-10),Vector3(26,0,0),Vector3.ZERO])
func recover_navigation() -> void:
	if not level.solo and level.role!=2: return
	var cp: int=level.checkpoint_id
	for i in range(tasks.size()):
		var task: Dictionary=tasks[i]
		if task.kind!="drive": continue
		var first: Vector3=task.points[0]
		var selected := false
		if cp==4 and first==Vector3(-48,0,-32):
			selected=true
			jumped=false
		if cp==5 and first==Vector3(-8,0,-20): selected=true
		if cp==10 and first==Vector3(58,0,-54): selected=true
		if cp==12 and first==Vector3(6,0,-8):
			selected=true
			task.points=[Vector3(0,-5.4,-38)]
		if cp in [13,14] and first==Vector3(0,0.6,-44):
			selected=true
			task.points=task.points.slice(1 if cp==13 else 3)
		if selected:
			task_index=i
			waypoint=0
			task_ticks=0
			if not level.solo: coordinator.publish(task_index)
			print("NETWORK navigator restored checkpoint ",cp)
			return

func next_task() -> void:
	if not level.solo and level.role!=2: return
	print("TRAVERSED task=%d %s pos=%s cp=%d" % [task_index,str(tasks[task_index]),level.robot.position,level.checkpoint_id])
	task_index+=1
	waypoint=0
	task_ticks=0
	if not level.solo: coordinator.publish(task_index)
func steer(target: Vector3,limit: float=2.4) -> Vector2:
	var data: Vector2=Driver.command(level.robot.position,level.robot.velocity,level.robot.heading(),target)
	var maximum: float=minf(2.5,level.robot.forward_limit)
	data.y=clampf(data.y*6/maximum,-limit/maximum,1)
	return data
func align(yaw: float) -> Vector2:
	return Vector2(clampf(-wrapf(yaw-level.robot.heading(),-PI,PI)*2.4/deg_to_rad(100),-1,1),0)
func tick() -> void:
	ticks+=1
	if ticks>80000:
		push_error("NETWORK TIMEOUT Waterworks task=%d pos=%s" % [task_index,level.robot.position])
		quit(1)
		return
	if not level.running:
		if ticks%1800==0: print("WAITING ",level.lobby_text.text," roster=",level.roles)
		return
	if level.completed:
		complete_ticks+=1
		if complete_ticks>(180 if level.authority() else 90):
			print("NETWORK PASS role=%d Waterworks order=%s cargo=%s checkpoint=%d" % [level.role,"BA" if b_first else "AB",level.cargo,level.checkpoint_id])
			quit(0)
		return
	if task_index>=tasks.size(): return
	if level.authority() and level.flags.pump_a and not recovery_tested:
		recovery_tested=true
		level.robot.teleport(level.robot.position+Vector3(0,-22,0))
		print("NETWORK deliberate fall after pump A")
		return
	if level.robot.recovering: return
	if level.recovery_serial!=last_recovery:
		last_recovery=level.recovery_serial
		recover_navigation()
	task_ticks+=1
	var task: Dictionary=tasks[task_index]
	var data := {"yaw":0.0,"pitch":0.0,"looked":true,"drive":Vector2.ZERO,"brace":true,"interact":false,"jump":counter,"pressure":0.0}
	var p: Vector3=level.robot.position
	match task.kind:
		"drive":
			var target: Vector3=task.points[waypoint]
			data.drive=steer(target,1.8 if absf(p.x+48)<3 or (absf(p.x)<3 and p.z< -55) else 2.4)
			if Vector2(p.x-target.x,p.z-target.z).length()<0.45 and absf(p.y-target.y)<0.5:
				if waypoint<task.points.size()-1: waypoint+=1
				elif level.robot.velocity.length()<0.25: next_task()
		"valve":
			if level.flags[task.id]: next_task()
			else:
				data.drive=align(level.Layout.STATIONS[task.id].yaw)
				if level.engaged==task.id:
					data.pressure=clampf((float(level.Layout.STATIONS[task.id].target)-level.pressure)*0.5,-1,1)
				else: data.interact=task_ticks%150<110
		"couple":
			data.drive=align(0)
			data.interact=task_ticks%150<110
			if level.coupled: next_task()
		"jump":
			data.drive=steer(Vector3(-38.5,0,-44),2.5)
			if p.x> -43.8 and not jumped:
				counter+=1
				data.jump=counter
				jumped=true
			if p.x> -40 and (level.robot.grounded if level.authority() else level.remote_grounded): next_task()
		"jets":
			var z := -12.5 if waypoint==0 else -22.0
			if task_ticks%600<10 and ticks%600==0: print("JET PHASE ",level.jet_phase())
			if waypoint==0 or p.z< -14 or level.jet_phase()<1.5:
				data.drive=steer(Vector3(16,0,z),2.4)
			if p.z<z+0.4:
				if waypoint==0: waypoint=1
				else: next_task()
		"shuttle":
			if waypoint==0:
				data.drive=align(-PI/2)
				if level.shuttle_x()<32.3 and level.clock>0: waypoint=1
			elif waypoint==1:
				data.drive=steer(Vector3(level.shuttle_x(),0,-22),2)
				if absf(p.x-level.shuttle_x())<0.6: waypoint=2
			elif waypoint==2:
				if level.shuttle_x()>37.7: waypoint=3
			else:
				data.drive=steer(Vector3(39.5,0,-22),2)
				if p.x>39: next_task()
		"wait":
			if (task.id=="lock" and level.lock_time>=8) or (task.id=="basin" and level.basin_time>=14): next_task()
	if level.authority():
		if level.solo:
			for r in [0,1,2]: level.apply_input(r,data)
		else: level.apply_input(level.role,data)
		level.broadcast_snapshot()
	else: level.submit_input.rpc_id(1,data)
	level.apply_presentation(1.0/60)
	if ticks%1200==0: print("NAV task=%d waypoint=%d pos=%s engaged=%s pressure=%.0f flags=%s" % [task_index,waypoint,p,level.engaged,level.pressure,str(level.flags)])
