extends CharacterBody3D

var SENSITIVITY = 0.06

const SPEED := 5.0				# ground wishspeed
const AIR_CAP := 1.0			# cap on wishspeed used for the air-accel target
const GROUND_ACCEL := 14.0		# ground sv_accelerate
const AIR_ACCEL := 14.0			# air sv_accelerate
const GROUND_FRICTION := 6.0	# sv_friction
const STOP_SPEED := 1.5			# sv_stopspeed
const JUMP_VELOCITY := 4
const GRAVITY := 10.0

@onready var health_component: HealthComponent = $HealthComponent
@onready var health_bar: TextureProgressBar = get_node_or_null("../CanvasLayer/TextureProgressBar")

func _ready():
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if health_component:
		health_component.health_changed.connect(_on_health_changed)
		health_component.died.connect(_on_died)
		_on_health_changed(health_component.current_hp, health_component.max_hp)

func _process(delta: float) -> void:
	%ViewmodelCamera.global_transform = $PlayerCamera.global_transform	# Copying viewmodel to player camera
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
	
	if Input.is_action_pressed("attack1") and %Timer.is_stopped():
		shoot_bullet()

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

func shoot_bullet():
	const BULLET_3D = preload("uid://dun60ksa6v0ai")
	var new_bullet = BULLET_3D.instantiate()
	new_bullet.shooter = self
	get_tree().current_scene.add_child(new_bullet)
	new_bullet.global_transform = %Marker3D.global_transform
	
	%Timer.start()

func _on_health_changed(current_hp: float, max_hp: float) -> void:
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current_hp

func _on_died() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().reload_current_scene()
