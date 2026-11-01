extends SceneTree
var level
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool,text: String) -> void:
	print(("PASS: " if value else "FAIL: ")+text)
	if not value: failures+=1
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func dock() -> void:
	level.robot.teleport(level.DOCKS[level.stage]+Vector3(0,0.06,0))
	await frames(45)
func run() -> void:
	level=load("res://scenes/level_two.tscn").instantiate()
	root.add_child(level)
	level.start_solo()
	level.set_process(false)
	level.set_physics_process(false)
	await frames(70)
	check(level.robot.grounded and level.cargo,"Arrival starts grounded with sapling")
	check(not level.robot.auto_stabilize and level.robot.kill_height< -6,"Manual balance and lower deck recovery depth")
	check(level.bridges.size()==2 and is_equal_approx(level.bridges[0].width,2.4),"Two narrow continuous-deck suspension bridges")
	check(level.bridges[0].initial_transform.origin.distance_to(Vector3(-10.5,-0.14,-13))<0.01,"Shortcut bridge connects its actual endpoint platforms")
	check(level.bridges[1].initial_transform.origin.distance_to(Vector3(11.5,-0.14,-78))<0.01,"Final bridge connects landing and repair island")
	check(level.Layout.SHORT_ROUTE[-1]==level.Layout.SERVICE_ROUTE[-1],"Both branches rejoin the machinery island")
	await dock()
	level.looked=true
	level.drove=true
	level.advance_objective()
	check(level.stage==0,"Balance practice required before route choice")
	level.apply_input(2,{"drive":Vector2.ZERO,"balance":1})
	check(not level.balance_practiced,"Wheel cannot operate cargo balance")
	level.apply_input(1,{"balance":1})
	check(level.balance_practiced and level.robot.balance_input==1,"Hands controls cargo balance")
	level.robot.balance_input=0
	for id in ["stabilize","turntable","freight","refill","bridge","repair"]:
		check(level.encounter_id()==id,"Ordered encounter: "+id)
		await dock()
		if id=="turntable":
			level.robot.position.y= -6
			check(not level.can_interact(),"Cannot activate an upper console from the lower deck")
			await dock()
		level.advance_objective()
		check(level.encounter_id()!=id,"Interaction advances: "+id)
		if id=="turntable":
			check(level.turning and level.robot.freeze,"Turntable safely holds robot while aligning")
			level.update_level(3.1)
			check(not level.turning and not level.robot.freeze,"Turntable releases aligned chassis")
		if id=="freight":
			check(level.riding and level.robot.freeze,"Freight lift safely carries robot")
			level.update_level(4.1)
			level.apply_presentation(0)
			check(not level.riding and is_equal_approx(level.lift.position.y,-6.15),"Freight reaches lower deck")
			level.restore_checkpoint()
			check(level.stage==3 and level.cargo and level.robot.position.y< -5,"Lower deck checkpoint restores cargo and elevation")
		if id=="refill":
			check(level.robot.water==100 and level.checkpoint_water==100,"Refill station replenishes and checkpoints water")
			level.apply_presentation(0)
			check(not level.lower_gate.visible,"Lower gate opens after refill")
		if id=="bridge":
			level.apply_presentation(0)
			check(not level.final_gate.visible,"Final bridge gate opens after ascent")
	check(level.completed and level.robot.auto_stabilize and level.robot.water==100,"Repair completes level and restores stabilizer")
	var state: Dictionary=level.make_snapshot()
	check(state.has("wave") and state.has("cargo_tilt") and state.has("freight_time") and state.has("checkpoint_water"),"Network state includes bridges, freight and cargo")
	level.restore_checkpoint()
	level.robot.water=0
	level.update_level(0)
	check(level.robot.water>0 and level.cargo,"Water depletion is recoverable without losing sapling")
	level.bridges[0].set_wave(1.0)
	var first: Transform3D=level.bridges[0].transform
	level.bridges[0].set_wave(1.0)
	check(level.bridges[0].transform.is_equal_approx(first),"Bridge sway is deterministic from synchronized clock")
	print("Level 2 checks: %d failures" % failures)
	quit(1 if failures else 0)
