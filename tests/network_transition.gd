extends SceneTree
var ticks := 0
var transitioned_ticks := 0
var requested := false
var from_level := 1
var to_level := 2
func _initialize() -> void:
	call_deferred("setup")
func setup() -> void:
	if "--transition-three" in OS.get_cmdline_user_args():
		from_level=2
		to_level=3
	var level=load("res://scenes/level_two.tscn" if from_level==2 else "res://scenes/main.tscn").instantiate()
	root.add_child(level)
	current_scene=level
	level.set_process(false)
	physics_frame.connect(tick)
func tick() -> void:
	ticks+=1
	if ticks>1800:
		push_error("Campaign transition timed out")
		quit(1)
		return
	var scene=current_scene
	if scene==null:
		return
	if scene.level_number==from_level and scene.running and scene.authority() and not requested:
		requested=true
		print("NETWORK: switching persistent session %d → %d" % [from_level,to_level])
		scene.enter_level.rpc(to_level)
	if scene.level_number==to_level and (scene.running or transitioned_ticks>0):
		transitioned_ticks+=1
		if transitioned_ticks>(180 if scene.authority() else 90):
			if scene.cargo and (scene.robot.auto_stabilize if to_level==3 else not scene.robot.auto_stabilize) and scene.roles.size()>=1:
				print("NETWORK PASS campaign handoff role=%d cargo=true" % scene.role)
				quit(0)
			else:
				push_error("Incorrect Level 2 campaign state")
				quit(1)
