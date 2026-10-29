extends RigidBody3D
## Host-simulated, wheel-contact force model. Forward is local -Z.
## drive_input.x = clockwise steering; drive_input.y = reverse (negative forward).
signal fell
const START := Vector3(0,1.2,5)
@export var robot_mass := 80.0
@export var tire_radius := 0.61
@export var forward_limit := 6.0
@export var reverse_limit := 3.0
@export var acceleration := 3.5
@export var braking := 4.5
@export var grip := 0.95
@export var jump_height := 1.4
@export var balance_strength := 1500.0
@export var balance_damping := 500.0
@export var balance_torque_limit := 700.0
var drive_input := Vector2.ZERO
var balance_input := 0.0
var brace := false
var jump_requested := false
var cargo_tilt := 0.0
var water := 100.0
var spills := 0
var visual: Node3D
var cradle: Node3D
var wheel: Node3D
var last_velocity := Vector3.ZERO
var spill_cooldown := 0.0
var finished := false
var auto_stabilize := false
var checkpoint_position := START
var checkpoint_heading := 0.0
var grounded := false
var ground_normal := Vector3.UP
var jump_buffer := 0.0
var coyote := 0.0
var jump_used := false
var airborne_time := 0.0
var tip_time := 0.0
var recovery_time := 0.0
var recovering := false
var simulation_enabled := true
var remote_replica := false
var suspension := 0.0
var suspension_velocity := 0.0
var visual_pitch := 0.0
var visual_roll := 0.0
var wheel_angle := 0.0
var reset_pending := false
var reset_transform := Transform3D.IDENTITY
var collision_count := 0
var velocity: Vector3:
	get: return linear_velocity
	set(value): linear_velocity = value

func _ready() -> void:
	mass=robot_mass
	gravity_scale=1.0
	linear_damp=0.04
	angular_damp=0.1
	center_of_mass_mode=RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass=Vector3(0,1.05,0)
	contact_monitor=true
	max_contacts_reported=12
	continuous_cd=true
	can_sleep=false
	var tire := CylinderShape3D.new()
	tire.radius=tire_radius
	tire.height=0.46
	var collider := CollisionShape3D.new()
	collider.shape=tire
	collider.position=Vector3(0,0.63,0)
	collider.rotation.z=PI/2
	add_child(collider)
	for spec in [[Vector3(0,1.85,0),Vector3(1.12,1.08,0.70)],[Vector3(0,2.84,0),Vector3(1.2,0.70,0.72)]]:
		var box := BoxShape3D.new()
		box.size=spec[1]
		var body_shape := CollisionShape3D.new()
		body_shape.position=spec[0]
		body_shape.shape=box
		add_child(body_shape)
	var physics_mat := PhysicsMaterial.new()
	# Explicit tire forces supply friction; avoid hidden isotropic floor drag.
	physics_mat.friction=0.0
	physics_mat.bounce=0.0
	physics_material_override=physics_mat
	position=START
	visual=preload("res://scenes/robot_visual.tscn").instantiate()
	add_child(visual)
	cradle=visual.cradle
	wheel=visual.wheel

func heading() -> float:
	var f := -global_basis.z
	return atan2(-f.x,-f.z)

func forward() -> Vector3:
	return Vector3(-sin(heading()),0,-cos(heading()))

func signed_speed() -> float:
	return linear_velocity.dot(forward())

func tilt_degrees() -> float:
	return rad_to_deg(acos(clampf(global_basis.y.dot(Vector3.UP),-1,1)))

func is_on_floor() -> bool:
	return grounded

func get_slide_collision_count() -> int:
	return collision_count

func set_simulation(enabled: bool, replica: bool=false) -> void:
	simulation_enabled=enabled
	remote_replica=replica
	freeze=not enabled
	# Frozen network replicas and cinematic/lobby bodies must not block others.
	collision_layer=0 if replica else 1
	collision_mask=0 if replica else 1
	if not enabled:
		drive_input=Vector2.ZERO
		jump_requested=false
		linear_velocity=Vector3.ZERO
		angular_velocity=Vector3.ZERO

