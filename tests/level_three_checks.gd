extends SceneTree
var level
var failures := 0
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second=int(arg.get_slice("=",1))
	call_deferred("run")
func check(value: bool,label: String) -> void:
	print(("PASS: " if value else "FAIL: ")+label)
	if not value: failures+=1
func frames(n: int) -> void:
	for i in range(n): await physics_frame
func dock(id: String) -> void:
	level.robot.reset_robot()
	level.robot.teleport(level.station_at(id)+Vector3(0,0.08,0),level.Layout.STATIONS[id].yaw)
	await frames(65)
	level.active_station=id
	if not level.station_valid(id): print("DOCK DEBUG ",id," robot=",level.robot.position," station=",level.station_at(id)," ground=",level.robot.grounded," speed=",level.robot.velocity," yaw=",level.robot.heading()," recovering=",level.robot.recovering)
func calibrate(id: String) -> void:
	await dock(id)
	level.release_required=false
	level.interact_held=true
	for i in range(50): level.update_level(0.02)
	check(level.engaged==id,"Hold E engages "+id)
	level.interact_held=false
	level.update_level(0.02)
	level.pressure_input=1
	var target: float=level.Layout.STATIONS[id].target
	for i in range(roundi(target/0.4)): level.update_level(0.02)
	level.pressure_input=0
	for i in range(155): level.update_level(0.02)
	check(level.flags[id],"Pressure target completes "+id)
