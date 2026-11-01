extends RefCounted
## Decorative meshes only: never creates or changes gameplay collisions.
var art
var bevel_mesh: ArrayMesh
var ring_mesh: TorusMesh
var leaf_mesh: ArrayMesh
func install(level: Node3D) -> void:
	art=level.factory
	art.palette["orange"]=art.surface("ba642c",0.55,0.28)
	art.palette["cream"]=art.surface("a9a38d",0.35,0.15)
	art.palette["concrete"]=art.surface("656b65",0.0,0.1)
	art.palette["moss"]=art.surface("455c31",0.0,0.1)
	bevel_mesh=make_bevel()
	leaf_mesh=make_leaf()
	ring_mesh=TorusMesh.new()
	ring_mesh.inner_radius=0.72
	ring_mesh.outer_radius=1.0
	ring_mesh.rings=20
	ring_mesh.ring_segments=8
	var blocked: Array=level.gates.duplicate()
	if level.level_number==3: blocked.append_array(level.barriers.values())
	if is_instance_valid(level.bridge): blocked.append(level.bridge)
	for node in level.world.get_children():
		if not node is StaticBody3D or node in blocked: continue
		for child in node.get_children():
			if child is CollisionShape3D and child.shape is BoxShape3D:
				var size: Vector3=child.shape.size
				if size.y<=1.0 and size.x>=4 and size.z>=3: deck_skin(node,size)
	match level.level_number:
		1: factory_details()
		2: shaft_details()
		3: waterworks_details()
	art.flush()

func batch(mesh: Mesh,at: Vector3,size: Vector3,key: String,rotation: Vector3=Vector3.ZERO,kind: String="bevel") -> void:
	var id := key+"_"+kind
	if id not in art.batches: art.batches[id]={"mesh":mesh,"material":art.palette[key],"transforms":[]}
	art.batches[id].transforms.append(Transform3D((Basis.from_euler(rotation)*Basis.from_scale(size)),at))
func box(at: Vector3,size: Vector3,key: String,rotation: Vector3=Vector3.ZERO) -> void:
	batch(bevel_mesh,at,size,key,rotation)

func polygon(st: SurfaceTool,points: Array,normal: Vector3) -> void:
	if (points[1]-points[0]).cross(points[2]-points[0]).dot(normal)>0: points.reverse()
	for i in range(1,points.size()-1):
		for p in [points[0],points[i],points[i+1]]:
			st.set_normal(normal.normalized())
			st.set_uv(Vector2(p.x,p.z)+Vector2.ONE*0.5)
			st.add_vertex(p)
func make_bevel() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner := 0.44
	for axis in range(3):
		var a := (axis+1)%3
		var b := (axis+2)%3
		for side in [-1.0,1.0]:
			var points: Array=[]
			for pair in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				var p := Vector3.ZERO
				p[axis]=0.5*side
				p[a]=pair.x*inner
				p[b]=pair.y*inner
				points.append(p)
			var n := Vector3.ZERO
			n[axis]=side
			polygon(st,points,n)
	for free in range(3):
		var a := (free+1)%3
		var b := (free+2)%3
		for sa in [-1.0,1.0]:
			for sb in [-1.0,1.0]:
				var points: Array=[]
				for spec in [Vector2(-inner,0),Vector2(inner,0),Vector2(inner,1),Vector2(-inner,1)]:
					var p := Vector3.ZERO
					p[free]=spec.x
					p[a]=(0.5 if spec.y==0 else inner)*sa
					p[b]=(inner if spec.y==0 else 0.5)*sb
					points.append(p)
				var n := Vector3.ZERO
				n[a]=sa
				n[b]=sb
				polygon(st,points,n)
	for x in [-1.0,1.0]:
		for y in [-1.0,1.0]:
			for z in [-1.0,1.0]: polygon(st,[Vector3(x*0.5,y*inner,z*inner),Vector3(x*inner,y*0.5,z*inner),Vector3(x*inner,y*inner,z*0.5)],Vector3(x,y,z))
	return st.commit()

func flange(at: Vector3,axis: Vector3,radius: float,key: String="steel") -> void:
	var basis := Basis.IDENTITY
	if axis.dot(Vector3.UP)< -0.99: basis=Basis(Vector3.RIGHT,PI)
	elif axis.dot(Vector3.UP)<0.99: basis=Basis(Quaternion(Vector3.UP,axis))
	batch(ring_mesh,at,Vector3(radius,0.2,radius),key,basis.get_euler(),"ring")
	for i in range(8):
		var a := TAU*i/8
		var p := at+basis*Vector3(cos(a)*radius*0.87,0,sin(a)*radius*0.87)
		art.rod(p-axis*0.12,p+axis*0.12,radius*0.065,"steel")
