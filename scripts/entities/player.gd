extends CharacterBody3D

var SENSITIVITY = 0.06

const SPEED := 5.0				# ground wishspeed
const AIR_CAP := 1.0			# cap on wishspeed used for the air-accel target
const GROUND_ACCEL := 14.0		# ground sv_accelerate
const AIR_ACCEL := 14.0			# air sv_accelerate
const GROUND_FRICTION := 6.0	# sv_friction
const STOP_SPEED := 1.5			# sv_stopspeed
const JUMP_VELOCITY := 3.5
const GRAVITY := 9.81

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta: float) -> void:
	%ViewmodelCamera.global_transform = $PlayerCamera.global_transform	# Copying viewmodel to player camera
	if Vector2(velocity.x, velocity.z).length() > 0.01:
		%Shotgun.rotation.y = sin(Time.get_ticks_msec() / 200.0) * 0.05	# Temporary debug wobble, will delete it later
	else:
		%Shotgun.rotation.y = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotation_degrees.y -= event.relative.x * SENSITIVITY
		$PlayerCamera.rotation_degrees.x -= event.relative.y * SENSITIVITY
		$PlayerCamera.rotation_degrees.x = clamp($PlayerCamera.rotation_degrees.x, -90.0, 90.0)

func _physics_process(delta: float) -> void:
	var input_direction_2D = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var input_direction_3D = Vector3(input_direction_2D.x, 0.0, input_direction_2D.y)
	var raw_wishdir: Vector3 = transform.basis * input_direction_3D	# not normalized
	var wishspeed: float = raw_wishdir.length() * SPEED
	var wishdir: Vector3 = raw_wishdir.normalized()
	
	if is_on_floor():
		_apply_friction(delta)
		_accelerate(wishdir, wishspeed, GROUND_ACCEL, delta)
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
	else:
		_air_accelerate(wishdir, wishspeed, AIR_ACCEL, delta)
	
	velocity.y -= GRAVITY * delta
	move_and_slide()

# SV_UserFriction, ground horizontal speed
func _apply_friction(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.0001:
		return
	var control := maxf(speed, STOP_SPEED)
	var drop := control * GROUND_FRICTION * delta
	var new_speed := maxf(speed - drop, 0.0)
	var scale := new_speed / speed
	velocity.x *= scale
	velocity.z *= scale

# SV_Accelerate, ground, accelerate toward wishdir up to wishspeed
func _accelerate(wishdir: Vector3, wishspeed: float, accel: float, delta: float) -> void:
	var current_speed := velocity.dot(wishdir)
	var add_speed := wishspeed - current_speed
	if add_speed <= 0:
		return
	var accel_speed: float = min(accel * delta * wishspeed, add_speed)
	velocity += accel_speed * wishdir

# SV_AirAccelerate, air, target is capped (AIR_CAP), but the rate of closing the gap uses the uncapped wishspeed
func _air_accelerate(wishdir: Vector3, wishspeed: float, accel: float, delta: float) -> void:
	var capped_wishspeed: float = min(wishspeed, AIR_CAP)
	var current_speed := velocity.dot(wishdir)
	var add_speed := capped_wishspeed - current_speed
	if add_speed <= 0:
		return
	var accel_speed: float = min(accel * delta * wishspeed, add_speed)
	velocity += accel_speed * wishdir
