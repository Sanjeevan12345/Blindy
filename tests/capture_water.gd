extends SceneTree
var level
func _initialize() -> void: call_deferred("capture")
func frames(n: int) -> void:
	for i in range(n): await process_frame
func capture() -> void:
	root.size=Vector2i(1920,1080)
	root.show()
	level=load("res://scenes/level_three.tscn").instantiate()
	root.add_child(level)
	level.save_enabled=false
	level.start_solo()
	level.set_process(false)
	level.set_physics_process(false)
	level.robot.set_simulation(false)
	for key in level.flags: level.flags[key]=true
	level.flags.exit=false
	level.hud.hide()
	level.camera.fov=70
	var prefix := "before" if "--before" in OS.get_cmdline_user_args() else "after"
	for high in [false,true]:
		level.basin_time=14 if high else 0
		level.lock_time=8 if high else 0
		level.clock=9
		level.update_machinery()
		for view in ["hub","raft","lock"]:
			match view:
				"hub":
					level.camera.position=Vector3(0,3.2,-7)
					level.camera.look_at(Vector3(0,-1,-45))
				"raft":
					level.camera.position=Vector3(6,level.water.position.y+3.3,-34)
					level.camera.look_at(Vector3(-3,level.water.position.y,-49))
				"lock":
					level.camera.position=Vector3(39.8,level.lock_water.position.y+3.5,-40)
					level.camera.look_at(Vector3(37.4,level.lock_water.position.y,-46))
			await frames(40)
			RenderingServer.force_draw(false)
			var path := "res://output/water-%s-%s-%s.png" % [prefix,view,"high" if high else "low"]
			root.get_texture().get_image().save_png(path)
			print("Saved ",path)
	if prefix=="after":
		level.camera.position=Vector3(0,3.2,-7)
		for side in [-1,1]:
			level.camera.look_at(Vector3(side*12,-1,-45))
			await frames(30)
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png("res://output/water-after-pan-%s.png" % ("left" if side<0 else "right"))
		level.factory.set_quality(false)
		level.camera.look_at(Vector3(0,-1,-45))
		await frames(30)
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://output/water-reduced-hub-high.png")
		level.factory.set_quality(true)
		level.basin_time=7
		level.lock_time=4
		level.update_machinery()
		level.camera.position=Vector3(-5,level.water.position.y+2.8,-41.5)
		level.camera.look_at(Vector3(-9,level.water.position.y,-53))
		for i in range(40):
			level.clock+=1.0/60
			await frames(1)
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://output/water-after-fill-detail.png")
	level.queue_free()
	await frames(5)
	quit()
