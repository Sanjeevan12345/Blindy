extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func frames(n: int) -> void:
	for i in range(n):
		await process_frame
func save_image(name: String) -> void:
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://output/"+name+".png")
	print("Saved ",name)
func capture() -> void:
	root.size=Vector2i(1920,1080)
	root.mode=Window.MODE_WINDOWED
	root.show()
	var level=load("res://scenes/level_two.tscn").instantiate()
	root.add_child(level)
	level.start_solo()
	level.set_process(false)
	level.set_physics_process(false)
	level.robot.set_simulation(false)
	level.robot.position=level.Layout.START
	level.stage=5 # Art overview shows the complete route with both gates open.
	level.apply_presentation(0)
	level.robot.visual.head.show()
	level.hud.hide()
	level.camera.position=Vector3(29,30,32)
	level.camera.fov=45
	level.camera.look_at(Vector3(0,-4,-32))
	await frames(90)
	await save_image("level-two-overview")
	level.camera.position=Vector3(-22,3,9)
	level.camera.fov=65
	level.camera.look_at(Vector3(-7,1,-15))
	await frames(30)
	await save_image("level-two-route-choice")
	level.camera.position=Vector3(0,2,-30)
	level.camera.look_at(Vector3(20,-6,-20))
	await frames(30)
	await save_image("level-two-freight")
	level.camera.position=Vector3(22,2.6,-76)
	level.camera.look_at(Vector3(1,1.8,-78))
	await frames(30)
	await save_image("level-two-final-bridge")
	print("Level 2 actual renders saved under output/level-two-*.png")
	quit()
