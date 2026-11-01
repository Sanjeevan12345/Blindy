extends SceneTree
var stage_name := "00-baseline"
var metadata: Array = []
func _initialize() -> void: call_deferred("capture")
func frames(n: int) -> void:
	for i in range(n): await process_frame
func save_view(level,view: String,at: Vector3,target: Vector3,fov: float=70) -> void:
	level.camera.position=at
	level.camera.fov=fov
	level.camera.look_at(target)
	await frames(36)
	RenderingServer.force_draw(false)
	var path := "res://output/art-pass/%s/%s.png" % [stage_name,view]
	root.get_texture().get_image().save_png(path)
	metadata.append({"view":view,"camera":[at.x,at.y,at.z],"target":[target.x,target.y,target.z],"fov":fov,"level":level.level_number,"stage":level.stage,"exposure":level.factory.environment.tonemap_exposure})
	print("ART CAPTURE ",path)
func capture() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="): stage_name=arg.get_slice("=",1)
	DirAccess.make_dir_recursive_absolute("res://output/art-pass/"+stage_name)
	root.size=Vector2i(1920,1080)
	root.show()
	for number in [3,2,1]:
		var path: String={1:"res://scenes/main.tscn",2:"res://scenes/level_two.tscn",3:"res://scenes/level_three.tscn"}[number]
		var level=load(path).instantiate()
		root.add_child(level)
		level.start_solo()
		level.set_process(false)
		level.set_physics_process(false)
		level.robot.set_simulation(false)
		if number==3:
			for key in level.flags: level.flags[key]=true
			level.flags.exit=false
			level.basin_time=0
			level.lock_time=8
			level.clock=9
			level.update_machinery()
		else:
			level.stage=5
			level.bridge_time=2
		level.apply_presentation(0)
		level.hud.hide()
		level.robot.visual.head.show()
		await frames(50)
		if number==3:
			await save_view(level,"level-3-hub",Vector3(0,3.3,9),Vector3(0,2,-35),72)
			level.basin_time=14
			level.update_machinery()
			await save_view(level,"level-3-water-high",Vector3(0,3.2,-7),Vector3(0,-1,-45))
			await save_view(level,"level-3-pump",Vector3(34,3,-48),Vector3(40,2,-56))
			level.factory.set_quality(false)
			await save_view(level,"level-3-reduced",Vector3(0,3.3,9),Vector3(0,2,-35),72)
			level.factory.set_quality(true)
			level.robot.position=level.Layout.START
			await save_view(level,"robot-materials",level.Layout.START+Vector3(-3.8,2.9,-4.5),level.Layout.START+Vector3(0,1.7,0),50)
		elif number==2:
			await save_view(level,"level-2-arrival",Vector3(-22,3,9),Vector3(-7,1,-15),65)
			await save_view(level,"level-2-destination",Vector3(22,2.6,-76),Vector3(1,1.8,-78),65)
		else:
			await save_view(level,"level-1-greenhouse",Vector3(0,2.8,-106),Vector3(-2,2,-116),72)
			await save_view(level,"level-1-boot",Vector3(0,2.84,5),Vector3(0,2,-16),72)
		level.queue_free()
		await frames(8)
	var file := FileAccess.open("res://output/art-pass/"+stage_name+"/cameras.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata,"  "))
	quit()
