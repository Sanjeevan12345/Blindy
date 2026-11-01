extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in range(n): await process_frame
func check(ok: bool,label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures+=1
func press_f3() -> void:
	for held in [true,false]:
		var event := InputEventKey.new()
		event.keycode=KEY_F3
		event.physical_keycode=KEY_F3
		event.pressed=held
		Input.parse_input_event(event)
		Input.flush_buffered_events()
func run() -> void:
	var level=load("res://scenes/level_three.tscn").instantiate()
	root.add_child(level)
	level.save_enabled=false
	level.start_solo()
	level.set_process(false)
	level.set_physics_process(false)
	await frames(5)
	var before: Dictionary=level.make_snapshot()
	check(level.factory.quality_high and level.water_fx.maximum,"Maximum water quality is default")
	check(level.water_fx.probes.size()==2,"Two local static reflection probes")
	check(level.water.layers & level.water_fx.STATIC_REFLECTION_LAYER==0,"Water is excluded from reflection capture")
	check(level.raft.get_child(0).get_child(0).layers & level.water_fx.STATIC_REFLECTION_LAYER==0,"Moving platform is excluded from static reflection capture")
	level.basin_time=7
	level.lock_time=4
	level.clock=12
	level.update_machinery()
	level.water_fx.refresh()
	check(is_equal_approx(level.water.position.y,-3),"Visual effects retain authoritative basin height")
	check(is_equal_approx(level.lock_water.position.y,-2.1),"Visual effects retain authoritative lock height")
	check(level.water.material_override.get_shader_parameter("water_time")==12.0,"Water uses replicated level clock")
	check(level.water_fx.spray[0].emitting and level.water_fx.spray[1].emitting,"Filling emits localized spray in Maximum")
	press_f3()
	check(not level.factory.quality_high,"Physical F3 switches to Reduced")
	level.water_fx.refresh()
	check(not level.water.material_override.get_shader_parameter("maximum_quality") and not level.water_fx.spray[0].emitting,"Reduced disables tracing, displacement and particles")
	check(level.water_fx.probes[0].visible,"Reduced retains reflection fallback")
	press_f3()
	check(level.factory.quality_high,"Physical F3 restores Maximum")
	level.solo=false
	for role in [1,2]:
		level.role=role
		level.water_fx.refresh()
		check(not level.water.visible and not level.water_fx.probes[0].visible and not level.water_fx.spray[0].visible,"Private role %d cannot render water or reflections" % role)
	level.solo=true
	level.role=0
	level.water_fx.refresh()
	check(level.water.visible and level.water_fx.probes[0].visible,"Head/solo restores water effects")
	var after: Dictionary=level.make_snapshot()
	check(before.keys()==after.keys(),"Water adds no gameplay snapshot fields")
	level.flags.training=true
	level.flags.battery=true
	level.flags.pump_a=true
	level.flags.pump_b=true
	level.flags.lock=true
	level.basin_time=0
	level.lock_time=8
	level.capture_checkpoint(12)
	level.restore_checkpoint()
	level.water_fx.refresh()
	check(level.water.position.y== -6 and level.cargo and not level.flags.basin,"Checkpoint recovery still resets low basin and retains cargo")
	check(level.Save.valid(level.save_data()),"Existing save format remains valid")
	print("Water render checks: %d failures" % failures)
	level.queue_free()
	await frames(5)
	quit(1 if failures else 0)