func pipe(a: Vector3,b: Vector3,radius: float,key: String="orange") -> void:
	art.rod(a,b,radius,key)
	var axis := (b-a).normalized()
	flange(a+axis*0.15,axis,radius*1.45)
	flange(b-axis*0.15,axis,radius*1.45)
	if a.distance_to(b)>7: flange((a+b)*0.5,axis,radius*1.4)

func deck_skin(node: Node3D,size: Vector3) -> void:
	var transform := node.global_transform
	for side in [-1,1]:
		box(transform*Vector3(side*(size.x*0.5-0.10),-0.2,0),Vector3(0.20,0.65,size.z),"steel",node.global_rotation)
		if size.x>=7 and size.z>=5:
			art.box(transform*Vector3(side*(size.x*0.5-0.25),size.y*0.5+0.004,0),Vector3(0.10,0.008,size.z),"yellow",node.global_rotation)
		for i in range(maxi(1,ceili(size.z/6))):
			var z := -size.z*0.5+(i+0.5)*size.z/maxi(1,ceili(size.z/6))
			box(transform*Vector3(side*(size.x*0.5-0.5),-2.7,z),Vector3(0.45,5.2,0.55),"blue",node.global_rotation)
			box(transform*Vector3(side*(size.x*0.5-0.55),-0.6,z),Vector3(0.8,0.5,0.8),"orange",node.global_rotation)
	# Crossmembers stay entirely below the collision deck.
	for i in range(maxi(1,ceili(size.z/5))):
		var z := -size.z*0.5+(i+0.5)*size.z/maxi(1,ceili(size.z/5))
		box(transform*Vector3(0,-0.5,z),Vector3(size.x,0.4,0.22),"steel",node.global_rotation)

func facade(at: Vector3,width: float,height: float,yaw: float=0,key: String="orange") -> void:
	var basis := Basis(Vector3.UP,yaw)
	box(at+basis*Vector3(0,height*0.5,0),Vector3(width,height,1.8),key,Vector3(0,yaw,0))
	box(at+basis*Vector3(0,height*0.48,0.95),Vector3(width*0.74,height*0.72,0.25),"black",Vector3(0,yaw,0))
	box(at+basis*Vector3(0,height*0.47,1.1),Vector3(width*0.60,height*0.61,0.12),"steel",Vector3(0,yaw,0))
	for side in [-1,1]:
		box(at+basis*Vector3(side*width*0.39,height*0.49,1.12),Vector3(0.22,height*0.75,0.20),"yellow",Vector3(0,yaw,0))
		for y in [0.4,height-0.4]: box(at+basis*Vector3(side*(width*0.5-0.35),y,1),Vector3(0.26,0.3,0.15),"steel",Vector3(0,yaw,0))
	box(at+basis*Vector3(0,height*0.85,1.12),Vector3(width*0.64,0.15,0.12),"amber",Vector3(0,yaw,0))
	for i in range(5): box(at+basis*Vector3((i-2)*0.42,height*0.18,1.2),Vector3(0.20,0.45,0.06),"black",Vector3(0,yaw,0))

func plant(at: Vector3,scale: float=1) -> void:
	box(at+Vector3(0,0.18,0)*scale,Vector3(0.9,0.35,0.75)*scale,"blue")
	box(at+Vector3(0,0.36,0)*scale,Vector3(0.8,0.05,0.65)*scale,"soil")
	for i in range(5):
		var start := at+Vector3((i-2)*0.12,0.37,0)*scale
		var top := start+Vector3(sin(i*2.3)*0.15,0.45+(i%3)*0.2,cos(i*2.3)*0.1)*scale
		art.rod(start,top,0.018*scale,"leaf")
		for side in [-1,1]:
			leaf(top+Vector3(side*0.15,-0.13,0)*scale,Vector3(0.44,0.44,0.75)*scale,Vector3(0,i*0.6,side*0.55))

func make_leaf() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline := [Vector3(-0.5,0,0),Vector3(-0.05,0.02,0.22),Vector3(0.5,0.03,0),Vector3(-0.05,0.02,-0.22)]
	for i in range(4): polygon(st,[Vector3(0,0.08,0),outline[i],outline[(i+1)%4]],Vector3.UP)
	return st.commit()
func leaf(at: Vector3,size: Vector3,rotation: Vector3) -> void:
	if leaf_mesh==null: leaf_mesh=make_leaf()
	batch(leaf_mesh,at,size,"leaf",rotation,"leaf")

