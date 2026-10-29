extends RefCounted
## Heading-based test driver. It uses exactly the player's steering/throttle API.
static func command(position: Vector3, velocity: Vector3, yaw: float, target: Vector3) -> Vector2:
	var diff := Vector2(target.x-position.x,target.z-position.z)
	var distance := diff.length()
	if distance<0.10:
		return Vector2.ZERO
	var desired_yaw := atan2(-diff.x,-diff.y)
	var error := wrapf(desired_yaw-yaw,-PI,PI)
	var speed := Vector2(velocity.x,velocity.z).length()
	var rate := deg_to_rad(lerpf(100,45,clampf(speed/6.0,0,1)))
	var steer := clampf(-error*2.4/rate,-1,1)
	var target_speed := minf(3.8,sqrt(maxf(0,2*3.0*(distance-0.10))))
	var throttle := target_speed/6.0 if absf(error)<0.22 else 0.0
	return Vector2(steer,-throttle)
