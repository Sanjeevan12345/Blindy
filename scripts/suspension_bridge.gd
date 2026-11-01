extends AnimatableBody3D
## Continuous deck collision; visual plank seams cannot snag the tire.
var span := 10.0
var width := 2.4
var initial_transform := Transform3D.IDENTITY
var sway_amplitude := 0.9
var phase := 0.0

func build(a: Vector3,b: Vector3,art: Node3D,offset: float) -> void:
	span=a.distance_to(b)
	phase=offset
	var center := (a+b)*0.5-Vector3(0,0.14,0)
	var direction := (b-a).normalized()
	# Construct explicitly: sync_to_physics can defer setters and return the old
	# transform when a just-added AnimatableBody is configured in the same frame.
	sync_to_physics=false
	initial_transform=Transform3D(Basis(Vector3.UP,atan2(-direction.x,-direction.z)),center)
	transform=initial_transform
	sync_to_physics=true
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=Vector3(width,0.28,span+0.1)
	collision.shape=shape
	add_child(collision)
	var material: Material=art.surface("667078",0.7,0.3,1)
	var plank := BoxMesh.new()
	plank.size=Vector3(width,0.12,0.58)
	var mm := MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.mesh=plank
	mm.instance_count=ceili(span/0.60)
	for i in range(mm.instance_count):
		mm.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(0,0.08,-span*0.5+(i+0.5)*span/mm.instance_count)))
	var deck := MultiMeshInstance3D.new()
	deck.multimesh=mm
	deck.material_override=material
	add_child(deck)
	for side in [-1,1]:
		for i in range(ceili(span/3.0)+1):
			var z := lerpf(-span*0.5,span*0.5,i/float(ceili(span/3.0)))
			local_rod(Vector3(side*width*0.5,0.1,z),Vector3(side*width*0.5,1.45,z),0.045,art.palette["yellow"])
			local_lamp(Vector3(side*width*0.5,1.48,z),art.palette["amber"])
		for i in range(24):
			var t := i/24.0
			var u := (i+1)/24.0
			for height in [1.1,1.6]:
				local_rod(Vector3(side*width*0.5,height-sin(t*PI)*0.35,lerpf(-span*0.5,span*0.5,t)),Vector3(side*width*0.5,height-sin(u*PI)*0.35,lerpf(-span*0.5,span*0.5,u)),0.023,art.palette["black"])

func local_rod(a: Vector3,b: Vector3,radius: float,material: Material) -> void:
	var rod := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=a.distance_to(b)
	mesh.radial_segments=8
	rod.mesh=mesh
	rod.material_override=material
	rod.position=(a+b)*0.5
	var direction := (b-a).normalized()
	if absf(direction.dot(Vector3.UP))<0.999:
		rod.quaternion=Quaternion(Vector3.UP,direction)
	add_child(rod)

func local_lamp(at: Vector3,material: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size=Vector3(0.12,0.16,0.12)
	node.mesh=mesh
	node.material_override=material
	node.position=at
	add_child(node)

func set_wave(time: float) -> void:
	transform=initial_transform*Transform3D(Basis.from_euler(Vector3(0,0,deg_to_rad(sway_amplitude)*sin(time*1.35+phase))),Vector3.ZERO)