func run() -> void:
	level=load("res://scenes/level_three.tscn").instantiate()
	root.add_child(level)
	level.save_enabled=false
	level.start_solo()
	level.set_process(false)
	level.set_physics_process(false)
	await frames(80)
	check(level.robot.grounded and level.cargo and level.robot.auto_stabilize,"Arrival grounded with repaired stabilizer and sapling")
	var length: float=level.Layout.route_length()
	print("WATERWORKS measured centreline: %.2f m" % length)
	check(length>=504 and length<=616,"Both pump orders share a route within 560 m ±10%")
	check(level.Layout.CHECKPOINTS.size()==14,"Exactly fourteen checkpoint locations")
	check(level.bridges.size()==2 and level.bridges[0].width==2.2 and level.bridges[0].sway_amplitude==1.2,"Narrow guarded bridges have specified width and sway")
	check(is_equal_approx(level.bridges[0].span,14) and is_equal_approx(level.bridges[1].span,10),"Bridge spans are 14 m and 10 m")
	check(not level.available("basin") and not level.available("exit"),"Finale unavailable before both pumps")
	await calibrate("training")
	check(level.available("lock") and not level.available("pump_a"),"Either wing opens; filtration requires its battery")
	level.apply_input(2,{"pressure":1,"drive":Vector2.ZERO})
	check(level.pressure_input==0,"Wheel cannot adjust pressure")
	level.apply_input(1,{"pressure":-1})
	check(level.pressure_input== -1,"Hands can adjust pressure")
	await dock("lock")
	level.robot.angular_velocity=Vector3(0,0.4,0)
	check(not level.station_valid("lock"),"Pivoting blocks valve engagement")
	level.robot.angular_velocity=Vector3.ZERO
	level.robot.teleport(level.station_at("lock")+Vector3(0,0.08,0),PI/2)
	await frames(50)
	check(not level.station_valid("lock"),"Incorrect heading blocks valve engagement")
	await dock("lock")
	level.engaged="lock"
	level.pressure=50
	level.pressure_hold=2
	level.pressure_input=1
	level.update_level(1)
	check(level.pressure_hold==0 and not level.flags.lock,"Overshoot resets continuous target hold")
	level.engaged=""
	level.pressure_input=0
	await calibrate("lock")
	for i in range(500): level.update_level(0.02)
	check(level.lock_time==8 and level.flags.lock,"Water lock completes its timed rise")
	await frames(5)
	check(absf(level.lock_platform.position.y)<0.05,"Lock platform actually reaches upper elevation")
	await calibrate("pump_b")
	check(level.flags.pump_b and not level.flags.pump_a,"Pressure wing can be completed first")
	check(not level.available("basin"),"One pump cannot unlock the basin")
	level.robot.teleport(Vector3(-16,0.1,0))
	await frames(60)
	level.set_coupled(true)
	check(level.coupled and level.robot.forward_limit==2 and is_instance_valid(level.hitch),"Physical trolley hitch enforces coupled speed")
	level.apply_input(1,{"jump":2})
	check(not level.robot.jump_requested,"Coupled trolley prevents jump input")
	level.set_coupled(false)
	check(level.trolley.freeze and level.robot.forward_limit==6,"Detached trolley parks and restores speed")
	level.flags.battery=true
	level.reset_trolley()
	await calibrate("pump_a")
	check(level.available("basin"),"Both pumps unlock basin in B-then-A order")
	level.capture_checkpoint(12)
	level.flags.basin=true
	level.basin_time=5
	level.restore_checkpoint()
	check(level.flags.pump_a and level.flags.pump_b and not level.flags.basin and level.basin_time==0,"Mid-fill recovery keeps pumps and resets low raft")
	level.flags.lock=true
	level.lock_time=8
	await calibrate("basin")
	for i in range(750): level.update_level(0.02)
	await frames(5)
	check(level.basin_time==14 and absf(level.raft.position.y-0.6)<0.05,"Basin raft reaches its upper landing")
	check(level.available("exit"),"Upper exit unlocks after basin completes")
	level.clock=0
	check(level.jet_phase()<3 and level.shuttle_x()==32,"Jets and shuttle reset to safe initial phase")
	level.clock=5.5
	check(level.jet_phase()>=5 and is_equal_approx(level.shuttle_x(),34.5),"Hazard and shuttle phase follow deterministic timing")
	level.flags.light_1=true
	level.update_machinery()
	check(level.gallery_lights[0].light_energy>0 and level.gallery_lights[1].light_energy==0,"Inspection panels illuminate sections independently")
	var path := "user://waterworks-check-test.json"
	for id in range(1,15):
		for key in level.flags: level.flags[key]=true
		level.flags.basin=id>=13
		level.flags.exit=false
		level.lock_time=8
		level.basin_time=14 if id>=13 else 0
		level.capture_checkpoint(id)
		var data: Dictionary=level.save_data()
		check(level.Save.write_slot(data,path)==OK,"Atomic disk checkpoint %d" % id)
		level.load_checkpoint(level.Save.read_slot(path))
		check(level.checkpoint_id==id and level.cargo and level.robot.auto_stabilize,"Reload checkpoint %d safely" % id)
		var before: Dictionary=level.flags.duplicate()
		level.apply_flags_mask(level.flags_mask())
		check(before==level.flags,"Stable flag wire order after disk reload %d" % id)
	var damaged := FileAccess.open(path,FileAccess.WRITE)
	damaged.store_string("broken")
	damaged.close()
	check(not level.Save.read_slot(path).is_empty(),"Corrupt primary recovers previous valid backup")
	check(not level.Save.valid({"version":99}),"Unsupported save versions rejected")
	# Exercise the real recovery loop, rather than calling restore directly.
	level.flags.basin=true
	level.basin_time=14
	level.flags.exit=false
	level.capture_checkpoint(14)
	level.set_physics_process(true)
	level.robot.teleport(Vector3(-10,-1.5,-50))
	var serial: int=level.recovery_serial
	await frames(Engine.physics_ticks_per_second*2)
	check(level.recovery_serial>serial and level.robot.position.distance_to(level.checkpoint)<1,"Deep water triggers timed checkpoint recovery through physics")
	level.set_physics_process(false)
	check(level.cargo and level.flags.pump_a and level.flags.pump_b and level.flags.basin,"Immersion recovery preserves cargo and checkpoint machinery")
	level.flags.basin=true
	level.basin_time=14
	await dock("exit")
	level.complete_station("exit")
	check(level.completed and level.flags.exit and level.cargo,"Parked elevator completes with cargo")
	print("Waterworks checks: %d failures" % failures)
	quit(1 if failures else 0)
