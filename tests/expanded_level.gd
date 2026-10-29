extends SceneTree
var failures := 0
var level
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, description: String) -> void:
	print(("PASS: " if value else "FAIL: ")+description)
	if not value:
		failures+=1
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
func dock() -> void:
	level.robot.teleport(level.DOCKS[level.stage]+Vector3(0,0.03,0))
	await frames(45)
func run() -> void:
	level=load("res://scenes/main.tscn").instantiate()
	root.add_child(level)
	level.start_solo()
	level.set_process(false)
	level.set_physics_process(false)
	await frames(70)
	check(level.running and level.robot.is_on_floor(),"Solo starts grounded")
	var length: float=level.Layout.route_length()
	check(length>=150 and length<=170,"Required route is %.1f metres" % length)
	check(level.Layout.ENCOUNTERS.size()==8,"Eight named teamwork encounters")
	level.advance_objective()
	check(level.stage==0,"Cannot interact from across room")
	await dock()
	level.advance_objective()
	check(level.stage==0,"Head look and wheel input required")
	level.apply_input(0,{"looked":true})
	level.apply_input(2,{"drive":Vector2(0,-1)})
	level.robot.drive_input=Vector2.ZERO
	level.robot.velocity=Vector3(1,0,0)
	level.advance_objective()
	check(level.stage==0,"Moving robot cannot interact")
	level.robot.velocity=Vector3.ZERO
	await frames(5)
	level.robot.angular_velocity=Vector3(0,0.8,0)
	check(not level.can_interact(),"Pivoting robot cannot interact")
	level.robot.angular_velocity=Vector3.ZERO
	for id in ["release","sorting","bridge","shutter","seal","pickup","power","departure"]:
		check(level.encounter_id()==id,"Ordered encounter: "+id)
		await dock()
		if id=="seal":
			level.interact_held=true
			level.update_level(0.7)
			check(level.encounter_id()==id,"Seal requires sustained hold")
			level.interact_held=false
			level.update_level(0.1)
			check(level.hold_progress==0,"Releasing E cancels interaction")
		if id=="departure":
			level.cargo=false
			level.advance_objective()
			check(level.encounter_id()==id,"Departure requires cargo")
			level.cargo=true
		level.advance_objective()
		level.apply_presentation(0)
		check(level.encounter_id()!=id,"Interaction advances: "+id)
		if id=="release":
			check(level.checkpoint_stage==level.stage,"Boot checkpoint saved")
			check(not level.gates[0].visible and level.gates[1].visible,"Future gate stays closed")
		if id=="bridge":
			check(level.gates[2].visible,"Bridge gate stays shut during extension")
			level.interact_held=false
			level.update_level(2.1)
			level.apply_presentation(0)
			check(not level.gates[2].visible and level.bridge.position.y> -0.41,"Bridge extends before opening gate")
		if id in ["bridge","shutter"]:
			var z: float=-61.6 if id=="bridge" else -82.6
			level.robot.position=Vector3(0,0.1,-63 if id=="bridge" else -84)
			level.update_level(0)
			level.restore_checkpoint()
			check(is_equal_approx(level.robot.position.z,z) and not level.cargo,"Gap checkpoint recovery: "+str(z))
		if id=="pickup":
			check(level.cargo and level.checkpoint_cargo,"Pickup saves cargo checkpoint")
			level.restore_checkpoint()
			check(level.cargo and level.encounter_id()=="power","Cargo survives fall recovery")
			level.advance_objective()
			check(level.encounter_id()=="power","Repeated pickup cannot skip power console")
		if id=="power":
			check(level.checkpoint_stage==level.stage and level.checkpoint_cargo,"Power console saves final checkpoint")
	level.update_level(7)
	check(level.completed and level.lift.position.y>7,"Lift ascends and completes level")
	level.restore_checkpoint()
	check(level.robot.simulation_enabled and not level.robot.freeze and level.encounter_id()=="departure" and is_equal_approx(level.lift.position.y,0.4),"Restart after ending restores an operable lift checkpoint")
	check(level.robot.water==100 and level.robot.spills==0,"No cargo damage in Level 1")
	level.interact_held=false
	level.apply_input(2,{"interact":true,"jump":900,"drive":Vector2.ZERO})
	check(not level.interact_held,"Wheel cannot operate hands interactions")
	level.robot.drive_input=Vector2.ZERO
	level.apply_input(1,{"drive":Vector2.ONE,"jump":0})
	check(level.robot.drive_input==Vector2.ZERO,"Hands cannot drive")
	for r in [1,2,0]:
		level.role=r
		level.begin_session()
		check((level.camera.cull_mask==0)==(r!=0),"View isolation for role "+str(r))
	level.factory.set_quality(false)
	check(not level.factory.environment.volumetric_fog_enabled,"Reduced effects preset")
	level.factory.set_quality(true)
	check(level.factory.environment.volumetric_fog_enabled,"High quality preset")
	level.yaw=0.3
	level.robot.quaternion=Quaternion.from_euler(Vector3(0.1,0.8,0.1))
	level.apply_presentation(0)
	check(absf(wrapf(level.camera.rotation.y-level.robot.heading()-level.yaw,-PI,PI))<0.01 and absf(level.camera.rotation.z)<0.01,"Camera follows chassis plus head look with a level horizon")
	var snapshot: Dictionary=level.make_snapshot()
	check(snapshot.has("orientation") and snapshot.has("angular_velocity") and snapshot.has("recovering") and snapshot.has("checkpoint_heading"),"Network snapshot includes physical orientation and recovery state")
	print("Expanded Level 1 checks: %d failures" % failures)
	quit(1 if failures else 0)