func wall_bays(xs: Array,zs: Array) -> void:
	for x in xs:
		for z in zs:
			box(Vector3(x,7,z),Vector3(0.8,15,0.8),"steel")
			box(Vector3(x,7,z+4),Vector3(0.45,5,6),"blue")
			box(Vector3(x,2,z+4),Vector3(0.5,2,6),"concrete")
			for height in [3.5,10]: box(Vector3(x, height,z+4),Vector3(0.9,0.22,7.5),"steel")
			pipe(Vector3(x-0.8,-7,z+2),Vector3(x-0.8,12,z+2),0.45)

func waterworks_details() -> void:
	for at in [Vector3(-32,0,-49.5),Vector3(38,0,-59.5)]:
		facade(at,8,7)
		pipe(at+Vector3(-3,-2,2),at+Vector3(-3,8.5,2),0.6)
		pipe(at+Vector3(3,-2,2),at+Vector3(3,7,2),0.45,"blue")
		for side in [-1,1]:
			box(at+Vector3(side*4.8,1.4,0),Vector3(2,2.8,2),"blue")
			plant(at+Vector3(side*4.8,2.8,0),1.5)
		flange(at+Vector3(0,3.3,1.4),Vector3.FORWARD,1.25,"yellow")
	facade(Vector3(0,3.6,-110),9,10)
	facade(Vector3(0,0,45),9,7,PI)
	for x in [-7,7]:
		box(Vector3(x,1.5,4),Vector3(2,3,2.4),"blue")
		plant(Vector3(x,3,4),1.4)
		pipe(Vector3(x,-5,4),Vector3(x,5,4),0.5)
	for x in [-24.5,24.5]:
		for z in [-24,-48,-72]:
			box(Vector3(x,-2,z),Vector3(0.65,4,3.5),"orange")
			plant(Vector3(x,0.1,z),1.1)
	wall_bays([-70,74],[-90,-66,-42,-18,6])
	# A substantial pipe gallery above the basin, clear of all robot/head paths.
	for x in [-20,20]:
		pipe(Vector3(x,11,-12),Vector3(x,11,-84),0.65)
		pipe(Vector3(x,-7,-10),Vector3(x,9,-10),0.65)
		for i in range(16):
			var a := PI*0.5*i/16
			var b := PI*0.5*(i+1)/16
			art.rod(Vector3(x,9+2*sin(a),-12+2*cos(a)),Vector3(x,9+2*sin(b),-12+2*cos(b)),0.65,"orange")
	for z in [-30,-60]:
		box(Vector3(0,13,z),Vector3(48,0.8,0.8),"steel")
		for x in [-20,20]: art.rod(Vector3(x,11,z),Vector3(x,13,z),0.08,"steel")

func shaft_details() -> void:
	for x in [-2,6]: flange(Vector3(x,1.75,6.3),Vector3.UP,2.2,"blue")
	facade(Vector3(-21.8,0,14),7.5,7.5,PI/2)
	facade(Vector3(1,0,-83.3),8,7)
	for at in [Vector3(0,0,-30),Vector3(20,-6,-40)]:
		box(at+Vector3(0,-4,0),Vector3(7,6.5,6),"blue")
		for side in [-1,1]:
			pipe(at+Vector3(side*5.5,-12,-3),at+Vector3(side*5.5,5,-3),0.55)
			plant(at+Vector3(side*5.5,0.1,3),1.3)
	for at in [Vector3(-20,0,17),Vector3(4,0,-81)]: plant(at,1.5)
	wall_bays([-33,33],[-80,-56,-32,-8,16])

func factory_details() -> void:
	facade(Vector3(3,0,-152.8),8,8)
	for z in [-8,-35,-80]:
		for side in [-1,1]:
			facade(Vector3(side*9.5,0,z),4.5,4,-side*PI/2,"blue")
			pipe(Vector3(side*9,-6,z-2),Vector3(side*9,8,z-2),0.5)
	# Greenhouse arch, glazed upper panels and richer planting beds.
	for side in [-1,1]:
		for z in [-105,-110,-115,-120]:
			box(Vector3(side*5.6,2.5,z),Vector3(0.22,5,0.25),"cream")
			plant(Vector3(side*4.5,0.8,z+0.5),1.5)
	for z in [-105,-110,-115,-120]:
		box(Vector3(0,5.2,z),Vector3(11.5,0.25,0.3),"cream")
		pipe(Vector3(-5.5,5.5,z),Vector3(5.5,5.5,z),0.1,"blue")
	wall_bays([-16,16],[-140,-116,-92,-68,-44,-20,4])
