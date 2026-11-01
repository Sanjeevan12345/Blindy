extends SceneTree
var level
var samples: Array = []
var solo_run := false
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in range(n):
		await process_frame
		RenderingServer.force_draw(true)
func position_camera(view: String) -> void:
	level.camera.fov=70
	if view=="hub":
		level.camera.position=Vector3(0,3.2,-7)
		level.camera.look_at(Vector3(0,-1,-45))
	else:
		level.camera.position=Vector3(39.8,2.9,-40)
		level.camera.look_at(Vector3(37.4,-0.6,-46))
func run() -> void:
	root.size=Vector2i(1920,1080)
	root.show()
	solo_run="--solo" in OS.get_cmdline_user_args()
	level=load("res://scenes/level_three.tscn").instantiate()
	root.add_child(level)
	level.save_enabled=false
	var sync=load("res://tests/water_benchmark_sync.gd").new()
	sync.name="WaterBenchmarkSync"
	root.add_child(sync)
	level.set_process(false)
	level.set_physics_process(false)
	var deadline := Time.get_ticks_msec()+25000
	while not level.running and Time.get_ticks_msec()<deadline: await process_frame
	if not level.running:
		push_error("Water benchmark clients did not connect")
		quit(1)
		return
	level.robot.set_simulation(false,not level.authority())
	for key in level.flags: level.flags[key]=true
	level.flags.exit=false
	level.basin_time=14
	level.lock_time=8
	level.clock=9
	level.update_machinery()
	level.apply_presentation(0)
	if solo_run or level.role==0: level.hud.hide()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	# One explicit draw per frame avoids measuring an extra forced render.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.set_render_loop_enabled(false)
	# Warm both cameras and both presets before scheduling shared samples.
	for high in [true,false]:
		level.factory.set_quality(high)
		level.water_fx.refresh()
		for view in ["hub","lock"]:
			position_camera(view)
			await frames(60)
	if solo_run: sync.epoch=Time.get_unix_time_from_system()+1.0
	elif level.authority(): sync.begin.rpc(Time.get_unix_time_from_system()+1.5)
	while sync.epoch<=0: await frames(1)
	var phases := [[true,"hub"],[true,"lock"],[false,"hub"],[false,"lock"]]
	for phase in range(4):
		var high: bool=phases[phase][0]
		var view: String=phases[phase][1]
		var start: float=sync.epoch+phase*3.0
		while Time.get_unix_time_from_system()<start: await frames(1)
		level.factory.set_quality(high)
		level.water_fx.refresh()
		position_camera(view)
		while Time.get_unix_time_from_system()<start+0.8: await frames(1)
		var elapsed: Array[float] = []
		var gpu: Array[float] = []
		var previous := Time.get_ticks_usec()
		while Time.get_unix_time_from_system()<start+3.0:
			level.clock+=1.0/60
			await frames(1)
			var now := Time.get_ticks_usec()
			elapsed.append((now-previous)/1000.0)
			previous=now
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		elapsed.sort()
		gpu.sort()
		var total := 0.0
		for value in elapsed: total+=value
		var n := elapsed.size()
		if n==0:
			push_error("No benchmark frames in synchronized window")
			quit(1)
			return
		samples.append({"mode":"solo" if solo_run else "three_clients","role":level.role,"view":view,"quality":"Maximum" if high else "Reduced","resolution":"1920x1080","frames":n,"mean_frame_ms":total/n,"median_frame_ms":elapsed[n/2],"p95_frame_ms":elapsed[mini(n-1,int(n*0.95))],"median_gpu_ms":gpu[n/2],"water_visible":level.water.visible,"vsync":false,"explicit_draws_per_frame":1})
	var suffix := "solo" if solo_run else "three-%d" % level.role
	var file := FileAccess.open("res://output/water-performance-"+suffix+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(samples,"  "))
	file.close()
	print("NETWORK PASS water benchmark ",suffix)
	level.queue_free()
	await frames(5)
	quit()
