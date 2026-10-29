extends SceneTree
## Actual Forward+ renders and a short 1080p frame-time sample, not concept art.
func _initialize() -> void:
	call_deferred("capture")
func wait_frames(count: int) -> void:
	for i in range(count):
		await process_frame
func save_image(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/"+name+".png")
func sample(level, high: bool) -> Dictionary:
	level.factory.set_quality(high)
	await wait_frames(60)
	var start := Time.get_ticks_usec()
	await wait_frames(180)
	var seconds := (Time.get_ticks_usec()-start)/1000000.0
	return {"quality":"high" if high else "reduced", "resolution":"1920x1080", "average_fps":180.0/seconds, "average_ms":seconds/180*1000, "draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
func capture() -> void:
	root.size=Vector2i(1920,1080)
	var level=load("res://scenes/main.tscn").instantiate()
	root.add_child(level)
	level.start_solo()
	level.set_process(false)
	level.set_physics_process(false)
	level.robot.set_simulation(false)
	level.hud.hide()
	await wait_frames(90)
	for entry in [
		["factory-boot",Vector3(0,0,5),0,Vector3(0,3,-16)],
		["factory-sorting",Vector3(3.7,0,-18),1,Vector3(-2,3,-26)],
		["factory-conveyor",Vector3(0,0,-55),3,Vector3(0,3,-73)],
		["factory-greenhouse",Vector3(0,0,-108),5,Vector3(-2,2,-116)],
		["factory-lift",Vector3(3,0,-138),7,Vector3(3,3,-151)]
	]:
		level.robot.position=entry[1]
		level.stage=entry[2]
		level.bridge_time=2
		level.cargo=level.stage>=6
		level.apply_presentation(0)
		level.camera.look_at(entry[3])
		await wait_frames(35)
		await save_image(entry[0])
	# External overview of the real post-pickup robot on the return catwalk.
	level.stage=7
	level.cargo=true
	level.robot.position=Vector3(3,0,-139)
	level.apply_presentation(0)
	level.robot.visual.head.show()
	level.camera.fov=50
	level.camera.position=level.robot.position+Vector3(-3.8,2.8,-4.4)
	level.camera.look_at(level.robot.position+Vector3(0,1.8,0))
	await wait_frames(50)
	await save_image("factory-overview")
	var results: Array=[]
	results.append(await sample(level,true))
	results.append(await sample(level,false))
	var file := FileAccess.open("res://output/factory-performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"  "))
	print("FACTORY PERFORMANCE: ",JSON.stringify(results))
	quit()
