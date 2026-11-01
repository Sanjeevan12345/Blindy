extends SceneTree
var level
var ticks := 0
var ready_ticks := 0
var saved_complete := false
func _initialize() -> void: call_deferred("setup")
func setup() -> void:
	saved_complete="--saved-complete" in OS.get_cmdline_user_args()
	level=load("res://scenes/level_three.tscn").instantiate()
	root.add_child(level)
	current_scene=level
	level.save_enabled=false
	level.slot_path="user://waterworks-network-resume-%d.json" % level.server_port
	if level.multiplayer.is_server():
		var data := {"version":1,"level":3,"checkpoint":14 if saved_complete else 10,"flags":{"training":true,"battery":saved_complete,"pump_a":saved_complete,"lock":true,"pump_b":true,"light_1":saved_complete,"light_2":saved_complete,"basin":saved_complete,"exit":saved_complete},"complete":saved_complete,"heading":0,"cargo":true}
		if level.Save.write_slot(data,level.slot_path)!=OK:
			push_error("Cannot prepare isolated resume fixture")
			quit(1)
		root.get_node("Campaign").resume_three=true
	physics_frame.connect(tick)
func tick() -> void:
	ticks+=1
	if ticks>1800:
		push_error("Multiplayer saved-session resume timed out")
		quit(1)
	if not level.running: return
	ready_ticks+=1
	if ready_ticks>(360 if level.authority() else 90):
		var expected := 14 if saved_complete else 10
		if level.checkpoint_id==expected and level.flags.pump_b and level.flags.pump_a==saved_complete and level.completed==saved_complete and level.cargo and level.robot.auto_stabilize:
			print("NETWORK PASS new player role=%d restored checkpoint=%d complete=%s" % [level.role,level.checkpoint_id,level.completed])
			quit(0)
		else:
			push_error("Saved-session state did not synchronize")
			quit(1)