func probe_ground(state: PhysicsDirectBodyState3D) -> bool:
	ground_normal=Vector3.UP
	# Tire-relative rays, not head/body contacts. Wall touches never enable jumps.
	for x in [-0.18,0.0,0.18]:
		var origin := state.transform*Vector3(x,0.65,0)
		var end := state.transform*Vector3(x,-0.09,0)
		var query := PhysicsRayQueryParameters3D.create(origin,end)
		query.exclude=[get_rid()]
		var hit := state.get_space_state().intersect_ray(query)
		if not hit.is_empty() and hit.normal.dot(Vector3.UP)>0.6:
			ground_normal=hit.normal
			return true
	return false

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if reset_pending:
		state.transform=reset_transform
		state.linear_velocity=Vector3.ZERO
		state.angular_velocity=Vector3.ZERO
		reset_pending=false
	if not simulation_enabled or finished:
		return
	var dt := state.step
	var previous_grounded := grounded
	grounded=probe_ground(state) and state.linear_velocity.y<1.0
	collision_count=state.get_contact_count()
	var up := state.transform.basis.y
	var tilt := rad_to_deg(acos(clampf(up.dot(Vector3.UP),-1,1)))
	if recovering:
		recovery_time-=dt
		state.linear_velocity=Vector3.ZERO
		state.angular_velocity=Vector3.ZERO
		if recovery_time<=0:
			recovering=false
			reset_robot()
			fell.emit()
		return
	tip_time=tip_time+dt if tilt>55 else 0.0
	if tip_time>=1.0 or state.transform.origin.y< -6:
		recovering=true
		recovery_time=0.4
		drive_input=Vector2.ZERO
		return
	jump_buffer=maxf(0,jump_buffer-dt)
	if jump_requested:
		jump_buffer=0.1
		jump_requested=false
	if grounded:
		coyote=0.08
		if airborne_time>0.12:
			jump_used=false
		airborne_time=0
	else:
		coyote=maxf(0,coyote-dt)
		airborne_time+=dt
	if jump_buffer>0 and coyote>0 and not jump_used and tilt<35:
		var g := maxf(0.01,state.total_gravity.length())
		state.linear_velocity.y=sqrt(2.0*g*jump_height)
		jump_used=true
		jump_buffer=0
		coyote=0
		grounded=false
	var f := Vector3(-state.transform.basis.z.x,0,-state.transform.basis.z.z).normalized()
	var right := f.cross(Vector3.UP)
	var speed := state.linear_velocity.dot(f)
	var lateral := state.linear_velocity.dot(right)
	if grounded and tilt<55:
		var throttle := -clampf(drive_input.y,-1,1)
		var steer := clampf(drive_input.x,-1,1)
		var limit := (forward_limit if throttle>=0 else reverse_limit)
		if brace:
			limit=minf(limit,2.5)
		var desired_speed := throttle*limit
		var slowing := absf(throttle)<0.01 or speed*throttle<0 or absf(speed)>absf(desired_speed)
		var motor_accel := clampf((desired_speed-speed)*4.0,-braking if slowing else -acceleration,braking if slowing else acceleration)
		var lateral_accel := -lateral*7.5
		var tire_force := (f*motor_accel+right*lateral_accel)*mass
		tire_force=tire_force.limit_length(grip*mass*state.total_gravity.length())
		state.apply_central_force(tire_force)
		var rate := deg_to_rad(lerpf(100,45,clampf(absf(speed)/forward_limit,0,1)))
		var yaw_target := -steer*rate
		var yaw_torque := clampf((yaw_target-state.angular_velocity.y)*180,-220,220)
		state.apply_torque(Vector3.UP*yaw_torque)
		# Offset wheel drive/contact forces create actual pitching and cornering load.
		state.apply_torque(right*(-motor_accel*mass*0.28))
		state.apply_torque(f*(-speed*state.angular_velocity.y*mass*0.30))
	# Limited gyro can recover small disturbances, not an overturned chassis.
	if tilt<55:
		var angular_horizontal := Vector3(state.angular_velocity.x,0,state.angular_velocity.z)
		var stabilizer := up.cross(Vector3.UP)*balance_strength-angular_horizontal*balance_damping
		state.apply_torque(stabilizer.limit_length(balance_torque_limit*(1.5 if brace else 1.0)))
	center_of_mass=Vector3(0,0.85 if brace else 1.05,0)
	var accel := (state.linear_velocity-last_velocity)/maxf(dt,0.001)
	var local_accel := state.transform.basis.inverse()*accel
	if previous_grounded==false and grounded:
		suspension_velocity-=minf(1.5,absf(last_velocity.y)*0.16)
		cargo_tilt+=0.12*signf(cargo_tilt+0.001) if not brace else 0.02
	update_visuals(dt,speed,local_accel)
	last_velocity=state.linear_velocity

func update_visuals(dt: float, speed: float, local_accel: Vector3) -> void:
	cargo_tilt+=local_accel.x*0.08*dt+balance_input*0.85*dt
	cargo_tilt=move_toward(cargo_tilt,0,(3.0 if auto_stabilize else (0.8 if brace else 0.2))*dt)
	cargo_tilt=clampf(cargo_tilt,-1.1,1.1)
	spill_cooldown-=dt
	if not auto_stabilize and absf(cargo_tilt)>0.65 and spill_cooldown<=0:
		water=maxf(0,water-5)
		spills+=1
		spill_cooldown=0.7
	cradle.rotation.z=cargo_tilt
	wheel_angle-=speed/tire_radius*dt
	wheel.rotation.x=wheel_angle
	suspension_velocity+=(-suspension*85-suspension_velocity*15)*dt
	suspension=clampf(suspension+suspension_velocity*dt,-0.10,0.07)
	visual.position.y=suspension
	visual_pitch=lerpf(visual_pitch,clampf(local_accel.z*0.008,-0.05,0.05),1-exp(-8*dt))
	visual_roll=lerpf(visual_roll,clampf(-local_accel.x*0.008,-0.06,0.06),1-exp(-8*dt))
	visual.rotation=Vector3(visual_pitch,0,visual_roll)

func teleport(at: Vector3, yaw: float=0) -> void:
	reset_transform=Transform3D(Basis(Vector3.UP,yaw),at)
	global_transform=reset_transform
	reset_pending=true
	linear_velocity=Vector3.ZERO
	angular_velocity=Vector3.ZERO
	grounded=false

func reset_robot() -> void:
	teleport(checkpoint_position,checkpoint_heading)
	drive_input=Vector2.ZERO
	last_velocity=Vector3.ZERO
	cargo_tilt=0
	water=100
	spills=0
	spill_cooldown=0
	finished=false
	jump_requested=false
	jump_buffer=0
	coyote=0
	jump_used=false
	airborne_time=0
	tip_time=0
	recovering=false
	recovery_time=0
	suspension=0
	suspension_velocity=0
	visual_pitch=0
	visual_roll=0
	if is_instance_valid(visual):
		visual.position=Vector3.ZERO
		visual.rotation=Vector3.ZERO
