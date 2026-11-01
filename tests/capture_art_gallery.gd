extends SceneTree
func _initialize() -> void: call_deferred("capture")
func frames(n: int) -> void:
	for i in range(n): await process_frame
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
	level.robot.position=Vector3(50,0,-24)
	level.yaw=PI
	level.flags.pump_b=true
	level.apply_presentation(0)
	level.hud.hide()
	await frames(45)
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://output/art-pass/04-final-foliage/inspection-gallery.png")
	level.flags.light_1=true
	level.flags.light_2=true
	level.update_machinery()
	await frames(30)
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://output/art-pass/04-final-foliage/inspection-gallery-lit.png")
	level.camera.position=Vector3(34,3,-48)
	level.camera.fov=70
	level.camera.look_at(Vector3(40,2,-56))
	await frames(30)
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://output/art-pass/04-final-foliage/level-3-pump-readable.png")
	level.queue_free()
	await frames(5)
	quit()
