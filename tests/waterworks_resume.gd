extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var level=load("res://scenes/level_three.tscn").instantiate()
	root.add_child(level)
	current_scene=level
	level.slot_path="user://waterworks-process-resume-test.json"
	level.save_enabled=true
	if "--read" in OS.get_cmdline_user_args(): root.get_node("Campaign").resume_three=true
	level.start_solo()
	if "--read" in OS.get_cmdline_user_args():
		if level.checkpoint_id==10 and level.flags.pump_b and not level.flags.pump_a and level.flags.lock and level.cargo and level.robot.auto_stabilize:
			print("PASS: Fresh process resumes pump-B-first checkpoint, cargo and lock")
			quit(0)
		else:
			push_error("Fresh process save resume mismatch")
			quit(1)
	else:
		level.flags.training=true
		level.flags.lock=true
		level.flags.pump_b=true
		level.lock_time=8
		level.capture_checkpoint(10)
		print("PASS: Producer wrote checkpoint for independent-process resume")
		quit(0)
