@tool
extends Node3D
## Reference-led procedural art asset. Forward is -Z. No collision or gameplay.
## Rounded panels and wear are actual realtime geometry/materials, not a billboard.

var cradle: Node3D
var wheel: Node3D
var head: Node3D
var orange: Material
var yellow: Material
var blue: Material
var metal: Material
var dark: Material
var rubber: Material
var glow: Material
var soil: Material
var green: Material
var pale_green: Material

func paint(color: String, amount: float = 0.5) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://materials/worn_paint.gdshader")
	m.set_shader_parameter("paint_color", Color(color))
	m.set_shader_parameter("wear", amount)
	return m

func standard(color: String, metallic: float = 0.0, rough: float = 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.metallic = metallic
	m.roughness = rough
	return m

func _ready() -> void:
	orange = paint("c97927")
	yellow = paint("e5a746")
	blue = paint("347f96", 0.7)
	metal = paint("555959", 0.8)
	dark = standard("1c292d", 0.65, 0.35)
	rubber = standard("181e20", 0.05, 0.94)
	glow = standard("66ecf4", 0.25, 0.22)
	glow.emission_enabled = true
	glow.emission = Color("24c9e2")
	glow.emission_energy_multiplier = 1.8
	soil = paint("423426", 0.8)
	green = standard("598e2c", 0, 0.55)
	pale_green = standard("8bbf42", 0, 0.55)
	build_wheel()
	build_torso()
	build_head()
	build_cargo()
	build_arms()

func mesh_node(mesh: Mesh, at: Vector3, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = material
	parent.add_child(node)
	return node

func group(label: String, at: Vector3, parent: Node3D = self) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = at
	parent.add_child(node)
	return node

func rounded(size: Vector3, radius: float) -> ArrayMesh:
	# Project a subdivided cube onto a bevelled box. Shared analytic normals
	# give smooth curved corners and planar sheet-metal panel faces.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := size * 0.5
	var inner := half - Vector3.ONE * radius
	var divisions := 12
	for face in range(6):
		var axis: int = floori(face / 2.0)
		var direction := 1.0 if face % 2 == 0 else -1.0
		var normal := Vector3.ZERO
		normal[axis] = direction
		var u := normal.cross(Vector3.UP if axis != 1 else Vector3.FORWARD).normalized()
		var v := normal.cross(u)
		for iy in range(divisions):
			for ix in range(divisions):
				for corner in [Vector2(0,0), Vector2(0,1), Vector2(1,1), Vector2(0,0), Vector2(1,1), Vector2(1,0)]:
					var uv: Vector2 = (Vector2(ix, iy) + corner) / float(divisions)
					var point: Vector3 = (normal + u * (uv.x * 2 - 1) + v * (uv.y * 2 - 1)) * half
					var core: Vector3 = point.clamp(-inner, inner)
					var bevel_normal: Vector3 = (point - core).normalized()
					st.set_normal(bevel_normal)
					st.set_uv(uv)
					st.add_vertex(core + bevel_normal * radius)
	st.generate_tangents()
	return st.commit()

func panel(at: Vector3, size: Vector3, material: Material, radius: float = 0.04, parent: Node3D = self) -> MeshInstance3D:
	return mesh_node(rounded(size, minf(radius, minf(size.x, minf(size.y, size.z)) * 0.45)), at, material, parent)

func cylinder(at: Vector3, radius: float, height: float, material: Material, parent: Node3D = self, axle: bool = false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 48
	var node := mesh_node(mesh, at, material, parent)
	if axle:
		node.rotation.z = PI / 2
	return node

func ring(at: Vector3, inner: float, outer: float, material: Material, parent: Node3D = self, axle: bool = false) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 40
	mesh.ring_segments = 12
	var node := mesh_node(mesh, at, material, parent)
	if axle:
		node.rotation.z = PI / 2
	return node

func bolt(at: Vector3, parent: Node3D = self) -> void:
	var cap := cylinder(at, 0.027, 0.018, metal, parent)
	cap.rotation.x = PI / 2
	panel(at + Vector3(0,0,-0.012), Vector3(0.024,0.006,0.006), dark, 0.001, parent)

func label3d(text: String, at: Vector3, size: int, parent: Node3D = self, color: Color = Color("d7cc9d")) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = size
	label.pixel_size = 0.0018
	label.outline_size = 0
	label.modulate = color
	parent.add_child(label)

func build_wheel() -> void:
	wheel = group("RollingWheel", Vector3(0,0.63,0))
	cylinder(Vector3.ZERO, 0.59, 0.46, rubber, wheel, true)
	for side in [-1.0, 1.0]:
		var x: float = side * 0.24
		ring(Vector3(x,0,0), 0.43, 0.58, rubber, wheel, true)
		cylinder(Vector3(x,0,0), 0.43, 0.04, dark, wheel, true)
		ring(Vector3(x + side * 0.026,0,0), 0.30, 0.345, metal, wheel, true)
		ring(Vector3(x + side * 0.032,0,0), 0.245, 0.265, glow, wheel, true)
		cylinder(Vector3(x + side * 0.045,0,0), 0.19, 0.03, metal, wheel, true)
		ring(Vector3(x + side * 0.067,0,0), 0.09, 0.115, glow, wheel, true)
		for i in range(10):
			var angle := TAU * i / 10
			cylinder(Vector3(x + side * 0.04, sin(angle)*0.37,cos(angle)*0.37),0.018,0.02,metal,wheel,true)
	# Chevron blocks make the tread readable in silhouette and close-up.
	var tread_mesh := rounded(Vector3(0.23, 0.045, 0.10), 0.012)
	for i in range(30):
		var a := TAU * i / 30
		for side in [-1.0, 1.0]:
			var pivot := group("Tread", Vector3.ZERO, wheel)
			pivot.rotation.x = a
			var tread := mesh_node(tread_mesh, Vector3(side*0.115,0.602,0), rubber, pivot)
			tread.rotation.y = side * 0.50
	# Partial curved blue mudguard, separate from the spinning tire.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(48):
		for c in [Vector2(0,0),Vector2(1,1),Vector2(0,1),Vector2(0,0),Vector2(1,0),Vector2(1,1)]:
			var a := lerpf(-1.32,1.32,(i+c.y)/48.0)
			st.set_normal(Vector3(0,cos(a),sin(a)))
			st.set_uv(Vector2(c.x,(i+c.y)/48.0))
			st.add_vertex(Vector3(lerpf(-0.35,0.35,c.x),0.63+0.69*cos(a),0.69*sin(a)))
	var fender_mat := blue.duplicate() as ShaderMaterial
	# Mesh is wound for its outside face.
	mesh_node(st.commit(), Vector3.ZERO, fender_mat)
	for side in [-1.0,1.0]:
		for a in [-1.0, -0.5, 0.5, 1.0]:
			var fastener := cylinder(Vector3(side*0.30,0.63+0.706*cos(a),0.706*sin(a)),0.026,0.016,metal)
			fastener.rotation.x = a
	panel(Vector3(0,1.29,0.09),Vector3(0.47,0.23,0.40),dark)

func build_torso() -> void:
	panel(Vector3(0,1.84,0.04),Vector3(1.12,1.13,0.70),dark,0.10)
	panel(Vector3(0,1.87,-0.02),Vector3(1.20,1.08,0.72),orange,0.10)
	for side in [-1.0,1.0]:
		panel(Vector3(side*0.50,1.91,-0.39),Vector3(0.16,0.91,0.08),yellow)
		for y in [1.47,2.24]:
			bolt(Vector3(side*0.49,y,-0.443))
	panel(Vector3(0,2.03,-0.412),Vector3(0.56,0.50,0.08),metal)
	panel(Vector3(0,2.04,-0.46),Vector3(0.43,0.37,0.035),dark,0.025)
	link(Vector3(0,1.99,-0.487),Vector3(0,2.16,-0.487),0.007,green)
	leaf(Vector3(0,2.06,-0.49),Vector3(-0.10,2.16,-0.49),0.035,green,self)
	leaf(Vector3(0,2.09,-0.49),Vector3(0.10,2.19,-0.49),0.035,pale_green,self)
	label3d("BLINDY",Vector3(0,1.73,-0.43),29)
	label3d("03",Vector3(-0.35,1.61,-0.43),23)
	for x in [-0.17,-0.09,-0.01]:
		panel(Vector3(x,1.92,-0.484),Vector3(0.04,0.012,0.008),green,0.002)
	# Back access panel, cooling slots and service cables.
	panel(Vector3(0,2.04,0.422),Vector3(0.72,0.45,0.08),metal)
	for x in [0.13,0.21,0.29]:
		panel(Vector3(x,2.08,0.47),Vector3(0.025,0.17,0.015),dark,0.005)
	panel(Vector3(0,1.60,0.43),Vector3(0.57,0.28,0.08),dark)
	for i in range(4):
		var wire_mat := standard(["813f30","b8a35a","395d54","232c2e"][i])
		var previous := Vector3(-0.18+i*0.10,1.68,0.49)
		for j in range(1,13):
			var t := j/12.0
			var next := Vector3(-0.18+i*0.10+sin(t*PI)*0.09,1.68-t*0.64,0.49+sin(t*PI)*0.12)
			link(previous,next,0.018,wire_mat)
			previous=next

func link(a: Vector3, b: Vector3, radius: float, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var node := cylinder((a+b)*0.5,radius,a.distance_to(b),material,parent)
	var direction := (b-a).normalized()
	if absf(direction.dot(Vector3.UP)) < 0.999:
		node.quaternion = Quaternion(Vector3.UP,direction)
	return node

func build_head() -> void:
	cylinder(Vector3(0,2.46,0),0.19,0.22,dark)
	for y in [2.39,2.44,2.49]:
		ring(Vector3(0,y,0),0.18,0.205,metal)
	head = group("Head",Vector3(0,2.84,0))
	head.rotation_degrees.z = -4
	panel(Vector3.ZERO,Vector3(1.27,0.77,0.76),yellow,0.14,head)
	panel(Vector3(0,0,-0.32),Vector3(1.17,0.67,0.17),metal,0.12,head)
	panel(Vector3(0,0,-0.412),Vector3(1.06,0.55,0.055),dark,0.10,head)
	for x in [-0.28,0.28]:
		var bezel := ring(Vector3(x,0,-0.456),0.15,0.19,metal,head)
		bezel.rotation.x = PI/2
		var lens := SphereMesh.new()
		lens.radius = 0.15
		lens.height = 0.30
		var eye := mesh_node(lens,Vector3(x,0,-0.463),glow,head)
		eye.scale = Vector3(1,1.12,0.34)
	panel(Vector3(0,0,-0.45),Vector3(0.075,0.023,0.012),metal,0.004,head)
	for side in [-1.0,1.0]:
		panel(Vector3(side*0.62,0,0.04),Vector3(0.16,0.44,0.44),blue,0.06,head)
		cylinder(Vector3(side*0.72,0,0.04),0.15,0.06,metal,head,true)
		cylinder(Vector3(side*0.758,0,0.04),0.103,0.018,glow,head,true)
	for x in [-0.48,0.48]:
		for y in [-0.24,0.24]:
			bolt(Vector3(x,y,-0.43),head)
	cylinder(Vector3(-0.48,0.49,0.15),0.052,0.23,dark,head)
	link(Vector3(-0.48,0.51,0.15),Vector3(-0.52,0.98,0.17),0.016,metal,head)
	panel(Vector3(0,0.06,0.39),Vector3(0.7,0.4,0.04),orange,0.04,head)
	label3d("B / 03",Vector3(0,0.05,0.418),27,head)

func build_cargo() -> void:
	cradle = group("Cradle",Vector3(0,1.57,-0.76))
	cylinder(Vector3.ZERO,0.39,0.15,metal,cradle)
	cylinder(Vector3(0,0.07,0),0.405,0.10,yellow,cradle)
	ring(Vector3(0,0.135,0),0.34,0.38,dark,cradle)
	cylinder(Vector3(0,0.16,0),0.32,0.08,soil,cradle)
	var glass := standard("c1e6eb",0.05,0.12)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.69,0.90,0.94,0.13)
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var shell := CylinderMesh.new()
	shell.top_radius = 0.355
	shell.bottom_radius = 0.355
	shell.height = 0.57
	shell.cap_top = false
	shell.cap_bottom = false
	shell.radial_segments = 64
	mesh_node(shell,Vector3(0,0.43,0),glass,cradle)
	ring(Vector3(0,0.715,0),0.347,0.358,standard("9abfc3",0.4,0.18),cradle)
	# Thin highlights on the glass remain readable in Compatibility renderer.
	var reflection := standard("bfe0df",0.2,0.2)
	reflection.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	reflection.albedo_color.a = 0.28
	panel(Vector3(-0.25,0.45,-0.248),Vector3(0.022,0.41,0.008),reflection,0.003,cradle)
	var stem_a := Vector3(0,0.19,0)
	var stem_b := Vector3(0.02,0.98,0)
	link(stem_a,stem_b,0.015,green,cradle)
	for i in range(6):
		var side := -1.0 if i%2==0 else 1.0
		var base := Vector3(0.01,0.32+i*0.10,0)
		var tip := base+Vector3(side*(0.25-i*0.018),0.15,-0.035)
		link(base,tip,0.007,green,cradle)
		leaf(base,tip,0.09 if i<4 else 0.06,pale_green if i%2 else green,cradle)
	var latch := cylinder(Vector3(0,0.065,-0.415),0.065,0.035,metal,cradle)
	latch.rotation.x = PI/2

func leaf(base: Vector3, tip: Vector3, width: float, material: Material, parent: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mid := base.lerp(tip,0.5)
	var perpendicular := (tip-base).normalized().cross(Vector3.FORWARD) * width
	var ridge := mid+Vector3(0,0,-0.035)
	for tri in [[base,mid+perpendicular,ridge],[mid+perpendicular,tip,ridge],[tip,mid-perpendicular,ridge],[mid-perpendicular,base,ridge]]:
		for point in tri:
			st.add_vertex(point)
		for point in [tri[2],tri[1],tri[0]]:
			st.add_vertex(point)
	st.generate_normals()
	mesh_node(st.commit(),Vector3.ZERO,material,parent)
	link(base,tip,0.004,pale_green,parent)

func build_arms() -> void:
	for side in [-1.0,1.0]:
		var shoulder := Vector3(side*0.69,2.15,0)
		var elbow := Vector3(side*0.86,1.61,-0.20)
		var wrist := Vector3(side*0.49,1.60,-0.79)
		cylinder(shoulder,0.23,0.20,dark,self,true)
		cylinder(shoulder+Vector3(side*0.12,0,0),0.17,0.07,yellow,self,true)
		cylinder(shoulder+Vector3(side*0.17,0,0),0.10,0.03,metal,self,true)
		arm_panel(shoulder,elbow,0.25,yellow)
		cylinder(elbow,0.15,0.29,dark,self,true)
		cylinder(elbow+Vector3(side*0.16,0,0),0.10,0.03,metal,self,true)
		arm_panel(elbow,wrist,0.27,orange)
		# Hands ride the cradle so grip stays attached while it tilts.
		var palm := Vector3(side*0.40,0.05,-0.10)
		panel(palm,Vector3(0.17,0.27,0.20),metal,0.04,cradle)
		for i in range(3):
			var y := -0.045+i*0.08
			panel(Vector3(side*0.33,y,-0.24),Vector3(0.20,0.061,0.12),dark,0.022,cradle)
			panel(Vector3(side*0.24,y,-0.29),Vector3(0.09,0.058,0.10),metal,0.02,cradle)
		panel(Vector3(side*0.34,0.23,-0.02),Vector3(0.10,0.19,0.11),dark,0.025,cradle).rotation.z = side*0.35
		cylinder(wrist,0.13,0.18,dark,self,true)
		cylinder(wrist+Vector3(side*0.1,0,0),0.072,0.025,glow,self,true)

func arm_panel(a: Vector3,b: Vector3,width: float,material: Material) -> void:
	var arm := panel((a+b)*0.5,Vector3(width,a.distance_to(b)*0.73,width),material,0.06)
	arm.quaternion = Quaternion(Vector3.UP,(a-b).normalized())
