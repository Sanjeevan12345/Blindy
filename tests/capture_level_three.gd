extends SceneTree
func _initialize() -> void: call_deferred("capture")
func frames(n: int) -> void:
	for i in range(n): await process_frame
func save_image(name: String) -> void:
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://output/"+name+".png")
	print("Saved ",name)
func capture() -> void:
	root.size=Vector2i(1920,1080)
	root.show()
	var level=load("res://scenes/level_three.tscn").instantiate()
	root.add_child(level)
	level.save_enabled=false
	level.start_solo()
	level.set_process(false)
	level.set_physics_process(false)
	level.robot.set_simulation(false)
	for key in level.flags: level.flags[key]=true
	level.flags.exit=false
	level.lock_time=8
	level.basin_time=14
	level.update_machinery()
	level.apply_presentation(0)
	level.robot.visual.head.show()
	level.hud.hide()
	level.camera.position=Vector3(90,90,85)
	level.camera.fov=36
	level.camera.look_at(Vector3(6,0,-36))
	await frames(90)
	save_image("level-three-overview")
	level.camera.position=Vector3(0,3.3,9)
	level.camera.fov=72
	level.camera.look_at(Vector3(0,2,-35))
	await frames(30)
	save_image("level-three-hub")
	level.camera.position=Vector3(-23,4,5)
	level.camera.look_at(Vector3(-40,1,-18))
	await frames(30)
	save_image("level-three-filtration")
	level.camera.position=Vector3(24,5,-9)
	level.camera.look_at(Vector3(38,-1,-40))
	await frames(30)
	save_image("level-three-pressure")
	level.flags.light_1=false
	level.flags.light_2=false
	level.update_machinery()
	level.robot.position=Vector3(50,0,-24)
	level.yaw=PI
	level.apply_presentation(0)
	level.hud.hide()
	await frames(30)
	save_image("level-three-inspection")
	quit()
